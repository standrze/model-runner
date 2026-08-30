# Model runner milestones

This registry indexes reproducible source and measurement boundaries. Detailed
validity notes and raw reports live under `benchmark-results/`. Annotated Git
tags are rollback points; accepted `main` remains unchanged until a candidate
passes both correctness and the predeclared stability gate.

## Restore safely

Inspect a milestone without moving a branch:

```sh
git switch --detach TAG
```

Start a new branch from it:

```sh
git switch -c codex/restore-TAG TAG
```

These commands preserve later milestones. Do not reset a dirty working tree to
a tag.

## Current state

- Accepted `origin/main`: `7238a63`, tagged `direct-kv-zero-wrapper-v3`
- Accepted stable mean: `172.1080 tok/s`; best accepted block: `172.2590`
- Historical Ollama Q4R8 ScaleSearch median: `179.5662 tok/s`
- Tie threshold: greater than `179.5662 tok/s`
- Five-percent win threshold: greater than `188.5445 tok/s`
- Candidate promotion gate: correct output, at least `+1%`, and absolute drift
  no greater than `1%` in controlled forward and reverse brackets

The compiled Laguna block-tail experiment is the highest correct measured arm
so far at `177.499062770142 tok/s`. Its same-loaded alternating A/B effect is
`+0.935598000375%`, which misses the `+1%` promotion gate and remains
`1.151196623690%` below Ollama, so it is preserved but not promoted. The clean
incremental ByteLevel branch remains its source baseline; its definitive
final-binary v2 order-balanced result is `+2.466914598390%`, but its forward
control drift remains just outside the strict stability boundary. Raw evidence
is under `benchmark-results/incremental-final-binary-20260830/` and
`benchmark-results/laguna-compiled-block-tail-20260830/`.

The subsequent fused Laguna QKVG projection was rejected. Its same-loaded
screening arm measured `-0.171863260430%`, and the 128-token legacy and fused
streams diverged after 304 output characters. Raw failure evidence is under
`benchmark-results/laguna-fused-qkvg-20260830/`; no accepted branch changed.

The decode-only compiled attention prelude is numerically correct when its
graph stops before RoPE, but performance-neutral. Its same-loaded median effect
was `+0.207863954995%`, while the order-balanced geometric effect was only
`+0.034787554331%`. Heavy unrelated host activity invalidates its absolute rate
as an Ollama comparison, and the relative effect misses the `+1%` gate by a
wide margin. Raw evidence is under
`benchmark-results/laguna-compiled-attention-prelude-20260830/`.

The last-stream Metal command-encoder lookup cache is also correct but
performance-neutral. On the exact Q4R8 ScaleSearch checkpoint, its median
effect was `-0.053761301784%` and its order-balanced geometric effect was
`-0.016529798294%`. A second standard-Q4 screen was likewise neutral. Raw
evidence is under `benchmark-results/metal-command-encoder-cache-20260830/`;
the cache remains disabled by default and is not promoted.

The persistent stateless `mlx_compile` closure candidate is lifetime-safe and
produces exact output, but it does not remove measurable decode overhead on the
consolidated compiled-tail stack. Its same-loaded median effect was
`-0.062702219450%` and its geometric/order-balanced effect was
`-0.042423215199%`. Raw evidence is under
`benchmark-results/persistent-compiled-closures-20260830/`; the path remains
disabled by default and is not promoted.

## Performance milestone index

| Tag | Commit | Status | Result or disposition |
| --- | --- | --- | --- |
| `pre-direct-kv-optimization` | `1ee1989` | Original native baseline | `166.0916 tok/s` |
| `direct-kv-fast-path-v1` | `b766eac` | First direct-KV candidate | Preserved source |
| `direct-kv-measured-v1` | `2b1ef4c` | Measured direct-KV campaign | `172.1080 tok/s` stable evidence; formal ABBA rejected |
| `direct-kv-fast-path-v2` | `f1bc642` | Bounds-allocation removal | Superseded by v3 |
| `direct-kv-zero-wrapper-v3` | `7238a63` | Accepted production baseline | `172.1080 tok/s` stable mean; `172.2590` best block |
| `generation-loop-autorelease-candidate-v1` | `ce67075` | Preserved candidate | Inconclusive; not promoted |
| `token-loop-decoder-candidate-v1` | `f1233c5` | Autorelease plus in-place decoder candidate | Not promoted alone |
| `token-loop-decoder-measured-v1` | `22f077c` | Mixed-order evidence | `+0.6514%` descriptive; order estimates crossed zero |
| `token-loop-decoder-isolation-v1` | `c1f97d3` | Invalid stability campaign | Not promoted |
| `incremental-bytelevel-decoder-candidate-v1` | `2b09357` | Historical mixed-branch candidate | Correctness passed; superseded by clean source tag |
| `incremental-bytelevel-decoder-measured-v1` | `e120a83` | Initial incremental measurement | `+0.4822%` to `+0.5501%`; preserved, not promoted |
| `consolidated-decoder-fast-path-candidate-v1` | `38604eb` | Clean incremental plus in-place candidate | Correctness passed |
| `performance-milestone-registry-v1` | `7d41c3b` | Registry snapshot | No performance decision |
| `stable-string-cache-candidate-v1` | `59e2605` | Bounded stable-string cache candidate | Correctness passed |
| `stable-string-cache-measured-v1` | `cc51e45` | Measured stable-string cache | `-0.4698%` balanced; rejected |
| `consolidated-decoder-fast-path-measured-v1` | `2f889d5` | Measured incremental plus in-place candidate | `+0.127683%` balanced; performance-neutral, not promoted |
| `incremental-fast-path-clean-v1` | `f613995` | Clean incremental-only source boundary | Correctness and patch verification passed |
| `incremental-fast-path-final-binary-measured-v1` | `c5ca138` | Definitive same-final-binary measurement | `+2.466914598390%` v2 balanced; `+2.213684635318%` confirmation; stability recheck required |
| `laguna-compiled-block-tail-candidate-v1` | `b103114` | Guarded decode-only compiled tail | Nine focused Laguna tests passed |
| `laguna-compiled-block-tail-measured-v1` | `9cbdd94` | Same-loaded alternating A/B evidence | `177.499062770142 tok/s`, `+0.935598000375%`; correct but below gate and Ollama |
| `laguna-fused-qkvg-candidate-v1` | `f6feaf2` | Guarded fused Q/K/V/gate projection | Short-horizon tests passed; Release screening required |
| `laguna-fused-qkvg-rejected-v1` | `62d7ea7` | Same-loaded failure evidence | `-0.171863260430%`; 128-token streams diverged; rejected |
| `laguna-compiled-attention-prelude-candidate-v1` | `6949c23` | Separate-width decode-only compiled prelude | Eleven focused Laguna tests and real Q4 smoke passed exactly |
| `laguna-compiled-attention-prelude-measured-v1` | `fc9b71f` | Same-loaded alternating A/B evidence | `+0.034787554331%` order-balanced; performance-neutral, not promoted |
| `metal-command-encoder-cache-candidate-v1` | `b27d10b` | Default-off last-stream encoder cache | Host-Metal functional and Laguna regression tests passed |
| `metal-command-encoder-cache-measured-v1` | `29bbf61` | Exact-model same-loaded alternating A/B evidence | `-0.016529798294%` order-balanced; performance-neutral, not promoted |
| `persistent-compiled-closure-candidate-v1` | `861793f` | Default-off stateless public-compile closure | Patch cycles, lifetime tests, and real Q4 smoke passed exactly |
| `persistent-compiled-closure-measured-v1` | this commit | Exact-model same-loaded alternating A/B evidence | `-0.042423215199%` order-balanced; performance-neutral, not promoted |

## Clean incremental candidate

Branch `codex/incremental-fast-path` starts at accepted direct-KV v3 and adds
only guarded incremental ByteLevel streaming detokenization. It explicitly
excludes the in-place outer decoder, generation-loop autorelease candidate,
QMV experiments, and stable-string cache.

- Clean source tag: `incremental-fast-path-clean-v1`
- Candidate binary SHA-256:
  `93c85328a8d1809113df6134a13b2090bd456cdefb8a866a2a9d9b9718dbaa96`
- Accepted control binary SHA-256:
  `59536631ba31e251bd0f71424262aa334faa48cf86fa8d9df60afdcab97ce93c`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`

All 72 definitive measured generations produced correct, identical 128-token
outputs. The reverse bracket passed the drift gate and every candidate block
was stable. Accepted `main` is deliberately unchanged pending a stable forward
control bracket.

## Compiled Laguna block-tail candidate

Branch `codex/compiled-tail-fast-path` adds one guarded compiled graph per
Laguna decoder layer for the post-attention gate, output projection, residual,
post-attention normalization, and dense or sparse MLP tail. It is off by
default outside its explicit runtime benchmark A/B mode.

- Source tag: `laguna-compiled-block-tail-candidate-v1`
- Candidate release binary SHA-256:
  `2180fc576de2ba066b7d471d4d01fc25a58c5a04d5d1141b75ff6e138198217f`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Same-loaded median: eager `175.853778336442 tok/s`, compiled
  `177.499062770142 tok/s`
- Effect: `+0.935598000375%`
- Gap to Ollama: `2.067160297239 tok/s` (`1.151196623690%`)

All measured outputs match exactly. This candidate is a rollback boundary and
an input to the next attention-side experiment, not an accepted production
change.

## Rejected fused Laguna QKVG candidate

Branch `codex/fused-qkvg-fast-path` retains a diagnostic-only QKVG projection
on top of the compiled block-tail milestone. Both tensor layouts coexist so a
single loaded checkpoint can alternate legacy and fused execution.

- Source tag: `laguna-fused-qkvg-candidate-v1`
- Candidate release binary SHA-256:
  `09bfa82661f9f16755ce5538b51174543b93ec021527f92c6f296baf184c9f0f`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Same-loaded median: legacy `168.565299333401 tok/s`, fused
  `168.275597514012 tok/s`
- Effect: `-0.171863260430%`

The absolute rates are not a valid Ollama comparison because unrelated host
workers were active. The candidate is nevertheless decisively rejected: the
relative effect is negative and the deterministic 128-token streams are not
identical. This rollback boundary exists to prevent the failed path from being
rediscovered or accidentally consolidated.

## Performance-neutral compiled attention prelude

Branch `codex/compiled-attention-prelude-fast-path` starts from the measured
compiled block-tail milestone. It compiles input normalization plus separate
Q/K/V projection, reshape, Q/K normalization, and transpose operations only
during batch-one, one-token cached decode. Projection widths remain unchanged;
RoPE, cache mutation, SDPA, the attention gate, and the compiled block tail
retain their existing paths.

- Source tag: `laguna-compiled-attention-prelude-candidate-v1`
- Candidate release binary SHA-256:
  `037115f053defe73fa7553f352481a81e53ff999257381be8a845609e74d6534`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Same-loaded median: eager `165.035273280416 tok/s`, compiled
  `165.378322126595 tok/s`
- Serialized median effect: `+0.207863954995%`
- Order-balanced geometric effect: `+0.034787554331%`

All measured outputs match exactly, and all six paired effects fall between
`-0.869039089689%` and `+0.805212826617%`. The absolute rates are invalid for
an Ollama comparison because `mediaanalysisd` consumed roughly 128-132% CPU
during the campaign. The near-zero alternating relative result is sufficient
to classify the candidate as neutral and keep it out of production.

## Rejected Metal command-encoder cache

Branch `codex/global-encoder-cache-fast-path` starts from the measured compiled
block-tail milestone. It adds a default-off, generation-invalidated,
thread-local cache for the last Metal stream's `CommandEncoder`. The A/B harness
keeps the compiled attention gate, MoE, and block tail enabled in both arms.

- Source tag: `metal-command-encoder-cache-candidate-v1`
- Candidate release binary SHA-256:
  `2239e5f0200e02e7fb4066b1f0854bab04ac48ae76cc00161967298f88e1a726`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Exact ScaleSearch median: OFF `177.099891139778 tok/s`, ON
  `177.004679932843 tok/s`
- Serialized median effect: `-0.053761301784%`
- Order-balanced geometric effect: `-0.016529798294%`

All primary outputs match exactly. Darwin and Linux patch-cycle checks, the
GPU-backed toggle test, and all nine focused Laguna tests pass. The effect is
neutral to slightly negative, so this candidate is preserved as a rollback
boundary and excluded from production.

## Rejected persistent compiled-closure candidate

Branch `codex/persistent-compiled-closure-fast-path` starts from the measured
compiled block-tail milestone. It retains one public `mlx_compile` C closure
for each stateless Swift `CompiledFunction`; observed-state functions retain
the existing transient detail-compile path. The feature is process-global,
disabled by default, and toggled only across a complete benchmark generation.

- Source tag: `persistent-compiled-closure-candidate-v1`
- Candidate release binary SHA-256:
  `a81c5c046c86a9b66697ff218b04590962d663b0ed95c52df09536dcb8a11032`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Same-loaded median: transient `177.420380896899 tok/s`, persistent
  `177.309134380321 tok/s`
- Serialized median effect: `-0.062702219450%`
- Order-balanced geometric effect: `-0.042423215199%`

All primary outputs match exactly. Darwin and Linux patch-cycle checks, four
focused ownership/behavior tests, all nine Laguna model tests, and a real Q4
smoke pass. The effect is neutral to slightly negative, so the candidate is a
rollback boundary only and is excluded from production.

## Standalone Swift server

The educational OpenAI-compatible Swift server is intentionally separate from
the optimized performance runner. Historical repository snapshots remain at:

| Tag | Commit | Purpose |
| --- | --- | --- |
| `simple-swift-model-server-v1` | `7228a9f` | Minimal historical server |
| `simple-swift-model-server-v2` | `a3cde16` | Self-contained server snapshot |
| `simple-swift-model-server-v3` | `00c09cc` | Current historical repository snapshot |

Ongoing server work belongs to its independent local Git project at
`/Users/stephen/Documents/ChatGPT/simple-swift-model-runner`; the optimized
runner does not depend on that project or its archived ZIPs.
