import ArgumentParser
import Foundation
import ModelRunnerCore
import ModelRunnerProtocol

private struct RecordedMetrics: Encodable {
  var promptTokenCount: Int
  var prefilledPromptTokenCount: Int
  var cachedPromptTokenCount: Int
  var generationTokenCount: Int
  var promptTokensPerSecond: Double
  var tokensPerSecond: Double
  var stopReason: String
  var proposedDraftTokens: Int?
  var acceptedDraftTokens: Int?
  var speculativePassthroughReason: String?

  init(_ metrics: LocalModelRunnerMetrics) {
    promptTokenCount = metrics.promptTokenCount
    prefilledPromptTokenCount = metrics.prefilledPromptTokenCount
    cachedPromptTokenCount = metrics.cachedPromptTokenCount
    generationTokenCount = metrics.generationTokenCount
    promptTokensPerSecond = metrics.promptTokensPerSecond
    tokensPerSecond = metrics.tokensPerSecond
    stopReason = metrics.stopReason
    proposedDraftTokens = metrics.proposedDraftTokens
    acceptedDraftTokens = metrics.acceptedDraftTokens
    speculativePassthroughReason = metrics.speculativePassthroughReason
  }

  enum CodingKeys: String, CodingKey {
    case promptTokenCount = "prompt_token_count"
    case prefilledPromptTokenCount = "prefilled_prompt_token_count"
    case cachedPromptTokenCount = "cached_prompt_token_count"
    case generationTokenCount = "generation_token_count"
    case promptTokensPerSecond = "prompt_tokens_per_second"
    case tokensPerSecond = "tokens_per_second"
    case stopReason = "stop_reason"
    case proposedDraftTokens = "proposed_draft_tokens"
    case acceptedDraftTokens = "accepted_draft_tokens"
    case speculativePassthroughReason = "speculative_passthrough_reason"
  }
}

private struct RecordedTrial: Encodable {
  var sequence: Int
  var mode: String
  var metrics: RecordedMetrics
  var timeToFirstTokenMilliseconds: Double
  var content: String

  enum CodingKeys: String, CodingKey {
    case sequence, mode, metrics, content
    case timeToFirstTokenMilliseconds = "time_to_first_token_milliseconds"
  }
}

private struct DFlashABComparison: Encodable {
  var trialsPerMode: Int
  var targetOnlyMedianDecodeTokensPerSecond: Double
  var dflashMedianDecodeTokensPerSecond: Double
  var dflashSpeedupPercent: Double
  var outputsMatchExactly: Bool
  var firstOutputDivergenceUTF8Offset: Int?

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case targetOnlyMedianDecodeTokensPerSecond =
      "target_only_median_decode_tokens_per_second"
    case dflashMedianDecodeTokensPerSecond = "dflash_median_decode_tokens_per_second"
    case dflashSpeedupPercent = "dflash_speedup_percent"
    case outputsMatchExactly = "outputs_match_exactly"
    case firstOutputDivergenceUTF8Offset = "first_output_divergence_utf8_offset"
  }
}

private struct LagunaFusionABComparison: Encodable {
  var trialsPerMode: Int
  var unfusedMedianDecodeTokensPerSecond: Double
  var fusedMedianDecodeTokensPerSecond: Double
  var fusedSpeedupPercent: Double
  var outputsMatchExactly: Bool

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case unfusedMedianDecodeTokensPerSecond =
      "unfused_median_decode_tokens_per_second"
    case fusedMedianDecodeTokensPerSecond = "fused_median_decode_tokens_per_second"
    case fusedSpeedupPercent = "fused_speedup_percent"
    case outputsMatchExactly = "outputs_match_exactly"
  }
}

private struct LagunaAttentionGateABComparison: Encodable {
  var trialsPerMode: Int
  var eagerMedianDecodeTokensPerSecond: Double
  var compiledMedianDecodeTokensPerSecond: Double
  var compiledSpeedupPercent: Double
  var outputsMatchExactly: Bool

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case eagerMedianDecodeTokensPerSecond =
      "eager_median_decode_tokens_per_second"
    case compiledMedianDecodeTokensPerSecond =
      "compiled_median_decode_tokens_per_second"
    case compiledSpeedupPercent = "compiled_speedup_percent"
    case outputsMatchExactly = "outputs_match_exactly"
  }
}

private struct LagunaBlockTailABComparison: Encodable {
  var trialsPerMode: Int
  var eagerMedianDecodeTokensPerSecond: Double
  var compiledMedianDecodeTokensPerSecond: Double
  var compiledSpeedupPercent: Double
  var outputsMatchExactly: Bool

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case eagerMedianDecodeTokensPerSecond =
      "eager_median_decode_tokens_per_second"
    case compiledMedianDecodeTokensPerSecond =
      "compiled_median_decode_tokens_per_second"
    case compiledSpeedupPercent = "compiled_speedup_percent"
    case outputsMatchExactly = "outputs_match_exactly"
  }
}

private struct LagunaAttentionPreludeABComparison: Encodable {
  var trialsPerMode: Int
  var eagerMedianDecodeTokensPerSecond: Double
  var compiledMedianDecodeTokensPerSecond: Double
  var compiledSpeedupPercent: Double
  var outputsMatchExactly: Bool

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case eagerMedianDecodeTokensPerSecond =
      "eager_median_decode_tokens_per_second"
    case compiledMedianDecodeTokensPerSecond =
      "compiled_median_decode_tokens_per_second"
    case compiledSpeedupPercent = "compiled_speedup_percent"
    case outputsMatchExactly = "outputs_match_exactly"
  }
}

private struct PromptCacheComparison: Encodable {
  var trialsPerMode: Int
  var cachedMedianTimeToFirstTokenMilliseconds: Double
  var coldMedianTimeToFirstTokenMilliseconds: Double
  var cachedTTFTReductionPercent: Double
  var cachedMedianTotalPromptTokenCount: Double
  var cachedMedianPrefilledPromptTokenCount: Double
  var cachedMedianReusedPromptTokenCount: Double
  var coldMedianTotalPromptTokenCount: Double
  var coldMedianPrefilledPromptTokenCount: Double
  var coldMedianReusedPromptTokenCount: Double
  var outputsMatchExactly: Bool

  enum CodingKeys: String, CodingKey {
    case trialsPerMode = "trials_per_mode"
    case cachedMedianTimeToFirstTokenMilliseconds =
      "cached_median_time_to_first_token_milliseconds"
    case coldMedianTimeToFirstTokenMilliseconds =
      "cold_median_time_to_first_token_milliseconds"
    case cachedTTFTReductionPercent = "cached_ttft_reduction_percent"
    case cachedMedianTotalPromptTokenCount =
      "cached_median_total_prompt_token_count"
    case cachedMedianPrefilledPromptTokenCount =
      "cached_median_prefilled_prompt_token_count"
    case cachedMedianReusedPromptTokenCount =
      "cached_median_reused_prompt_token_count"
    case coldMedianTotalPromptTokenCount = "cold_median_total_prompt_token_count"
    case coldMedianPrefilledPromptTokenCount =
      "cold_median_prefilled_prompt_token_count"
    case coldMedianReusedPromptTokenCount =
      "cold_median_reused_prompt_token_count"
    case outputsMatchExactly = "outputs_match_exactly"
  }
}

private struct GenerationMode {
  var label: String
  var useDFlash: Bool
  var useLagunaFusion: Bool
  var useCompiledAttentionGate: Bool
  var useCompiledBlockTail = false
  var useCompiledAttentionPrelude = false
  var usePromptCache = true
}

private struct RuntimeBenchmarkReport: Encodable {
  var format = 1
  var status = "measured"
  var createdAt: String
  var modelPath: String
  var servedModelName: String
  var dflashModelPath: String?
  var dflashBlockSize: Int?
  var engine: String
  var prompt: String
  var requestedTokens: Int
  var warmupCount: Int
  var measuredTrials: Int
  var medianPromptTokensPerSecond: Double?
  var medianDecodeTokensPerSecond: Double?
  var dflashABComparison: DFlashABComparison?
  var lagunaFusionABComparison: LagunaFusionABComparison?
  var lagunaAttentionGateABComparison: LagunaAttentionGateABComparison?
  var lagunaBlockTailABComparison: LagunaBlockTailABComparison?
  var lagunaAttentionPreludeABComparison: LagunaAttentionPreludeABComparison?
  var promptCacheComparison: PromptCacheComparison?
  var warmups: [RecordedTrial]
  var trials: [RecordedTrial]

  enum CodingKeys: String, CodingKey {
    case format, status, engine, prompt, warmups, trials
    case createdAt = "created_at"
    case modelPath = "model_path"
    case servedModelName = "served_model_name"
    case dflashModelPath = "dflash_model_path"
    case dflashBlockSize = "dflash_block_size"
    case requestedTokens = "requested_tokens"
    case warmupCount = "warmup_count"
    case measuredTrials = "measured_trials"
    case medianPromptTokensPerSecond = "median_prompt_tokens_per_second"
    case medianDecodeTokensPerSecond = "median_decode_tokens_per_second"
    case dflashABComparison = "dflash_ab_comparison"
    case lagunaFusionABComparison = "laguna_fusion_ab_comparison"
    case lagunaAttentionGateABComparison = "laguna_attention_gate_ab_comparison"
    case lagunaBlockTailABComparison = "laguna_block_tail_ab_comparison"
    case lagunaAttentionPreludeABComparison =
      "laguna_attention_prelude_ab_comparison"
    case promptCacheComparison = "prompt_cache_comparison"
  }
}

private enum BenchmarkError: Error, LocalizedError {
  case invalidInput(String)
  case incompleteGeneration(Int, Int)
  case missingMetrics(Int)
  case unexpectedToolCall(Int)
  case dflashPassthrough(Int, String)
  case promptCacheNotUsed(Int)
  case coldPromptUnexpectedlyCached(Int, Int)

  var errorDescription: String? {
    switch self {
    case .invalidInput(let message): "Invalid runtime benchmark input: \(message)"
    case .incompleteGeneration(let actual, let expected):
      "Generation produced \(actual)/\(expected) requested tokens."
    case .missingMetrics(let sequence):
      "Generation \(sequence) completed without runtime metrics."
    case .unexpectedToolCall(let sequence):
      "Generation \(sequence) unexpectedly produced a tool call."
    case .dflashPassthrough(let sequence, let reason):
      "DFlash benchmark generation \(sequence) entered target-only passthrough: \(reason)."
    case .promptCacheNotUsed(let sequence):
      "Prompt-cache generation \(sequence) reused no prompt tokens; this mode requires native Laguna prompt-cache support."
    case .coldPromptUnexpectedlyCached(let sequence, let count):
      "Cold prompt-cache replay \(sequence) unexpectedly reused \(count) prompt tokens."
    }
  }
}

@main
private struct RuntimeBenchmark: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "model-runner-runtime-bench",
    abstract: "Measure native LocalModelRunner prefill and decode rates without HTTP overhead."
  )

  @Argument(help: "Local MLX checkpoint directory.")
  var model: String

  @Argument(help: "New JSON report path.")
  var output: String

  @Option(help: "Execution engine: auto, metal, cuda, or cpu.")
  var engine = "auto"

  @Option(help: "Generated tokens per warm-up and measured trial.")
  var tokens = 256

  @Option(help: "Poolside Laguna DFlash drafter checkpoint directory.")
  var dflashModel: String?

  @Option(help: "DFlash verification block size (2...checkpoint maximum).")
  var dflashBlockSize: Int?

  @Flag(
    name: .customLong("dflash-ab"),
    help:
      "Alternate target-only and DFlash generations on one loaded target; --trials is the count per mode."
  )
  var dflashAB = false

  @Flag(
    name: .customLong("laguna-fusion-ab"),
    help:
      "Alternate unfused and compiled-fusion Laguna generations on one loaded target; --trials is the count per mode."
  )
  var lagunaFusionAB = false

  @Flag(
    name: .customLong("laguna-attention-gate-ab"),
    help:
      "Alternate eager and compiled Laguna per-head attention gates with compiled MoE enabled; --trials is the count per mode."
  )
  var lagunaAttentionGateAB = false

  @Flag(
    name: .customLong("laguna-block-tail-ab"),
    help:
      "Alternate eager and compiled Laguna decoder block tails on one loaded target; --trials is the count per mode."
  )
  var lagunaBlockTailAB = false

  @Flag(
    name: .customLong("laguna-attention-prelude-ab"),
    help:
      "Alternate eager and decode-only compiled Laguna attention preludes with the compiled block tail enabled; --trials is the count per mode."
  )
  var lagunaAttentionPreludeAB = false

  @Flag(
    name: .customLong("laguna-compiled-tail-only"),
    help:
      "Run only the compiled Laguna decoder block tail; intended for isolated profiling."
  )
  var lagunaCompiledTailOnly = false

  @Flag(
    name: .customLong("prompt-cache"),
    help:
      "Measure a Laguna sibling branch restored from the completed-prefix LRU versus a forced-cold replay; reports TTFT and cache/prefill token counts, not decode speedup."
  )
  var promptCache = false

  @Option(help: "Warm-up generations excluded from the medians.")
  var warmups = 1

  @Option(help: "Measured generations.")
  var trials = 5

  @Option(help: "Deterministic user prompt.")
  var prompt =
    "Write a long, detailed technical tutorial about implementing a lock-free work-stealing scheduler in Swift. Continue with implementation details and code examples until the output limit; do not conclude or summarize early."

  @Option(
    help:
      "Second deterministic user turn used by --prompt-cache."
  )
  var continuationPrompt =
    "Continue from exactly where you stopped, adding new implementation details and code without repeating the earlier response."

  @Flag(help: "Permit EOS before the requested token count.")
  var allowEarlyStop = false

  mutating func validate() throws {
    guard tokens >= 1, tokens <= 2_048 else {
      throw ValidationError("--tokens must be in 1...2048.")
    }
    guard warmups >= 0, warmups <= 20 else {
      throw ValidationError("--warmups must be in 0...20.")
    }
    guard trials >= 1, trials <= 50 else {
      throw ValidationError("--trials must be in 1...50.")
    }
    guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ValidationError("--prompt must be nonblank.")
    }
    guard !continuationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ValidationError("--continuation-prompt must be nonblank.")
    }
    if dflashBlockSize != nil, dflashModel == nil {
      throw ValidationError("--dflash-block-size requires --dflash-model.")
    }
    if dflashAB, dflashModel == nil {
      throw ValidationError("--dflash-ab requires --dflash-model.")
    }
    if lagunaFusionAB, dflashModel != nil {
      throw ValidationError("--laguna-fusion-ab cannot be combined with --dflash-model.")
    }
    if lagunaAttentionGateAB, dflashModel != nil {
      throw ValidationError(
        "--laguna-attention-gate-ab cannot be combined with --dflash-model.")
    }
    if lagunaBlockTailAB, dflashModel != nil {
      throw ValidationError(
        "--laguna-block-tail-ab cannot be combined with --dflash-model.")
    }
    if lagunaAttentionPreludeAB, dflashModel != nil {
      throw ValidationError(
        "--laguna-attention-prelude-ab cannot be combined with --dflash-model.")
    }
    if lagunaCompiledTailOnly, dflashModel != nil {
      throw ValidationError(
        "--laguna-compiled-tail-only cannot be combined with --dflash-model.")
    }
    if promptCache, dflashModel != nil {
      throw ValidationError("--prompt-cache cannot be combined with --dflash-model.")
    }
    let exclusiveModes = [
      dflashAB, lagunaFusionAB, lagunaAttentionGateAB, lagunaBlockTailAB,
      lagunaAttentionPreludeAB, lagunaCompiledTailOnly, promptCache,
    ].filter { $0 }.count
    if exclusiveModes > 1 {
      throw ValidationError(
        "--dflash-ab, --laguna-fusion-ab, --laguna-attention-gate-ab, --laguna-block-tail-ab, --laguna-attention-prelude-ab, --laguna-compiled-tail-only, and --prompt-cache are mutually exclusive."
      )
    }
  }

  mutating func run() async throws {
    defer { clearModelRunnerMLXStreams() }

    let modelURL = URL(fileURLWithPath: model).standardizedFileURL
    let outputURL = URL(fileURLWithPath: output).standardizedFileURL
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw BenchmarkError.invalidInput("model directory does not exist: \(modelURL.path)")
    }
    guard !FileManager.default.fileExists(atPath: outputURL.path) else {
      throw BenchmarkError.invalidInput("output already exists: \(outputURL.path)")
    }
    let requestedEngine: ModelEngine
    do {
      requestedEngine = try ModelEngine(argument: engine)
    } catch {
      throw ValidationError(error.localizedDescription)
    }

    let runner = try await LocalModelRunner(
      modelPath: modelURL.path,
      servedModelName: "runtime-benchmark",
      engine: requestedEngine,
      maximumTokens: tokens,
      dflashModelPath: dflashModel,
      dflashBlockSize: dflashBlockSize
    )
    let messages = [OpenAIMessage(role: "user", content: prompt)]
    var warmupRecords = [RecordedTrial]()
    var measuredRecords = [RecordedTrial]()
    var sequence = 0
    let ordinaryMode = GenerationMode(
      label: lagunaCompiledTailOnly
        ? "laguna_block_tail_compiled"
        : (dflashModel == nil ? "target_only" : "dflash"),
      useDFlash: dflashModel != nil,
      useLagunaFusion: true,
      useCompiledAttentionGate: true,
      useCompiledBlockTail: lagunaCompiledTailOnly)
    let targetOnlyMode = GenerationMode(
      label: "target_only", useDFlash: false, useLagunaFusion: true,
      useCompiledAttentionGate: true)
    let dflashMode = GenerationMode(
      label: "dflash", useDFlash: true, useLagunaFusion: true,
      useCompiledAttentionGate: true)
    let fusionOffMode = GenerationMode(
      label: "laguna_fusion_off", useDFlash: false, useLagunaFusion: false,
      useCompiledAttentionGate: true)
    let fusionOnMode = GenerationMode(
      label: "laguna_fusion_on", useDFlash: false, useLagunaFusion: true,
      useCompiledAttentionGate: true)
    let attentionGateEagerMode = GenerationMode(
      label: "laguna_attention_gate_eager", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: false)
    let attentionGateCompiledMode = GenerationMode(
      label: "laguna_attention_gate_compiled", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: true)
    let blockTailEagerMode = GenerationMode(
      label: "laguna_block_tail_eager", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: true,
      useCompiledBlockTail: false)
    let blockTailCompiledMode = GenerationMode(
      label: "laguna_block_tail_compiled", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: true,
      useCompiledBlockTail: true)
    let attentionPreludeEagerMode = GenerationMode(
      label: "laguna_attention_prelude_eager", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: true,
      useCompiledBlockTail: true, useCompiledAttentionPrelude: false)
    let attentionPreludeCompiledMode = GenerationMode(
      label: "laguna_attention_prelude_compiled", useDFlash: false,
      useLagunaFusion: true, useCompiledAttentionGate: true,
      useCompiledBlockTail: true, useCompiledAttentionPrelude: true)

    if promptCache {
      for warmupIndex in 0..<warmups {
        let records = try await runPromptCacheProbe(
          runner: runner,
          sequence: sequence,
          seedMessages: messages,
          mode: ordinaryMode
        )
        sequence += records.count
        warmupRecords.append(contentsOf: records)
        printPromptCacheProbe(records, prefix: "warmup \(warmupIndex + 1)/\(warmups)")
      }
      for trialIndex in 0..<trials {
        let records = try await runPromptCacheProbe(
          runner: runner,
          sequence: sequence,
          seedMessages: messages,
          mode: ordinaryMode
        )
        sequence += records.count
        measuredRecords.append(contentsOf: records)
        printPromptCacheProbe(records, prefix: "trial \(trialIndex + 1)/\(trials)")
      }
    } else {
      let warmupModes: [GenerationMode]
      if dflashAB {
        warmupModes = [targetOnlyMode, dflashMode]
      } else if lagunaFusionAB {
        warmupModes = [fusionOffMode, fusionOnMode]
      } else if lagunaAttentionGateAB {
        warmupModes = [attentionGateEagerMode, attentionGateCompiledMode]
      } else if lagunaBlockTailAB {
        warmupModes = [blockTailEagerMode, blockTailCompiledMode]
      } else if lagunaAttentionPreludeAB {
        warmupModes = [attentionPreludeEagerMode, attentionPreludeCompiledMode]
      } else {
        warmupModes = [ordinaryMode]
      }
      for warmupIndex in 0..<warmups {
        for mode in warmupModes {
          let record = try await runGeneration(
            runner: runner,
            messages: messages,
            sequence: sequence,
            mode: mode
          )
          sequence += 1
          warmupRecords.append(record)
          print(
            "warmup \(warmupIndex + 1)/\(warmups) [\(record.mode)]: "
              + trialSummary(record)
          )
        }
      }

      for trialIndex in 0..<trials {
        let measuredModes: [GenerationMode]
        if dflashAB {
          measuredModes =
            trialIndex.isMultiple(of: 2)
            ? [targetOnlyMode, dflashMode] : [dflashMode, targetOnlyMode]
        } else if lagunaFusionAB {
          measuredModes =
            trialIndex.isMultiple(of: 2)
            ? [fusionOffMode, fusionOnMode] : [fusionOnMode, fusionOffMode]
        } else if lagunaAttentionGateAB {
          measuredModes =
            trialIndex.isMultiple(of: 2)
            ? [attentionGateEagerMode, attentionGateCompiledMode]
            : [attentionGateCompiledMode, attentionGateEagerMode]
        } else if lagunaBlockTailAB {
          measuredModes =
            trialIndex.isMultiple(of: 2)
            ? [blockTailEagerMode, blockTailCompiledMode]
            : [blockTailCompiledMode, blockTailEagerMode]
        } else if lagunaAttentionPreludeAB {
          measuredModes =
            trialIndex.isMultiple(of: 2)
            ? [attentionPreludeEagerMode, attentionPreludeCompiledMode]
            : [attentionPreludeCompiledMode, attentionPreludeEagerMode]
        } else {
          measuredModes = [ordinaryMode]
        }
        for mode in measuredModes {
          let record = try await runGeneration(
            runner: runner,
            messages: messages,
            sequence: sequence,
            mode: mode
          )
          sequence += 1
          measuredRecords.append(record)
          print(
            "trial \(trialIndex + 1)/\(trials) [\(record.mode)]: "
              + trialSummary(record)
          )
        }
      }
    }

    let dflashRecords = measuredRecords.filter { $0.mode == "dflash" }
    let targetOnlyRecords = measuredRecords.filter { $0.mode == "target_only" }
    let fusionOffRecords = measuredRecords.filter { $0.mode == "laguna_fusion_off" }
    let fusionOnRecords = measuredRecords.filter { $0.mode == "laguna_fusion_on" }
    let attentionGateEagerRecords = measuredRecords.filter {
      $0.mode == "laguna_attention_gate_eager"
    }
    let attentionGateCompiledRecords = measuredRecords.filter {
      $0.mode == "laguna_attention_gate_compiled"
    }
    let blockTailEagerRecords = measuredRecords.filter {
      $0.mode == "laguna_block_tail_eager"
    }
    let blockTailCompiledRecords = measuredRecords.filter {
      $0.mode == "laguna_block_tail_compiled"
    }
    let attentionPreludeEagerRecords = measuredRecords.filter {
      $0.mode == "laguna_attention_prelude_eager"
    }
    let attentionPreludeCompiledRecords = measuredRecords.filter {
      $0.mode == "laguna_attention_prelude_compiled"
    }
    let promptCacheCachedRecords = measuredRecords.filter {
      $0.mode == "prompt_cache_cached"
    }
    let promptCacheColdRecords = measuredRecords.filter {
      $0.mode == "prompt_cache_cold"
    }
    let primaryRecords: [RecordedTrial]
    if dflashAB {
      primaryRecords = dflashRecords
    } else if lagunaFusionAB {
      primaryRecords = fusionOnRecords
    } else if lagunaAttentionGateAB {
      primaryRecords = attentionGateCompiledRecords
    } else if lagunaBlockTailAB {
      primaryRecords = blockTailCompiledRecords
    } else if lagunaAttentionPreludeAB {
      primaryRecords = attentionPreludeCompiledRecords
    } else if promptCache {
      primaryRecords = []
    } else {
      primaryRecords = measuredRecords
    }
    let dflashComparison: DFlashABComparison?
    if dflashAB {
      let targetMedian = median(targetOnlyRecords.map(\.metrics.tokensPerSecond))
      let dflashMedian = median(dflashRecords.map(\.metrics.tokensPerSecond))
      let referenceContent = targetOnlyRecords.first?.content
      let outputsMatch =
        referenceContent != nil
        && targetOnlyRecords.allSatisfy { $0.content == referenceContent }
        && dflashRecords.allSatisfy { $0.content == referenceContent }
      let firstDivergence = referenceContent.flatMap { reference in
        (targetOnlyRecords.dropFirst().map(\.content) + dflashRecords.map(\.content))
          .compactMap { firstUTF8DivergenceOffset(reference, $0) }
          .min()
      }
      dflashComparison = DFlashABComparison(
        trialsPerMode: trials,
        targetOnlyMedianDecodeTokensPerSecond: targetMedian,
        dflashMedianDecodeTokensPerSecond: dflashMedian,
        dflashSpeedupPercent: 100 * (dflashMedian / targetMedian - 1),
        outputsMatchExactly: outputsMatch,
        firstOutputDivergenceUTF8Offset: firstDivergence
      )
    } else {
      dflashComparison = nil
    }
    let lagunaFusionComparison: LagunaFusionABComparison?
    if lagunaFusionAB {
      let unfusedMedian = median(fusionOffRecords.map(\.metrics.tokensPerSecond))
      let fusedMedian = median(fusionOnRecords.map(\.metrics.tokensPerSecond))
      let referenceContent = fusionOffRecords.first?.content
      let outputsMatch =
        referenceContent != nil
        && fusionOffRecords.allSatisfy { $0.content == referenceContent }
        && fusionOnRecords.allSatisfy { $0.content == referenceContent }
      lagunaFusionComparison = LagunaFusionABComparison(
        trialsPerMode: trials,
        unfusedMedianDecodeTokensPerSecond: unfusedMedian,
        fusedMedianDecodeTokensPerSecond: fusedMedian,
        fusedSpeedupPercent: 100 * (fusedMedian / unfusedMedian - 1),
        outputsMatchExactly: outputsMatch)
    } else {
      lagunaFusionComparison = nil
    }
    let lagunaAttentionGateComparison: LagunaAttentionGateABComparison?
    if lagunaAttentionGateAB {
      let eagerMedian = median(attentionGateEagerRecords.map(\.metrics.tokensPerSecond))
      let compiledMedian = median(
        attentionGateCompiledRecords.map(\.metrics.tokensPerSecond))
      let referenceContent = attentionGateEagerRecords.first?.content
      let outputsMatch =
        referenceContent != nil
        && attentionGateEagerRecords.allSatisfy { $0.content == referenceContent }
        && attentionGateCompiledRecords.allSatisfy { $0.content == referenceContent }
      lagunaAttentionGateComparison = LagunaAttentionGateABComparison(
        trialsPerMode: trials,
        eagerMedianDecodeTokensPerSecond: eagerMedian,
        compiledMedianDecodeTokensPerSecond: compiledMedian,
        compiledSpeedupPercent: 100 * (compiledMedian / eagerMedian - 1),
        outputsMatchExactly: outputsMatch
      )
    } else {
      lagunaAttentionGateComparison = nil
    }
    let lagunaBlockTailComparison: LagunaBlockTailABComparison?
    if lagunaBlockTailAB {
      let eagerMedian = median(blockTailEagerRecords.map(\.metrics.tokensPerSecond))
      let compiledMedian = median(
        blockTailCompiledRecords.map(\.metrics.tokensPerSecond))
      let referenceContent = blockTailEagerRecords.first?.content
      let outputsMatch =
        referenceContent != nil
        && blockTailEagerRecords.allSatisfy { $0.content == referenceContent }
        && blockTailCompiledRecords.allSatisfy { $0.content == referenceContent }
      lagunaBlockTailComparison = LagunaBlockTailABComparison(
        trialsPerMode: trials,
        eagerMedianDecodeTokensPerSecond: eagerMedian,
        compiledMedianDecodeTokensPerSecond: compiledMedian,
        compiledSpeedupPercent: 100 * (compiledMedian / eagerMedian - 1),
        outputsMatchExactly: outputsMatch
      )
    } else {
      lagunaBlockTailComparison = nil
    }
    let lagunaAttentionPreludeComparison: LagunaAttentionPreludeABComparison?
    if lagunaAttentionPreludeAB {
      let eagerMedian = median(
        attentionPreludeEagerRecords.map(\.metrics.tokensPerSecond))
      let compiledMedian = median(
        attentionPreludeCompiledRecords.map(\.metrics.tokensPerSecond))
      let referenceContent = attentionPreludeEagerRecords.first?.content
      let outputsMatch =
        referenceContent != nil
        && attentionPreludeEagerRecords.allSatisfy { $0.content == referenceContent }
        && attentionPreludeCompiledRecords.allSatisfy { $0.content == referenceContent }
      lagunaAttentionPreludeComparison = LagunaAttentionPreludeABComparison(
        trialsPerMode: trials,
        eagerMedianDecodeTokensPerSecond: eagerMedian,
        compiledMedianDecodeTokensPerSecond: compiledMedian,
        compiledSpeedupPercent: 100 * (compiledMedian / eagerMedian - 1),
        outputsMatchExactly: outputsMatch
      )
    } else {
      lagunaAttentionPreludeComparison = nil
    }
    let promptCacheModeComparison: PromptCacheComparison?
    if promptCache {
      let cachedTTFT = median(
        promptCacheCachedRecords.map(\.timeToFirstTokenMilliseconds))
      let coldTTFT = median(promptCacheColdRecords.map(\.timeToFirstTokenMilliseconds))
      let outputsMatch = zip(promptCacheCachedRecords, promptCacheColdRecords)
        .allSatisfy { pair in pair.0.content == pair.1.content }
      promptCacheModeComparison = PromptCacheComparison(
        trialsPerMode: trials,
        cachedMedianTimeToFirstTokenMilliseconds: cachedTTFT,
        coldMedianTimeToFirstTokenMilliseconds: coldTTFT,
        cachedTTFTReductionPercent: 100 * (1 - cachedTTFT / coldTTFT),
        cachedMedianTotalPromptTokenCount: median(
          promptCacheCachedRecords.map { Double($0.metrics.promptTokenCount) }),
        cachedMedianPrefilledPromptTokenCount: median(
          promptCacheCachedRecords.map { Double($0.metrics.prefilledPromptTokenCount) }),
        cachedMedianReusedPromptTokenCount: median(
          promptCacheCachedRecords.map { Double($0.metrics.cachedPromptTokenCount) }),
        coldMedianTotalPromptTokenCount: median(
          promptCacheColdRecords.map { Double($0.metrics.promptTokenCount) }),
        coldMedianPrefilledPromptTokenCount: median(
          promptCacheColdRecords.map { Double($0.metrics.prefilledPromptTokenCount) }),
        coldMedianReusedPromptTokenCount: median(
          promptCacheColdRecords.map { Double($0.metrics.cachedPromptTokenCount) }),
        outputsMatchExactly: outputsMatch
      )
    } else {
      promptCacheModeComparison = nil
    }

    let report = RuntimeBenchmarkReport(
      createdAt: ISO8601DateFormatter().string(from: Date()),
      modelPath: runner.modelPath,
      servedModelName: runner.servedModelName,
      dflashModelPath: runner.dflashModelPath,
      dflashBlockSize: runner.dflashBlockSize,
      engine: runner.engine.rawValue,
      prompt: prompt,
      requestedTokens: tokens,
      warmupCount: warmupRecords.count,
      measuredTrials: measuredRecords.count,
      medianPromptTokensPerSecond: promptCache
        ? nil : median(primaryRecords.map(\.metrics.promptTokensPerSecond)),
      medianDecodeTokensPerSecond: promptCache
        ? nil : median(primaryRecords.map(\.metrics.tokensPerSecond)),
      dflashABComparison: dflashComparison,
      lagunaFusionABComparison: lagunaFusionComparison,
      lagunaAttentionGateABComparison: lagunaAttentionGateComparison,
      lagunaBlockTailABComparison: lagunaBlockTailComparison,
      lagunaAttentionPreludeABComparison: lagunaAttentionPreludeComparison,
      promptCacheComparison: promptCacheModeComparison,
      warmups: warmupRecords,
      trials: measuredRecords
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(report).write(to: outputURL, options: .atomic)
    if let comparison = dflashComparison {
      print(
        String(
          format: "A/B median: target %.2f tok/s, DFlash %.2f tok/s (%+.2f%%)",
          comparison.targetOnlyMedianDecodeTokensPerSecond,
          comparison.dflashMedianDecodeTokensPerSecond,
          comparison.dflashSpeedupPercent
        )
      )
      print("A/B outputs match exactly: \(comparison.outputsMatchExactly)")
      if let offset = comparison.firstOutputDivergenceUTF8Offset {
        print("A/B first output divergence: UTF-8 byte \(offset)")
      }
    } else if let comparison = lagunaFusionComparison {
      print(
        String(
          format: "A/B median: unfused %.2f tok/s, fused %.2f tok/s (%+.2f%%)",
          comparison.unfusedMedianDecodeTokensPerSecond,
          comparison.fusedMedianDecodeTokensPerSecond,
          comparison.fusedSpeedupPercent
        )
      )
      print("A/B outputs match exactly: \(comparison.outputsMatchExactly)")
    } else if let comparison = lagunaAttentionGateComparison {
      print(
        String(
          format: "A/B median: eager gate %.2f tok/s, compiled gate %.2f tok/s (%+.2f%%)",
          comparison.eagerMedianDecodeTokensPerSecond,
          comparison.compiledMedianDecodeTokensPerSecond,
          comparison.compiledSpeedupPercent
        )
      )
      print("A/B outputs match exactly: \(comparison.outputsMatchExactly)")
    } else if let comparison = lagunaBlockTailComparison {
      print(
        String(
          format: "A/B median: eager block tail %.2f tok/s, compiled block tail %.2f tok/s (%+.2f%%)",
          comparison.eagerMedianDecodeTokensPerSecond,
          comparison.compiledMedianDecodeTokensPerSecond,
          comparison.compiledSpeedupPercent
        )
      )
      print("A/B outputs match exactly: \(comparison.outputsMatchExactly)")
    } else if let comparison = lagunaAttentionPreludeComparison {
      print(
        String(
          format:
            "A/B median: eager attention prelude %.2f tok/s, "
            + "compiled attention prelude %.2f tok/s (%+.2f%%)",
          comparison.eagerMedianDecodeTokensPerSecond,
          comparison.compiledMedianDecodeTokensPerSecond,
          comparison.compiledSpeedupPercent
        )
      )
      print("A/B outputs match exactly: \(comparison.outputsMatchExactly)")
    } else if let comparison = promptCacheModeComparison {
      print(
        String(
          format: "prompt-cache median TTFT: cached %.2f ms, cold %.2f ms (%+.2f%% reduction)",
          comparison.cachedMedianTimeToFirstTokenMilliseconds,
          comparison.coldMedianTimeToFirstTokenMilliseconds,
          comparison.cachedTTFTReductionPercent
        )
      )
      print(
        String(
          format: "prompt tokens (cached): %.0f total, %.0f reused, %.0f prefilled",
          comparison.cachedMedianTotalPromptTokenCount,
          comparison.cachedMedianReusedPromptTokenCount,
          comparison.cachedMedianPrefilledPromptTokenCount
        )
      )
      print("continuation outputs match exactly: \(comparison.outputsMatchExactly)")
    } else {
      guard let medianDecode = report.medianDecodeTokensPerSecond else {
        throw BenchmarkError.invalidInput("missing decode median")
      }
      print(
        "median decode: "
          + String(format: "%.2f tok/s", medianDecode)
      )
    }
    print("Wrote \(outputURL.path)")
  }

  private func runGeneration(
    runner: LocalModelRunner,
    messages: [OpenAIMessage],
    sequence: Int,
    mode: GenerationMode
  ) async throws -> RecordedTrial {
    let clock = ContinuousClock()
    let startedAt = clock.now
    let events = await LagunaRuntimeTuning.$useCompiledMoEFusion.withValue(
      mode.useLagunaFusion
    ) {
      await LagunaRuntimeTuning.$useCompiledAttentionGate.withValue(
        mode.useCompiledAttentionGate
      ) {
        await LagunaRuntimeTuning.$useCompiledBlockTail.withValue(
          mode.useCompiledBlockTail
        ) {
          await LagunaRuntimeTuning.$useCompiledAttentionPrelude.withValue(
            mode.useCompiledAttentionPrelude
          ) {
            await runner.stream(
              messages: messages,
              maximumTokens: tokens,
              temperature: 0,
              topP: 1,
              enablePromptCache: mode.usePromptCache,
              enableSpeculativeDecoding: mode.useDFlash
            )
          }
        }
      }
    }
    var content = ""
    var finalMetrics: LocalModelRunnerMetrics?
    var firstTokenAt: ContinuousClock.Instant?
    for try await event in events {
      switch event {
      case .content(let text):
        if firstTokenAt == nil { firstTokenAt = clock.now }
        content += text
      case .metrics(let metrics): finalMetrics = metrics
      case .toolCall: throw BenchmarkError.unexpectedToolCall(sequence)
      }
    }
    guard let finalMetrics else { throw BenchmarkError.missingMetrics(sequence) }
    if mode.useDFlash, let reason = finalMetrics.speculativePassthroughReason {
      throw BenchmarkError.dflashPassthrough(sequence, reason)
    }
    if !allowEarlyStop, finalMetrics.generationTokenCount != tokens {
      throw BenchmarkError.incompleteGeneration(finalMetrics.generationTokenCount, tokens)
    }
    guard let firstTokenAt else {
      throw BenchmarkError.incompleteGeneration(0, tokens)
    }
    return RecordedTrial(
      sequence: sequence,
      mode: mode.label,
      metrics: RecordedMetrics(finalMetrics),
      timeToFirstTokenMilliseconds: milliseconds(startedAt.duration(to: firstTokenAt)),
      content: content
    )
  }

  private func runPromptCacheProbe(
    runner: LocalModelRunner,
    sequence: Int,
    seedMessages: [OpenAIMessage],
    mode: GenerationMode
  ) async throws -> [RecordedTrial] {
    var seedMode = mode
    seedMode.label = "prompt_cache_seed"
    let seed = try await runGeneration(
      runner: runner, messages: seedMessages, sequence: sequence, mode: seedMode)
    let continuationMessages = seedMessages + [
      OpenAIMessage(role: "assistant", content: seed.content),
      OpenAIMessage(role: "user", content: continuationPrompt),
    ]
    // Move the hot session down a sibling branch first. The measured cached
    // continuation must then come from the immutable completed-prefix LRU,
    // rather than the zero-copy linear hot path.
    let displacementMessages = seedMessages + [
      OpenAIMessage(role: "assistant", content: seed.content),
      OpenAIMessage(
        role: "user",
        content: continuationPrompt + "\n\nBegin instead with memory reclamation."
      ),
    ]
    var displacementMode = mode
    displacementMode.label = "prompt_cache_displacement"
    let displacement = try await runGeneration(
      runner: runner, messages: displacementMessages, sequence: sequence + 1,
      mode: displacementMode)
    guard displacement.metrics.cachedPromptTokenCount > 0 else {
      throw BenchmarkError.promptCacheNotUsed(displacement.sequence)
    }
    var cachedMode = mode
    cachedMode.label = "prompt_cache_cached"
    let cached = try await runGeneration(
      runner: runner, messages: continuationMessages, sequence: sequence + 2,
      mode: cachedMode)
    guard cached.metrics.cachedPromptTokenCount > 0 else {
      throw BenchmarkError.promptCacheNotUsed(cached.sequence)
    }
    var coldMode = mode
    coldMode.label = "prompt_cache_cold"
    coldMode.usePromptCache = false
    let cold = try await runGeneration(
      runner: runner, messages: continuationMessages, sequence: sequence + 3,
      mode: coldMode)
    guard cold.metrics.cachedPromptTokenCount == 0 else {
      throw BenchmarkError.coldPromptUnexpectedlyCached(
        cold.sequence, cold.metrics.cachedPromptTokenCount)
    }
    return [seed, displacement, cached, cold]
  }

  private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
      return (sorted[middle - 1] + sorted[middle]) / 2
    }
    return sorted[middle]
  }

  private func firstUTF8DivergenceOffset(_ lhs: String, _ rhs: String) -> Int? {
    let lhsBytes = Array(lhs.utf8)
    let rhsBytes = Array(rhs.utf8)
    let commonCount = min(lhsBytes.count, rhsBytes.count)
    if let mismatch = (0..<commonCount).first(where: { lhsBytes[$0] != rhsBytes[$0] }) {
      return mismatch
    }
    return lhsBytes.count == rhsBytes.count ? nil : commonCount
  }

  private func milliseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1_000
      + Double(components.attoseconds) / 1_000_000_000_000_000
  }

  private func printPromptCacheProbe(_ records: [RecordedTrial], prefix: String) {
    guard records.count == 4 else { return }
    print("\(prefix) [prompt_cache_seed]: " + trialSummary(records[0]))
    print("\(prefix) [prompt_cache_displacement]: " + trialSummary(records[1]))
    print("\(prefix) [prompt_cache_cached]: " + trialSummary(records[2]))
    print("\(prefix) [prompt_cache_cold]: " + trialSummary(records[3]))
  }

  private func trialSummary(_ record: RecordedTrial) -> String {
    let metrics = record.metrics
    var summary = String(
      format: "%.2f tok/s, TTFT %.2f ms", metrics.tokensPerSecond,
      record.timeToFirstTokenMilliseconds)
    if metrics.cachedPromptTokenCount > 0 {
      summary += ", prompt \(metrics.cachedPromptTokenCount) cached/"
        + "\(metrics.prefilledPromptTokenCount) prefilled"
    }
    if let proposed = metrics.proposedDraftTokens,
      let accepted = metrics.acceptedDraftTokens,
      proposed > 0
    {
      summary += String(
        format: ", DFlash %.1f%% (%d/%d)",
        100 * Double(accepted) / Double(proposed), accepted, proposed)
    }
    if let reason = metrics.speculativePassthroughReason {
      summary += ", DFlash passthrough: \(reason)"
    }
    return summary
  }
}
