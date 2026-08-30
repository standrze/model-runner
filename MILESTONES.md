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
`1.151183925404%` below Ollama, so it is preserved but not promoted. The clean
incremental ByteLevel branch remains its source baseline; its definitive
final-binary v2 order-balanced result is `+2.466914598390%`, but its forward
control drift remains just outside the strict stability boundary. Raw evidence
is under `benchmark-results/incremental-final-binary-20260830/` and
`benchmark-results/laguna-compiled-block-tail-20260830/`.

The subsequent fused Laguna QKVG projection was rejected. Its same-loaded
screening arm measured `-0.171863260430%`, and the 128-token legacy and fused
streams diverged after 304 output characters. Raw failure evidence is under
`benchmark-results/laguna-fused-qkvg-20260830/`; no accepted branch changed.

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
| `incremental-fast-path-final-binary-measured-v1` | this commit | Definitive same-final-binary measurement | `+2.466914598390%` v2 balanced; `+2.213684635318%` confirmation; stability recheck required |
| `laguna-compiled-block-tail-candidate-v1` | `b103114` | Guarded decode-only compiled tail | Nine focused Laguna tests passed |
| `laguna-compiled-block-tail-measured-v1` | this commit | Same-loaded alternating A/B evidence | `177.499062770142 tok/s`, `+0.935598000375%`; correct but below gate and Ollama |
| `laguna-fused-qkvg-candidate-v1` | `f6feaf2` | Guarded fused Q/K/V/gate projection | Short-horizon tests passed; Release screening required |
| `laguna-fused-qkvg-rejected-v1` | this commit | Same-loaded failure evidence | `-0.171863260430%`; 128-token streams diverged; rejected |

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
- Gap to Ollama: `2.067137229858 tok/s` (`1.151183925404%`)

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
