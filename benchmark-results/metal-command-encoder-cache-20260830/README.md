# Metal command-encoder cache A/B (2026-08-30)

## Scope

This experiment starts from the measured compiled Laguna block-tail milestone
and adds a guarded last-stream `CommandEncoder` lookup cache inside MLX Metal.
It is disabled by default. The cache stores one thread-local stream index,
invalidation generation, and encoder pointer; every toggle and stream clear
advances the generation before a cached pointer can be reused.

The same-loaded benchmark enables the already-correct compiled attention gate,
compiled MoE fusion, and compiled block tail in both arms. Only the
command-encoder cache switch changes.

- Source commit: `b27d10b4764df6ebe89030fdc9749148172b9fb7`
- Source tag: `metal-command-encoder-cache-candidate-v1`
- Primary model: `Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2`
- Engine: Metal
- Prompt: 79 uncached tokens
- Generation: greedy, 128 requested tokens
- Warmups: two per mode
- Measured trials: six per mode, alternating `AB` / `BA`
- Release benchmark binary SHA-256:
  `2239e5f0200e02e7fb4066b1f0854bab04ac48ae76cc00161967298f88e1a726`
- Metal library SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Historical Ollama Q4R8 ScaleSearch median: `179.566223067381 tok/s`

## Primary ScaleSearch result

| Mode | Median decode (tok/s) | Geometric mean (tok/s) |
| --- | ---: | ---: |
| Encoder cache OFF | `177.099891139778` | `177.025443215477` |
| Encoder cache ON | `177.004679932843` | `176.996181266785` |

The serialized median ratio is `-0.053761301784%`. The order-balanced
geometric effect is `-0.016529798294%`. Individual paired effects span
`-0.160014680367%` to `+0.042763061294%`, crossing zero and clustering around
no change.

A secondary screen on the standard Q4 runtime fixture corroborates the neutral
result: its median ratio was `-0.003359282339%` and its order-balanced effect
was `+0.004840870033%`. That fixture is not used for the absolute Ollama
comparison.

## Correctness and evidence integrity

The GPU-backed command-encoder functional test passed, including real MLX
evaluation with the switch disabled and enabled. All nine focused native
Laguna tests passed. The patch apply/reverse/apply checks passed against the
pinned Darwin and Linux dependency revisions, and dependency preparation was
idempotent.

All four warmups and twelve primary measurements produced exactly 128 tokens,
stopped for `length`, and emitted byte-identical 742-byte content.

- Primary raw report SHA-256:
  `cf6543ad85e130ee9a7bff93a4752511084df1b621e74376bbec6c5dade608e0`
- Secondary raw report SHA-256:
  `9cd4735d86236f7f2a0ebd536cba07590f72da441db63366e7c35c3bc63ef6fc`
- Debug correctness-smoke SHA-256:
  `030e32e37513f6c462adead1ce926e5312b1fd946fbfb58a03d3df33608b6e43`
- Individual primary output SHA-256:
  `5b8e8efa2dd96fdc936e519d6f0922a1d4b0693dbf13167abfdea592d54d5946`
- Aggregate measured-output SHA-256 from
  `jq -r '.trials[].content' ... | shasum -a 256`:
  `3e30da17e2ee690531192c9b06dfc827c1fc5276334a24358cc177374ab87d57`

The report's top-level median fields represent the cache-ON arm, while
`measured_trials` counts both arms. The explicit A/B comparison object and the
independently recomputed arm statistics above are the decision inputs.

## Decision

Reject for performance and do not promote or stack it. The candidate is
correct, but both exact-model estimators are neutral to slightly negative and
miss the predeclared `+1%` gate by a wide margin. The source and measurement
remain rollback milestones so this lookup-cache idea does not need to be
rediscovered.
