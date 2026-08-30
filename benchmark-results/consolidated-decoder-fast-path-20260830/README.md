# Consolidated decoder fast path (2026-08-30)

## Scope and controls

This campaign isolates the in-place outer token-loop decoder mutation on top
of the already measured guarded incremental ByteLevel streaming decoder. The
incremental-only executable is `A`; the consolidated incremental plus in-place
executable is `B`. Both retain accepted direct-KV zero-wrapper v3, use the same
MLX dependency revisions and metallib, and exclude the generation-loop
autorelease candidate and rejected QMV experiments.

- Model: `Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2`
- Engine: Metal
- Prompt: 79 uncached tokens
- Generation: greedy, 128 requested tokens
- Per block: two warmups followed by six measured target-only trials
- Memory/cache setup: 24 GiB memory limit, 256 MiB MLX cache, wired residency
- Incremental-only binary SHA-256:
  `93c85328a8d1809113df6134a13b2090bd456cdefb8a866a2a9d9b9718dbaa96`
- Consolidated binary SHA-256:
  `600dd4d515d08c077d6cc87f345013b20d1f438ba1bfa480be9a2a16f93272c6`
- Metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Predeclared promotion gate: at least `+1%` with stable forward and reverse
  brackets

## Results

| Order/block | Build | Median decode (tok/s) |
| --- | --- | ---: |
| Forward A1 | Incremental only | 176.24714162769163 |
| Forward B1 | Incremental + in-place | 176.27822834576386 |
| Forward B2 | Incremental + in-place | 175.52991266097985 |
| Forward A2 | Incremental only | 175.71629832227666 |
| Reverse B3 | Incremental + in-place | 176.00417803357965 |
| Reverse A3 | Incremental only | 175.62215144372715 |
| Reverse A4 | Incremental only | 175.00931178244696 |
| Reverse B4 | Incremental + in-place | 175.67843528548661 |

The forward `A -> B -> B -> A` bracket produced geometric means of
`175.98151981586022 tok/s` for incremental-only and
`175.90367257554400 tok/s` for the composite, an exact
`-0.044236031372891%` composite effect.

The reverse `B -> A -> A -> B` bracket produced geometric means of
`175.31546382997524 tok/s` for incremental-only and
`175.84123123046962 tok/s` for the composite, an exact
`+0.299897903475466%` composite effect.

Geometrically balancing both execution orders gives
`+0.127683089728925%`. The two order estimates differ by
`0.344133934848357` percentage points. That spread crosses zero and is larger
than the balanced estimate, so the measurement is consistent with a neutral
change rather than a reliable throughput improvement.

## Correctness

All 48 measured generations produced exactly 128 tokens with stop reason
`length`. For each of the eight raw reports, the following command produced
the same aggregate content digest:

```sh
jq -r '.trials[].content' FILE | shasum -a 256
```

Digest:
`cde803c2ceb8ffc04563bb24b42de11575b3c56359074a5fa137f7a0fddde348`.

The in-place mutation also retained the previously completed focused decoder,
stop-string, Harmony-routing, and end-to-end smoke correctness checks.

## Decision

The in-place decoder change is correctness-clean but performance-neutral. It
does not meet the `+1%` promotion gate, and the forward and reverse estimates
do not agree on direction. Preserve the source and raw evidence as a reversible
measured milestone, but do not promote the in-place change or the consolidated
candidate over the accepted production baseline.
