# vLLM-Metal vs native Laguna — 2026-08-30

## Fastest local quant: affine Q3

The standard MLX affine-Q3/group-64 Laguna is the fastest locally available
quantization and gives vLLM-Metal a native fast-path format. Both engines ran
the same three SafeTensors shards with no requantization. The native runner
still won: **177.48 tok/s** versus vLLM-Metal's best block at **124.26 tok/s**,
a **42.83% native lead**.

| Deployment | Median decode | Median TTFT | Median end-to-end | Relative decode |
| --- | ---: | ---: | ---: | ---: |
| Native runner, current release build | **177.48 tok/s** | **56.65 ms** | **174.38 tok/s** | **+42.83%** |
| vLLM-Metal, first block | 124.26 tok/s | 67.82 ms | 122.45 tok/s | control |
| vLLM-Metal, reverse-order repeat | 123.92 tok/s | 67.33 ms | 122.02 tok/s | -0.28% vs first |

Each block used one excluded warm-up followed by five 512-token trials:

```text
vLLM Q3 first:   123.98  124.26  123.84  126.83  127.09
native Q3:       178.97  177.80  177.48  175.00  174.61
vLLM Q3 repeat:  123.92  120.69  111.12  126.21  125.01
```

All trials reported 50 prompt tokens, 512 completion tokens, and
`finish_reason: "length"`. Output was deterministic within each engine, though
the two engines' free-running completions differed. The vLLM/native/vLLM order
confirms that run order does not explain the roughly 43% gap.

Q3 raised the observed native rate by 5.52% and vLLM's by 6.13% relative to the
earlier Q4R8 runs. Those cross-quant uplifts are directional rather than a
strict quantization A/B: this cached Q3 model is stock Poolside Laguna and uses
a different tokenizer/template (50 prompt tokens), while the Q4R8 model is the
abliterated derivative (79 prompt tokens). The Q3 engine-to-engine comparison
itself is exact-artifact fair.

vLLM-Metal pins MLX 0.32.0 in its installed package. The native runner uses its
repository-pinned MLX-Swift dependency, so these figures compare the supported
deployment stacks rather than forcing an unsupported dependency substitution.

## Original abliterated Q4R8 outcome

The current native Swift/Metal runner won this single-request Laguna benchmark.
Its median decode rate was **168.19 tok/s**, versus **117.09 tok/s** for the
best measured vLLM-Metal configuration. Native was **43.65% faster** by that
comparison; equivalently, tuned vLLM-Metal delivered 30.38% fewer tokens per
second.

| Deployment | Median decode | Median TTFT | Median end-to-end | Relative decode |
| --- | ---: | ---: | ---: | ---: |
| Native runner, current release build | **168.19 tok/s** | **78.52 ms** | **164.28 tok/s** | **+43.65%** |
| vLLM-Metal, tuned 0.40 memory utilization | 117.09 tok/s | 87.05 ms | 115.03 tok/s | control |
| vLLM-Metal, initial block at 0.70 | 112.62 tok/s | 87.86 ms | 110.70 tok/s | -3.81% vs tuned |
| vLLM-Metal, reverse-order repeat at 0.70 | 113.17 tok/s | 88.26 ms | 111.20 tok/s | -3.34% vs tuned |

Native also reduced median visible time-to-first-token by 9.79% and raised
end-to-end token throughput by 42.81% relative to the tuned vLLM run.

## Measured trials

Each block used one excluded warm-up followed by five measured generations.

```text
native:            168.22  168.11  169.05  166.16  168.19
vLLM 0.70 first:   114.16  111.40  112.31  112.62  113.54
vLLM 0.70 repeat:  113.17  112.62  113.38  110.54  113.97
vLLM 0.40 tuned:   117.58  117.25  116.89  116.68  117.09
```

The engine order was vLLM, native, vLLM. The final vLLM memory-tuned block was
then run after the reverse-order repeat. The two 0.70 vLLM blocks bracket the
native measurement and remained stable, reducing order and thermal ambiguity.

## Test setup

- Machine: 40-GPU-core M5 Max MacBook with 64 GiB unified memory, on AC power.
- Model: `Laguna-XS-2.1-Abliterated-Q4R8-ScaleSearch-LS2`.
- Tensor payload: the exact 18,821,963,264-byte Q4R8 checkpoint used by the
  native runner; no weights were requantized.
- Native runtime: the repository's current `midnight` release build.
- vLLM runtime: vLLM `0.28.0+cpu`, vLLM-Metal
  `0.4.0.dev20260830090220`, MLX `0.32.0`, and MLX-LM `0.31.3`.
- Request: concurrency 1, 79 prompt tokens, greedy decoding, thinking disabled,
  512 completion tokens, and prefix caching disabled.
- Primary metric: `(completion_tokens - 1) / (finish - first visible token)`.
  Role-only and empty SSE chunks were excluded from TTFT.
- A fresh HTTP connection was used for every request.
- Every measured request reported 512 completion tokens and
  `finish_reason: "length"`.

The prompt was:

> Write a long, detailed technical tutorial about implementing a lock-free
> work-stealing scheduler in Swift. Continue with implementation details and
> code examples until the output limit; do not conclude or summarize early.

The tuned vLLM block used `--gpu-memory-utilization 0.40`. Its startup audit
reported 22.27 GB usable Metal memory: 18.82 GB model, 1.75 GB overhead, and a
1.69 GB KV cache capable of 10,336 tokens. That was comfortably above the
2,048-token configured context ceiling. Reducing the oversized initial KV
allocation improved vLLM's median from roughly 113 to 117.09 tok/s.

## Exact-checkpoint compatibility

Upstream vLLM-Metal/MLX-LM could not directly load the native checkpoint's
wrapper namespace, fused gate/up storage, and affine-Q8 MoE routers. The
benchmark used a compatibility view that:

- symlinked the original SafeTensors shards without copying their payload;
- removed the `language_model.` wrapper from metadata and load-time names;
- exposed the 79 fused gate/up tensors as exact MLX slices;
- represented the 39 router projections as quantizable linear modules so their
  existing affine-Q8 values loaded unchanged.

`build_vllm_laguna_compat.py` creates the metadata/symlink view. The companion
`mlx-lm-laguna-q4r8.patch` records the small MLX-LM loader adaptation used via a
temporary `PYTHONPATH` overlay. Neither operation alters or requantizes tensor
values.

## Output parity and evidence boundary

The two runtimes rendered the same 79-token prompt, and a 16-token smoke test
produced byte-identical text. Their free-running 512-token completions were
deterministic within each runtime but diverged at UTF-8 byte 304. This can occur
from small numerical/expert-routing differences and means the result is a
same-prompt deployment throughput comparison, not a teacher-forced
identical-output-token kernel comparison.

This benchmark answers batch-one decode speed for one short prompt and 512-token
completion. It does not establish the winner for concurrent serving, long
contexts, continuous batching, or throughput under load; those are areas where
vLLM's scheduler and paged KV cache may change the result.

## Artifacts

- `native-laguna-3bit-512x5.json`: native Q3 raw trials.
- `vllm-laguna-3bit-512x5.json`: first vLLM Q3 block.
- `vllm-laguna-3bit-512x5-repeat.json`: reverse-order vLLM Q3 block.
- `native-laguna-512x5.json`: native raw trials and generated text.
- `vllm-laguna-512x5.json`: first vLLM 0.70 block.
- `vllm-laguna-512x5-repeat.json`: reverse-order vLLM 0.70 block.
- `vllm-laguna-512x5-memory040.json`: best vLLM block.
- `laguna_sse_benchmark.py`: shared SSE benchmark client.
- `build_vllm_laguna_compat.py`: exact-tensor compatibility-view builder.
- `mlx-lm-laguna-q4r8.patch`: MLX-LM compatibility overlay patch.
