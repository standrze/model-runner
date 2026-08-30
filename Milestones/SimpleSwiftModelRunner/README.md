# Simple Swift Model Server

A deliberately small Swift + MLX HTTP server kept as a standalone testing fixture. It loads one local model at startup and exposes:

- `GET /v1/models`
- `POST /v1/chat/completions` (regular JSON or OpenAI-style SSE streaming)

It is independent of the optimized ModelRunner source tree. Its dependencies and bundled MLX Metal library match the known baseline in this repository.

The ZIP can be extracted anywhere and opened as its own Swift package. It has no local package paths, parent-repository imports, or optimized ModelRunner patches.

Use a model architecture supported by the pinned upstream `mlx-swift-lm`. Project-specific architectures such as `laguna` intentionally live in the full ModelRunner and will not load here.

## Run

```bash
swift run simple-model-server /absolute/path/to/model --host 127.0.0.1 --port 8080
```

The model name is the model directory's final path component. Check it with:

```bash
curl http://127.0.0.1:8080/v1/models
```

Send a non-streaming request:

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"YOUR_MODEL_DIRECTORY","messages":[{"role":"user","content":"Hello"}],"max_tokens":64}'
```

Add `"stream":true` to receive `text/event-stream` chunks ending in `data: [DONE]`.

This example intentionally omits authentication, TLS, tools, images, prompt caching, batching, and performance tuning. Bind it to localhost unless you add the production safeguards you need.

The bundled `mlx.metallib` was built with the current macOS 26 Xcode toolchain for this test machine. Rebuild that resource with an older deployment target before distributing the fixture to older macOS hosts.
