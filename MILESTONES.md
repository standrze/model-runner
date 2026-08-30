# Midnight performance milestones

This registry indexes Midnight's reproducible source and measurement
boundaries. Detailed validity notes and raw reports live under
`benchmark-results/`. Annotated Git tags are rollback points; accepted `main`
remains unchanged until a candidate passes both correctness and the predeclared
stability gate.

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

- Accepted production milestone: `d79760e`, tagged
  `laguna-fused-router-topk-production-v1`; `origin/main` includes it
- Accepted default-on median: `185.291435150063 tok/s`; geometric mean:
  `184.905172116502 tok/s`
- Previous production baseline: `7238a63`, tagged `direct-kv-zero-wrapper-v3`
- Historical Ollama Q4R8 ScaleSearch median: `179.5662 tok/s`
- Tie threshold: greater than `179.5662 tok/s`
- Five-percent win threshold: greater than `188.5445 tok/s`
- Candidate promotion gate: correct output, at least `+1%`, and absolute drift
  no greater than `1%` in controlled forward and reverse brackets

The fused Laguna router top-k stack is the highest correct measured build. Its
conservative same-loaded confirmation reached `183.753624693681 tok/s`, beat
the compiled-tail control by `+3.483719502080%`, and cleared the strict
stability gate twice. The ordinary default-on production path then reached
`185.291435150063 tok/s` with `-0.147554408633%` early/late drift: a
`5.725212082682 tok/s` (`+3.188356910828%`) lead over the historical exact
Ollama median. Raw evidence is under
`benchmark-results/laguna-fused-router-topk-20260830/`; both the default-off
measured source and default-on production source are separate rollback points.

The earlier compiled Laguna block-tail experiment reached
`177.499062770142 tok/s`, but its isolated `+0.935598000375%` effect missed the
`+1%` promotion gate. It is nevertheless part of the now-passing fused-router
stack. The clean incremental ByteLevel branch remains its source baseline; its
definitive final-binary v2 order-balanced result is `+2.466914598390%`, but its
forward control drift remains just outside the strict stability boundary.

Subsequent isolated experiments were preserved but excluded from the winning
stack: fused QKVG was slower and changed output; the compiled attention
prelude, last-stream Metal encoder cache, and persistent compiled closure were
all token-correct but performance-neutral or slightly negative. Their
respective measured branches and annotated tags remain rollback points.

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
| `laguna-compiled-attention-prelude-candidate-v1` | `6949c23` | Separate-width decode-only compiled prelude | Real Q4 smoke passed exactly |
| `laguna-compiled-attention-prelude-measured-v1` | `fc9b71f` | Same-loaded alternating A/B evidence | `+0.034787554331%` order-balanced; neutral |
| `metal-command-encoder-cache-candidate-v1` | `b27d10b` | Default-off last-stream encoder cache | Functional and regression tests passed |
| `metal-command-encoder-cache-measured-v1` | `29bbf61` | Same-loaded alternating A/B evidence | `-0.016529798294%` order-balanced; neutral |
| `persistent-compiled-closure-candidate-v1` | `861793f` | Default-off retained stateless compile closure | Lifetime and real-Q4 checks passed |
| `persistent-compiled-closure-measured-v1` | `abc5262` | Same-loaded alternating A/B evidence | `-0.042423215199%` order-balanced; neutral |
| `laguna-fused-router-topk-candidate-v1` | `c6c29da` | One-dispatch stable biased top-8 decode router | Exact unit, tiny-model, and real-Q4 checks passed |
| `laguna-fused-router-topk-measured-v1` | `9279a5f` | Two independent same-loaded campaigns | `183.753624693681 tok/s`; `+3.48%` / `+4.18%`; beats Ollama |
| `laguna-fused-router-topk-production-source-v1` | `8fa0f0a` | Metal-only automatic production selection | Full 108-test suite and Release build passed |
| `laguna-fused-router-topk-production-v1` | `d79760e` | Default-on production confirmation | `185.291435150063 tok/s`; `+3.188356910828%` ahead of Ollama |

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

## Fused Laguna router top-k candidate

Branch `codex/fused-laguna-router-fast-path` starts from the measured compiled
block-tail milestone. For the single-row 256-expert/top-8 sparse decode shape,
it replaces the stable full sort, gather, and reduction router tail with one
Metal threadgroup. The existing FP32 sigmoid and correction-bias semantics are
unchanged; prefill and unsupported shapes keep the original path.

- Source tag: `laguna-fused-router-topk-candidate-v1`
- Candidate release binary SHA-256:
  `e6fad6d3ef1cbf6387c4ace6dd41532ad71c0bea9fed301a1fd2d544515d27a8`
- Shared metallib SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`
- Confirmation v1: legacy `177.567665307960 tok/s`, fused
  `183.753624693681 tok/s` (`+3.483719502080%` median)
- Confirmation v2: legacy `176.412709399813 tok/s`, fused
  `183.782052267099 tok/s` (`+4.177331039446%` median)
- Lead over historical Ollama: `4.187401626300 tok/s`
  (`+2.331953947001%`)

All FP32, FP16, and BF16 router results are bit-identical, including stable
ties. Tiny cached-decode logits and all real-Q4 benchmark outputs are exact.
Early/late drift remained below `1%` in both confirmation campaigns. This is
the first experimental stack to clear every promotion gate.

The separate production source commit selects both fast paths automatically
only when `LocalModelRunner` resolves the Metal engine. It preserves explicit
scoped overrides and leaves CPU/CUDA unchanged. The ordinary no-flag Release
benchmark reached `185.291435150063 tok/s` (geometric mean
`184.905172116502`) with `-0.147554408633%` early/late drift. Its release
binary SHA-256 is
`fc9b1ad973f1fc1d27b046f3d462aae1163bf72aff697da5a1e22fd53105f385`.

## Standalone Swift server

The educational OpenAI-compatible Swift server is intentionally separate from
Midnight. Historical repository snapshots remain at:

| Tag | Commit | Purpose |
| --- | --- | --- |
| `simple-swift-model-server-v1` | `7228a9f` | Minimal historical server |
| `simple-swift-model-server-v2` | `a3cde16` | Self-contained server snapshot |
| `simple-swift-model-server-v3` | `00c09cc` | Current historical repository snapshot |

Ongoing server work belongs to an independent Git project; Midnight does not
depend on that project or its archived ZIPs.
