# Laguna fused QKVG screening A/B (2026-08-30)

## Scope

This experiment starts from the measured compiled Laguna block-tail milestone
and adds a guarded fused projection for query, key, value, and the per-head
attention gate. The same loaded model retains both legacy and fused tensors so
the runtime benchmark can alternate the two paths without reload or binary
changes. The fused path is off by default outside the explicit A/B mode.

- Source commit: `f6feaf2`
- Model: `Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2`
- Engine: Metal
- Prompt: 79 uncached tokens
- Generation: greedy, 128 requested tokens
- Warmups: two per mode
- Measured trials: six per mode, alternating `AB` / `BA`
- Release benchmark binary SHA-256:
  `09bfa82661f9f16755ce5538b51174543b93ec021527f92c6f296baf184c9f0f`
- Metal library SHA-256:
  `903daf038bc9e65c6b77ccb3dc023df6435cf50d4d2dc78ed950a711f68be48c`

## Result

| Mode | Median decode (tok/s) |
| --- | ---: |
| Legacy Q/K/V/gate projections | `168.565299333401` |
| Fused QKVG projection | `168.275597514012` |

The same-loaded fused arm measured `-0.171863260430%`. This run occurred while
unrelated macOS media-analysis and PDF-rendering workers were intermittently
active, so its absolute rates must not be compared with the quiet-host Ollama
reference. The alternating result is sufficient to screen out this candidate:
it is not directionally positive, and it also fails correctness.

## Correctness and evidence integrity

The strengthened focused `LagunaModelTests` suite passed all 12 tests, including
exact tiny-model logits and KV-cache tensors. A one-token real-checkpoint debug
smoke also matched exactly. The 128-token Release run revealed the missing
long-horizon gate: each arm was internally deterministic, but legacy and fused
streams first differed after 304 output characters.

- Legacy content SHA-256:
  `5b8e8efa2dd96fdc936e519d6f0922a1d4b0693dbf13167abfdea592d54d5946`
- Fused content SHA-256:
  `b250b4b04de9f6a0a7a254f54f39a4666e1e3d9c416cb508ace676cf06266847`
- Raw report SHA-256:
  `c3a6f38c1f2018c57cb7abb82f4e89dce78b654cc080f7b509ec9261b453b27a`

The packed rows are copied without requantization, but changing the projection
output geometry can select a different Metal reduction layout. Small floating-
point differences can therefore accumulate until greedy token selection
changes even though each output row is mathematically independent.

## Decision

Reject and preserve for diagnosis only. The candidate is slower in its own
same-loaded comparison and does not preserve the full generated stream. It is
not eligible for production promotion or for an absolute Ollama comparison.
Accepted `main`, the clean incremental milestone, and the compiled-tail
milestone remain unchanged.
