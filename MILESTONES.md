# Performance milestones

This file is the short index for reproducible performance states. Raw reports
and detailed validity notes live under `benchmark-results/`. Annotated Git tags
are the rollback boundaries; accepted `main` is not moved until a candidate
passes its correctness and stability gates.

## Restore safely

Inspect a milestone without moving a branch:

```sh
git switch --detach TAG
```

Start a new branch from it:

```sh
git switch -c codex/restore-TAG TAG
```

These commands leave later milestones intact. Avoid resetting a dirty working
tree to a tag.

## Current comparison target

- Historical Ollama Q4R8 ScaleSearch median: `179.5662 tok/s`
- Tie threshold: greater than `179.5662 tok/s`
- Five-percent win threshold: greater than `188.5445 tok/s`
- Candidate promotion gate: stable correctness plus at least `+1%` in
  controlled forward and reverse brackets

## Milestone index

| Tag | Commit | Status | Decode result |
| --- | --- | --- | ---: |
| `pre-direct-kv-optimization` | `1ee1989` | Original native baseline | `166.0916 tok/s` |
| `direct-kv-fast-path-v1` | `b766eac` | First direct-KV candidate | See raw milestone reports |
| `direct-kv-measured-v1` | `2b1ef4c` | Measured direct-KV campaign | See raw milestone reports |
| `direct-kv-fast-path-v2` | `f1bc642` | Bounds-allocation removal | Superseded by v3 |
| `direct-kv-zero-wrapper-v3` | `7238a63` | Accepted production baseline | `172.1080 tok/s` stable mean; `172.2590` best block |
| `generation-loop-autorelease-candidate-v1` | `ce67075` | Preserved, inconclusive | Not promoted |
| `token-loop-decoder-candidate-v1` | `f1233c5` | Preserved source candidate | Not promoted alone |
| `token-loop-decoder-measured-v1` | `22f077c` | Mixed-order evidence | `+0.6514%` descriptive; crossed zero by order |
| `token-loop-decoder-isolation-v1` | `c1f97d3` | Invalid stability campaign | Not promoted |
| `incremental-bytelevel-decoder-candidate-v1` | `2b09357` | Preserved source candidate | Correctness passed |
| `incremental-bytelevel-decoder-measured-v1` | `e120a83` | Small repeatable win | `+0.4822%` to `+0.5501%`; not promoted alone |
| `consolidated-decoder-fast-path-candidate-v1` | `38604eb` | Clean v3 + incremental + in-place candidate | Composite benchmark pending |
| `stable-string-cache-candidate-v1` | `59e2605` | Bounded decoded-string cache; correctness passed | Clean benchmark pending |
| `stable-string-cache-measured-v1` | `cc51e45` | Rejected after clean dual-order campaign | `-0.4698%` balanced; not promoted |

## Clean consolidated candidate

Branch `codex/consolidated-fast-path` starts at accepted direct-KV v3 and adds
only these two host-side changes:

1. Guarded incremental ByteLevel streaming detokenization.
2. In-place mutation of the outer token-loop decoder existential.

It deliberately excludes the inconclusive generation-loop autorelease change
and all rejected QMV experiments. The release binary built from the equivalent
isolated source tree has SHA-256
`600dd4d515d08c077d6cc87f345013b20d1f438ba1bfa480be9a2a16f93272c6`;
its metallib SHA-256 is
`903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`.
A real Laguna Metal smoke generation passed. End-to-end promotion remains
pending a clean bracket uncontaminated by background media analysis.

## Simple Swift server

The educational OpenAI-compatible Swift server is intentionally separate from
the optimized runner. Historical repository artifacts remain available at
tags `simple-swift-model-server-v1`, `simple-swift-model-server-v2`, and
`simple-swift-model-server-v3`; ongoing server work belongs in its independent
project rather than this performance branch.
