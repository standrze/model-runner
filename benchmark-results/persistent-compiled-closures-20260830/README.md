# Persistent compiled closures — 2026-08-30

## Decision

Rejected for promotion. Retaining one public `mlx_compile` closure per stateless
Swift `CompiledFunction` is correct and lifetime-safe, but it is neutral to
slightly slower than the transient wrapper on the consolidated compiled-tail
stack.

- Median effect: **-0.062702219450%**
- Geometric/order-balanced effect: **-0.042423215199%**
- Exact generated output: **yes**
- Promotion gate: **not met** (requires a stable improvement of at least 1%)

The best correct experimental result therefore remains the earlier compiled
block-tail measurement at `177.499062770142 tok/s`. The exact Ollama Q4R8
ScaleSearch control remains `179.566223067381 tok/s`, a gap of
`2.067160297239 tok/s`; the Swift arm still needs `+1.164603499860%` to tie it.

## Candidate

- Branch: `codex/persistent-compiled-closure-fast-path`
- Base: `9cbdd9462dda584dd8fb938af4228bddb9b24966`
- Source commit: `861793f1a72c70c1c2456abc2c17d5024b3fdedd`
- Candidate tag: `persistent-compiled-closure-candidate-v1`
- Release binary SHA-256:
  `a81c5c046c86a9b66697ff218b04590962d663b0ed95c52df09536dcb8a11032`
- `mlx.metallib` SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`

The feature is process-global, disabled by default, and stateless-only.
Stateful compiled functions keep the pre-existing transient path. Darwin uses
the already-required outer MLX evaluation lock for a lock-free hot-path flag
read; the pinned Linux revision uses `Synchronization.Atomic` and its existing
evaluation-lock order. The retained C closure is RAII-owned, the temporary
source closure is freed immediately after `mlx_compile`, and teardown happens
under the established evaluation lock.

## Correctness and persistence checks

- Darwin and Linux patch apply/reverse/apply round trips: passed.
- `prepare-dependencies.sh` repeated idempotence: passed twice.
- `PersistentCompiledClosureTests`: 4/4 passed.
  - default-off transient behavior
  - one retained handle reused across shape changes
  - observed-state fallback
  - closure/owner lifetime teardown without a retain cycle
- `LagunaModelTests`: 9/9 passed.
- Debug real-model smoke: 16/16 tokens in both modes, `length` stop, exact output.
- Release same-loaded test: every warmup and measured output was exact, 742 UTF-8
  bytes, 128/128 generated tokens, and `length` stop.

## Release benchmark

Command:

```sh
.build/arm64-apple-macosx/release/model-runner-runtime-bench \
  /Users/stephen/Documents/llm-abliteration/models/Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2 \
  /private/tmp/persistent-compiled-closures-release-abba-v1.json \
  --engine metal \
  --tokens 128 \
  --warmups 2 \
  --trials 6 \
  --persistent-compiled-closures-ab
```

Both modes used the same loaded model and the same fast stack: native Laguna
fusion, compiled attention gates, compiled decoder block tails, and direct KV
updates. Trial order alternated OFF/ON then ON/OFF.

| Mode | Decode median | Decode geometric mean | Prompt median |
|---|---:|---:|---:|
| Transient closure wrapper | 177.420380896899 tok/s | 177.366672067911 tok/s | 1038.934649350291 tok/s |
| Persistent compiled closure | 177.309134380321 tok/s | 177.291427422928 tok/s | 1040.008360803530 tok/s |
| Effect | -0.062702219450% | -0.042423215199% | +0.103347352397% |

The candidate median is `2.257088687060 tok/s` below Ollama and would require
`+1.272968081960%` from this arm to tie. Since it also fails to improve on the
transient control, no separate-binary confirmation or stack promotion is
warranted.

## Preserved artifacts

- `same-loaded-abba-v1.json`: committed SHA-256
  `dec4370a25a9881a686c6eaace5eee76fd1939c9d06a63c40821731e4cc2c9af`
- Original JSONEncoder output before the repository-normalizing final newline:
  `8d434e832850e16fbfc293b8ba4797e11e3bb273c247a05c0c65451e5c11b6e1`
- `debug-smoke-16x1.json`: committed SHA-256
  `8bb50b38530fdbd24e6ad83bb98ab6e8bde926db3558db999546cb4734537220`
- One generated 128-token output (no appended newline):
  `5b8e8efa2dd96fdc936e519d6f0922a1d4b0693dbf13167abfdea592d54d5946`
- All 12 measured contents through `jq -r`:
  `3e30da17e2ee690531192c9b06dfc827c1fc5276334a24358cc177374ab87d57`
