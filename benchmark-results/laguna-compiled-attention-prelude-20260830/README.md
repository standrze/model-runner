# Laguna compiled attention prelude A/B (2026-08-30)

## Scope

This experiment starts from the measured compiled Laguna block-tail milestone
and adds a default-off compiled graph for the attention prelude during ordinary
cached decode. It compiles input RMS normalization, separate Q/K/V projections,
reshape, Q/K RMS normalization, and transposes. The separate quantized output
widths are preserved.

The graph is eligible only for batch-one, one-token input at a positive cache
offset with no hidden-state capture. Prefill, multi-token and batched input,
RoPE, cache mutation, scaled-dot-product attention, the attention gate, and the
compiled block tail retain their existing paths. An attempted dynamic-offset
RoPE graph produced small deterministic float32 differences in the focused
exact test and was removed before this candidate was frozen.

- Source commit: `6949c23213614d7a15bb275741c4d04c675f4fa2`
- Model: `Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2`
- Engine: Metal
- Prompt: 79 uncached tokens
- Generation: greedy, 128 requested tokens
- Warmups: two per mode
- Measured trials: six per mode, alternating `AB` / `BA`
- Release benchmark binary SHA-256:
  `037115f053defe73fa7553f352481a81e53ff999257381be8a845609e74d6534`
- Metal library SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Historical Ollama Q4R8 ScaleSearch median: `179.5662 tok/s`

## Result

| Aggregate | Existing eager prelude | Compiled prelude | Effect |
| --- | ---: | ---: | ---: |
| Serialized median | `165.035273280416` | `165.378322126595` | `+0.207863954995%` |
| Geometric mean | `165.464749617926` | `165.522310757598` | `+0.034787554331%` |

The six within-pair effects were `-0.869039089689%`, `-0.129096589714%`,
`-0.107924535619%`, `+0.235953460405%`, `+0.805212826617%`, and
`+0.281420524522%`. The mixed signs and near-zero order-balanced result classify
the candidate as performance-neutral.

`mediaanalysisd` consumed approximately 128-132% CPU throughout the run, with
Spotlight workers also active. Therefore these absolute rates are not a valid
comparison with the historical Ollama median. Alternating both arms on the same
loaded model still makes the relative screen useful.

## Correctness and evidence integrity

The focused GPU-backed `LagunaModelTests` suite passed all 11 tests. New
coverage verifies the eligibility matrix and exact eager/compiled equivalence
for prefill, two successive cached decode steps, every KV-cache tensor, cache
offsets, and logits. A separate real affine-Q4 debug smoke generated 16 tokens
identically in both arms before the Release build.

All 12 measured Release generations produced exactly 128 tokens, stopped for
`length`, and emitted byte-identical 742-byte content. The report records
`outputs_match_exactly: true`.

- Raw Release report SHA-256:
  `a9ec3040a32a4289f9dc051dd79fcd5896281b7970bcf8b982b87dfecb8a70c0`
- Raw debug correctness report SHA-256:
  `abb508222eb313a92e5d1520c8201c82a75cf0e23eb620b8f6954a8a29fafd66`
- Aggregate measured-output SHA-256 from
  `jq -r '.trials[].content' ... | shasum -a 256`:
  `3e30da17e2ee690531192c9b06dfc827c1fc5276334a24358cc177374ab87d57`

## Decision

Preserve the source and evidence as a rollback milestone, but do not promote
or stack it into production. It is correct, yet its order-balanced effect is
only `+0.034788%`, far below the predeclared `+1%` candidate gate. The next
experiment should target host-side per-operation overhead, such as repeated
global Metal command-encoder lookup, while preserving all accepted numerical
paths.
