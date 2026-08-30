# Simple Swift Model Server

A deliberately small Swift + MLX HTTP server. It loads one local model at startup and exposes:

- `GET /v1/models`
- `POST /v1/chat/completions` (regular JSON or OpenAI-style SSE streaming)

It is independent of the main ModelRunner source tree. The dependency revisions match the known baseline in this repository.

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
