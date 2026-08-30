# Runtime host fast-path experiments (2026-08-30)

## Controls

- Historical Ollama Q4R8 ScaleSearch median: `179.5662 tok/s`.
- Direct-KV v1 binary SHA-256: `4c7241e7e23f2c184c9d4d8ae9627a621d73c2116411339d3c43e742bfd6bbec`.
- Zero-result-wrapper v3 binary SHA-256: `423a35823b9a20d7c4a5d562a759191c1567b8df5d7b7ad8654a0bb111f00e0e`.
- Isolated rebuild of v3 binary SHA-256: `59536631ba31e251bd0f71424262aa334faa48cf86fa8d9df60afdcab97ce93c`.
- Property-wrapper v4 binary SHA-256: `335736124f6112c2da566f53c3f687440661939874f59edec911372ecea1ac97`.
- Single-generation-pool candidate binary SHA-256: `74611b9fd8c5de032e8a97c321f0c269ab2c2c013c25921936ad202c82db4772`.
- Same-build single-generation-pool isolation binary SHA-256: `f7db32446acca479f92ae3cee5e39f0eb767f56176efea49d4f2e494c73879e8`.
- Autorelease + in-place decoder v6 binary SHA-256: `b2c4a7c39d7058e38a00fba686b6a2a1464260a7abd6483144d5fa49b10537e3`.
- Every binary uses metallib SHA-256 `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`.

All reports use the same local Laguna XS 2.1 Abliterated Q4R8 ScaleSearch model,
Metal, a 79-token uncached prompt, and the 24 GiB memory / 256 MiB cache /
wired-memory configuration. Primary blocks generate 128 tokens after two
warmups; diagnostic filenames identify shorter microblocks and the 1,024-token
length run explicitly.

## Property-wrapper fast path: rejected

The valid four-block `v1-a -> v4-a -> v4-b -> v1-b` ABBA produced geometric
medians of `172.405435 tok/s` for v1 and `172.291583 tok/s` for v4: an exact
`-0.066037%` effect. Both endpoint-stability checks and every block gate passed,
but the effect was flat and the two drift-adjusted candidate blocks split
directions. The source candidate was removed rather than carrying unmeasured
generic getter complexity.

The reverse `v4-c -> v1-c -> v1-d -> v4-d` bracket is retained as rejected raw
evidence. Background Git and media work shifted the v4 endpoints by `19.059%`
and the v1 endpoints by `2.347%`, so its apparent result is invalid.

## Single-generation-pool candidate: preserved

This candidate removes only the redundant outer `autoreleasepool` around the
production iterator call. Iterator-owned pools around model work remain. The
candidate compiles in an isolated detached v3 worktree and passes all four
focused `CancellationTests` (cancellation and length-stop behavior), the full
102-test project suite, and a 1,024-token length-stop generation.

Earlier stable directional evidence measured `+0.8708%` (`0.05273 ms/token`)
for this exact pool boundary on the standard ScaleSearch model, although that
run was ordered rather than ABBA. In the current model, the complete contended
ABBA pointed the same way at `+0.4810%`, and the interrupted partial bracket was
`+1.9490%`; neither current bracket is admissible as an exact estimate. The
candidate is therefore kept as a reversible milestone, with a clean closed
ABBA still required before calling the performance result final.

The `mediaanalysis-contended` directory is diagnostic only. macOS
`mediaanalysisd` cycled between idle and roughly 140% CPU, so those reports must
not be used as acceptance evidence. The same system load interrupted the first
attempt in `quiet-autorelease`; incomplete/failed brackets are intentionally
retained for auditability.

## Autorelease + in-place decoder campaign: preserved, not promoted

The v6 composite keeps the single-generation-pool change and additionally
updates MLXLM's token-loop handler to mutate its decoder in place. The source
candidate, focused dependency tests, full 102-test project suite, and a real
Laguna generation all pass. Every one of the 56 measured campaign generations
also produced byte-identical content SHA-256
`5b8e8efa2dd96fdc936e519d6f0922a1d4b0693dbf13167abfdea592d54d5946`
with the expected Metal, prompt, cache, generation-count, and length-stop
invariants.

The clean ABBA bracket (`v3 -> v6 -> v6 -> v3`) measured geometric medians of
`174.019540 tok/s` for v3 and `173.658860 tok/s` for v6, an exact
`-0.207264%` effect. The clean reverse BAAB bracket (`v6 -> v3 -> v3 -> v6`)
measured `172.458343 tok/s` for v3 and `175.075400 tok/s` for v6, an exact
`+1.517501%` effect. All per-block stability, endpoint-drift, correctness, and
host-load gates passed in both brackets; the monitored background processes
were idle throughout.

Balancing the two bracket orders geometrically gives `173.237183 tok/s` for v3
and `174.365692 tok/s` for v6, or `+0.651424%`. The valid bracket estimates
disagree by `1.724765` percentage points and cross zero, so the campaign is
inconclusive and remains below the predeclared `+1%` acceptance gate. This is
weak positive directional evidence, not a measured speed milestone. The
candidate is preserved at tag `token-loop-decoder-candidate-v1`; accepted
production `main` remains zero-wrapper v3 at `7238a63`.

## In-place decoder isolation: invalid, not promoted

The same-provenance decoder isolation compares an autorelease-only binary
against v6, with the same source/build tree and metallib. Its uninterrupted
eight-block order was `A -> B -> B -> A -> B -> A -> A -> B`, with two warmups
and six measured 128-token generations in every fresh process. All 64 outputs
were byte-identical with content SHA-256
`5b8e8efa2dd96fdc936e519d6f0922a1d4b0693dbf13167abfdea592d54d5946`;
all correctness, Metal, per-block variance, within-block drift, and host-media
gates passed.

The raw paired geometric effect was `-0.518991%`, with a one-sided-bound span
from `-2.209423%` to `+1.200662%`. That magnitude is invalid under the
predeclared cross-block gates: v6 changed `-2.016804%` and `-2.501305%` within
the two quartets, its overall block spread was `3.451136%`, and its execution-
order strata differed by `0.532695` percentage point. Each exceeds its tight
stability threshold. The result therefore cannot establish either a decoder
gain or a formal regression and does not support promotion. The raw reports
remain as reversible audit evidence; accepted production `main` is unchanged.
