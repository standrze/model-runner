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

## Clean performance campaign

The frozen composite control and stable-string candidate were measured in both
orders. Each block used two warmups followed by six measured target-only
generations, with a 79-token uncached prompt, greedy sampling, and 128 requested
tokens.

| Order/block | Median decode (tok/s) |
| --- | ---: |
| Forward A1: composite control | `175.97682816882792` |
| Forward B1: stable-string cache | `175.53771931650454` |
| Forward B2: stable-string cache | `173.748528924641` |
| Forward A2: composite control | `176.06868153737022` |
| Reverse B3: stable-string cache | `175.45151503185548` |
| Reverse A3: composite control | `175.58745453697975` |
| Reverse A4: composite control | `175.82623574957296` |
| Reverse B4: stable-string cache | `175.42245952227427` |

The forward `A -> B -> B -> A` bracket produced geometric means of
`176.022748861656765 tok/s` for the composite control and
`174.640832859984954 tok/s` for the cache, an exact
`-0.785078071220169%` effect.

The reverse `B -> A -> A -> B` bracket produced geometric means of
`175.706804581058918 tok/s` for the composite control and
`175.436986675550742 tok/s` for the cache, an exact
`-0.153561443537431%` effect.

The order-balanced geometric effect is exactly `-0.469820625871742%`.
The order-effect spread is `0.631516627682738` percentage points. Both orders
therefore agree that the cache is slower, even though the magnitude varies.

All 48 measured generations produced exactly 128 tokens with stop reason
`length`. In each raw block, concatenating `.trials[].content` and hashing it
with SHA-256 produced the same digest:
`cde803c2ceb8ffc04563bb24b42de11575b3c56359074a5fa137f7a0fddde348`.

## Decision

Reject the stable-string cache for production and do not promote it. Its
correctness gates pass, but both clean execution orders regress the frozen
composite control and the balanced result is negative. Preserve the candidate
source, smoke report, and raw benchmark campaign as a reversible negative
milestone.
