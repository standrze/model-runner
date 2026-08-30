# Stable short-string decoder cache (2026-08-30)

## Candidate scope

This candidate starts from `consolidated-decoder-fast-path-candidate-v1` and
changes only the swift-transformers ByteLevel lookup. At tokenizer load time it
precomputes exact decoded `String` values for standalone-stable ordinary pieces
whose UTF-8 representation is at most 15 bytes.

The token loop uses a cached string only when both pending UTF-8 bytes and
withheld replacement text are empty. Added, missing, skipped, unstable, and
long tokens retain the existing raw-byte path. Dense string caching is disabled
for vocabularies above 262,144 entries.

For the local Laguna tokenizer:

- Vocabulary entries: `100,352`
- Ordinary pieces: `100,282`
- Standalone-stable ordinary pieces: `99,387`
- Cached ordinary pieces at the 15-byte limit: `98,405` (`98.13%`)
- Dense optional-string table storage: `1,605,632` bytes (`1.53 MiB`)

## Validation

- All 15 focused `IncrementalByteLevelDecoderTests` pass.
- Direct tests cover 15-byte versus 16-byte classification, trailing and
  internal U+FFFD behavior, empty strings, added-token exclusion, vocabulary
  cap fallback, and pending-byte bypass of an otherwise cached token.
- A real Laguna differential checked every token ID `0...100351`, each followed
  by a stable terminator, plus 128 deterministic randomized sequences of 512
  IDs including negative and out-of-range values. Every incremental result
  matched full batch decoding.
- The production `model-runner-runtime-bench` release product builds.
- A real 16-token Laguna Metal generation produced the expected text and
  length stop. The raw smoke report is retained as `smoke-16x1.json`.

Composite control binary SHA-256:
`600dd4d515d08c077d6cc87f345013b20d1f438ba1bfa480be9a2a16f93272c6`.

Stable-string candidate binary SHA-256:
`ce7123c131738169cde7ee0a783d88ad514706e039e915812861fed3642911b7`.

Both use metallib SHA-256
`903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`.

## Decision

Correctness and reproducibility gates pass. Performance is not yet established:
macOS Photos `mediaanalysisd` was actively consuming CPU and Metal during the
smoke, so its `173.85 tok/s` observation is diagnostic only. Preserve this as
an isolated candidate and do not promote it until clean forward and reverse
brackets compare it with the frozen composite control.
