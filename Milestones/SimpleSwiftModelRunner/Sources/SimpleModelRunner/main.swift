import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import NIOCore
import NIOHTTP1
import NIOPosix
import Tokenizers

// MARK: - Command line

struct Options {
    let modelURL: URL
    var host = "127.0.0.1"
    var port = 8080

    init(arguments: [String]) throws {
        guard let path = arguments.first, path != "--help" else {
            throw AppError.usage
        }

        modelURL = URL(fileURLWithPath: path).standardizedFileURL
        var index = 1
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw AppError.usage }
            switch arguments[index] {
            case "--host":
                host = arguments[index + 1]
            case "--port":
                guard let value = Int(arguments[index + 1]), (1 ... 65_535).contains(value)
                else { throw AppError.usage }
                port = value
            default:
                throw AppError.usage
            }
            index += 2
        }
    }
}

enum AppError: LocalizedError {
    case usage
    case request(HTTPResponseStatus, String, String)
    case missingCompletionInfo

    var errorDescription: String? {
        switch self {
        case .usage:
            "Usage: simple-model-server MODEL_PATH [--host 127.0.0.1] [--port 8080]"
        case .request(_, let message, _):
            message
        case .missingCompletionInfo:
            "Generation ended without completion information."
        }
    }
}

// MARK: - HTTP server

final class ModelServer: @unchecked Sendable {
    let container: ModelContainer
    let modelName: String

    init(container: ModelContainer, modelName: String) {
        self.container = container
        self.modelName = modelName
    }

    func run(host: String, port: Int) async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        do {
            let channel = try await ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline().flatMap {
                        channel.pipeline.addHandler(RequestHandler(server: self))
                    }
                }
                .bind(host: host, port: port)
                .get()

            print("Ready: http://\(host):\(port)/v1  model=\(modelName)")
            try await channel.closeFuture.get()
            try await group.shutdownGracefully()
        } catch {
            try? await group.shutdownGracefully()
            throw error
        }
    }

    func handle(head: HTTPRequestHead, body: Data, channel: Channel) async {
        do {
            switch (head.method, head.uri) {
            case (.GET, "/v1/models"):
                try await sendJSON(ModelList(model: modelName), on: channel)
            case (.POST, "/v1/chat/completions"):
                try await complete(body: body, on: channel)
            default:
                throw AppError.request(.notFound, "Route not found.", "not_found")
            }
        } catch AppError.request(let status, let message, let code) {
            try? await sendJSON(
                ErrorEnvelope(message: message, code: code), status: status, on: channel)
        } catch let error as DecodingError {
            try? await sendJSON(
                ErrorEnvelope(message: "Invalid JSON: \(error.localizedDescription)", code: "invalid_json"),
                status: .badRequest,
                on: channel
            )
        } catch {
            try? await sendJSON(
                ErrorEnvelope(message: error.localizedDescription, code: "server_error"),
                status: .internalServerError,
                on: channel
            )
        }
    }

    private func complete(body: Data, on channel: Channel) async throws {
        let request = try JSONDecoder().decode(ChatRequest.self, from: body)
        guard request.model == modelName else {
            throw AppError.request(.notFound, "Model '\(request.model)' is not loaded.", "model_not_found")
        }
        guard !request.messages.isEmpty else {
            throw AppError.request(.badRequest, "messages must not be empty.", "invalid_request")
        }

        let messages = try request.messages.map { message in
            guard let role = Chat.Message.Role(rawValue: message.role) else {
                throw AppError.request(
                    .badRequest, "Unsupported message role '\(message.role)'.", "invalid_request")
            }
            return Chat.Message(role: role, content: message.content)
        }

        let maxTokens = request.maxCompletionTokens ?? request.maxTokens ?? 256
        guard maxTokens > 0 else {
            throw AppError.request(.badRequest, "max_tokens must be positive.", "invalid_request")
        }
        let temperature = request.temperature ?? 0.6
        let topP = request.topP ?? 1
        guard temperature >= 0, topP > 0, topP <= 1 else {
            throw AppError.request(
                .badRequest, "temperature or top_p is outside its valid range.", "invalid_request")
        }

        let input = try await container.prepare(input: UserInput(chat: messages))
        let events = try await container.generate(
            input: input,
            parameters: GenerateParameters(
                maxTokens: maxTokens,
                temperature: Float(temperature),
                topP: Float(topP)
            )
        )
        let id = "chatcmpl-" + UUID().uuidString.replacingOccurrences(of: "-", with: "")

        if request.stream == true {
            try await stream(events, id: id, on: channel)
        } else {
            try await collect(events, id: id, on: channel)
        }
    }

    private func collect(
        _ events: AsyncStream<Generation>, id: String, on channel: Channel
    ) async throws {
        var text = ""
        var info: GenerateCompletionInfo?
        for await event in events {
            if case .chunk(let chunk) = event { text += chunk }
            if case .info(let completion) = event { info = completion }
        }
        guard let info else { throw AppError.missingCompletionInfo }

        try await sendJSON(
            ChatResponse(
                id: id,
                model: modelName,
                text: text,
                finishReason: finishReason(info.stopReason),
                usage: Usage(info)
            ),
            on: channel
        )
    }

    private func stream(
        _ events: AsyncStream<Generation>, id: String, on channel: Channel
    ) async throws {
        try await beginEventStream(on: channel)
        try await sendEvent(
            ChatChunk(id: id, model: modelName, role: "assistant"), on: channel)

        var info: GenerateCompletionInfo?
        for await event in events {
            switch event {
            case .chunk(let text):
                try await sendEvent(ChatChunk(id: id, model: modelName, text: text), on: channel)
            case .info(let completion):
                info = completion
            case .toolCall, .rejectedToolCall:
                break
            }
        }
        guard let info else { throw AppError.missingCompletionInfo }

        try await sendEvent(
            ChatChunk(
                id: id,
                model: modelName,
                finishReason: finishReason(info.stopReason),
                usage: Usage(info)
            ),
            on: channel
        )
        try await write(Data("data: [DONE]\n\n".utf8), on: channel)
        try await finish(on: channel)
    }

    private func finishReason(_ reason: GenerateStopReason) -> String {
        switch reason {
        case .length: "length"
        case .stop, .cancelled: "stop"
        }
    }

    private func sendJSON<Value: Encodable>(
        _ value: Value,
        status: HTTPResponseStatus = .ok,
        on channel: Channel
    ) async throws {
        let data = try JSONEncoder().encode(value)
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json; charset=utf-8")
        headers.add(name: "content-length", value: String(data.count))
        headers.add(name: "connection", value: "close")
        try await channel.writeAndFlush(
            HTTPServerResponsePart.head(.init(version: .http1_1, status: status, headers: headers))
        ).get()
        try await write(data, on: channel)
        try await finish(on: channel)
    }

    private func beginEventStream(on channel: Channel) async throws {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "text/event-stream; charset=utf-8")
        headers.add(name: "cache-control", value: "no-cache")
        headers.add(name: "transfer-encoding", value: "chunked")
        headers.add(name: "connection", value: "close")
        try await channel.writeAndFlush(
            HTTPServerResponsePart.head(.init(version: .http1_1, status: .ok, headers: headers))
        ).get()
    }

    private func sendEvent<Value: Encodable>(_ value: Value, on channel: Channel) async throws {
        var data = Data("data: ".utf8)
        data.append(try JSONEncoder().encode(value))
        data.append(Data("\n\n".utf8))
        try await write(data, on: channel)
    }

    private func write(_ data: Data, on channel: Channel) async throws {
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        try await channel.writeAndFlush(
            HTTPServerResponsePart.body(.byteBuffer(buffer))
        ).get()
    }

    private func finish(on channel: Channel) async throws {
        try await channel.writeAndFlush(HTTPServerResponsePart.end(nil)).get()
        try? await channel.close().get()
    }
}

private final class RequestHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart

    private let server: ModelServer
    private var head: HTTPRequestHead?
    private var body = Data()
    private var responseInFlight = false

    init(server: ModelServer) {
        self.server = server
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard !responseInFlight else { return }
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            body.removeAll(keepingCapacity: true)
        case .body(var buffer):
            body.append(contentsOf: buffer.readBytes(length: buffer.readableBytes) ?? [])
        case .end:
            guard let head else { return }
            responseInFlight = true
            let requestBody = body
            self.head = nil
            body.removeAll(keepingCapacity: false)
            let channel = context.channel
            Task { await server.handle(head: head, body: requestBody, channel: channel) }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}

// MARK: - OpenAI wire types

private struct ChatRequest: Decodable, Sendable {
    struct Message: Decodable, Sendable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool?
    let maxTokens: Int?
    let maxCompletionTokens: Int?
    let temperature: Double?
    let topP: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
        case topP = "top_p"
    }
}

private struct ModelList: Encodable {
    struct Model: Encodable {
        let id: String
        let object = "model"
        let ownedBy = "local"

        enum CodingKeys: String, CodingKey {
            case id, object
            case ownedBy = "owned_by"
        }
    }

    let object = "list"
    let data: [Model]

    init(model: String) {
        data = [Model(id: model)]
    }
}

private struct Usage: Encodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    init(_ info: GenerateCompletionInfo) {
        promptTokens = info.totalPromptTokenCount
        completionTokens = info.generationTokenCount
        totalTokens = promptTokens + completionTokens
    }

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct ChatResponse: Encodable {
    struct Message: Encodable {
        let role = "assistant"
        let content: String
    }
    struct Choice: Encodable {
        let index = 0
        let message: Message
        let finishReason: String

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    let id: String
    let object = "chat.completion"
    let created = Int(Date().timeIntervalSince1970)
    let model: String
    let choices: [Choice]
    let usage: Usage

    init(id: String, model: String, text: String, finishReason: String, usage: Usage) {
        self.id = id
        self.model = model
        choices = [Choice(message: Message(content: text), finishReason: finishReason)]
        self.usage = usage
    }
}

private struct ChatChunk: Encodable {
    struct Delta: Encodable {
        let role: String?
        let content: String?
    }
    struct Choice: Encodable {
        let index = 0
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }

    let id: String
    let object = "chat.completion.chunk"
    let created = Int(Date().timeIntervalSince1970)
    let model: String
    let choices: [Choice]
    let usage: Usage?

    init(
        id: String,
        model: String,
        role: String? = nil,
        text: String? = nil,
        finishReason: String? = nil,
        usage: Usage? = nil
    ) {
        self.id = id
        self.model = model
        choices = [Choice(delta: Delta(role: role, content: text), finishReason: finishReason)]
        self.usage = usage
    }
}

private struct ErrorEnvelope: Encodable {
    struct Detail: Encodable {
        let message: String
        let type = "invalid_request_error"
        let code: String
    }
    let error: Detail

    init(message: String, code: String) {
        error = Detail(message: message, code: code)
    }
}

let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
guard FileManager.default.fileExists(atPath: options.modelURL.path) else {
    throw AppError.request(.notFound, "Model path does not exist.", "model_not_found")
}

print("Loading \(options.modelURL.path)…")
let container = try await LLMModelFactory.shared.loadContainer(
    from: options.modelURL,
    using: #huggingFaceTokenizerLoader()
)
let server = ModelServer(container: container, modelName: options.modelURL.lastPathComponent)
try await server.run(host: options.host, port: options.port)
