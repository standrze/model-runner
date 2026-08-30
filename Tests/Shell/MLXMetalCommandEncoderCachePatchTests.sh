#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$PACKAGE_ROOT/Scripts/swiftpm-scratch-path.sh"
model_runner_configure_swiftpm_scratch "$PACKAGE_ROOT" "$(uname -s)"
PATCH_HOST_OS="${MODEL_RUNNER_PATCH_TEST_HOST_OS:-$(uname -s)}"

MLX_SWIFT_CHECKOUT="$MODEL_RUNNER_SWIFTPM_SCRATCH_PATH/checkouts/mlx-swift"
MLX_CHECKOUT="$MLX_SWIFT_CHECKOUT/Source/Cmlx/mlx"
MLX_C_CHECKOUT="$MLX_SWIFT_CHECKOUT/Source/Cmlx/mlx-c"
MLX_PATCH="$PACKAGE_ROOT/Patches/mlx-metal-command-encoder-cache.patch"
MLX_C_PATCH="$PACKAGE_ROOT/Patches/mlx-c-metal-command-encoder-cache.patch"
MLX_SWIFT_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-metal-command-encoder-cache.patch"

case "$PATCH_HOST_OS" in
  Darwin)
    MLX_REVISION="1f8e74e3f12f31365464a6867c6579f0e9b29d85"
    MLX_C_REVISION="c74db5307cc8ce122f48d97ef951b30578674e7f"
    MLX_SWIFT_REVISION="72f3c3ad8aeee39bfc94f8fbeb446cac89e3a798"
    ;;
  Linux)
    MLX_REVISION="7a1d4f5c12ac82f4b4d0a6e71538d89ca0605247"
    MLX_C_REVISION="fba4470b89073180056c9ea46c443051375f7399"
    MLX_SWIFT_REVISION="2d2724006b62855c6c2a71df633baf4ee4ad8a0f"
    ;;
  *)
    echo "Unsupported host" >&2
    exit 1
    ;;
esac

for checkout in "$MLX_CHECKOUT" "$MLX_C_CHECKOUT" "$MLX_SWIFT_CHECKOUT"; do
  [[ -d "$checkout/.git" || -f "$checkout/.git" ]] || {
    echo "Missing prepared dependency checkout: $checkout" >&2
    exit 1
  }
done

FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

reconstruct_revision() {
  local checkout="$1"
  local revision="$2"
  local destination="$3"

  mkdir -p "$destination"
  git -C "$checkout" archive "$revision" | tar -xf - -C "$destination"
  git -C "$destination" init -q
}

cycle_patch() {
  local checkout="$1"
  local patch="$2"

  git -C "$checkout" apply --check "$patch"
  git -C "$checkout" apply "$patch"
  git -C "$checkout" apply --reverse --check "$patch"
  git -C "$checkout" apply --reverse "$patch"
  git -C "$checkout" apply --check "$patch"
  git -C "$checkout" apply "$patch"
}

MLX_FIXTURE="$FIXTURE_ROOT/mlx"
MLX_C_FIXTURE="$FIXTURE_ROOT/mlx-c"
MLX_SWIFT_FIXTURE="$FIXTURE_ROOT/mlx-swift"
reconstruct_revision "$MLX_CHECKOUT" "$MLX_REVISION" "$MLX_FIXTURE"
reconstruct_revision "$MLX_C_CHECKOUT" "$MLX_C_REVISION" "$MLX_C_FIXTURE"
reconstruct_revision "$MLX_SWIFT_CHECKOUT" "$MLX_SWIFT_REVISION" "$MLX_SWIFT_FIXTURE"

if [[ "$PATCH_HOST_OS" == "Linux" ]]; then
  git -C "$MLX_FIXTURE" apply "$PACKAGE_ROOT/Patches/mlx-global-stream-cleanup.patch"
  git -C "$MLX_C_FIXTURE" apply "$PACKAGE_ROOT/Patches/mlx-c-clear-streams.patch"
  git -C "$MLX_C_FIXTURE" apply "$PACKAGE_ROOT/Patches/mlx-c-clear-global-streams.patch"
  git -C "$MLX_SWIFT_FIXTURE" apply "$PACKAGE_ROOT/Patches/mlx-swift-cross-thread-stream.patch"
  git -C "$MLX_SWIFT_FIXTURE" apply "$PACKAGE_ROOT/Patches/mlx-swift-clear-streams.patch"
fi

cycle_patch "$MLX_FIXTURE" "$MLX_PATCH"
cycle_patch "$MLX_C_FIXTURE" "$MLX_C_PATCH"
cycle_patch "$MLX_SWIFT_FIXTURE" "$MLX_SWIFT_PATCH"

DEVICE_CPP="$MLX_FIXTURE/mlx/backend/metal/device.cpp"
METAL_EVAL="$MLX_FIXTURE/mlx/backend/metal/eval.cpp"
NO_METAL="$MLX_FIXTURE/mlx/backend/metal/no_metal.cpp"
C_STREAM="$MLX_C_FIXTURE/mlx/c/stream.cpp"
SWIFT_API="$MLX_SWIFT_FIXTURE/Source/MLX/MetalCommandEncoderCache.swift"
RUNTIME_BENCHMARK="$PACKAGE_ROOT/Sources/RuntimeBenchmark/main.swift"
RUNTIME_CLEANUP="$PACKAGE_ROOT/Sources/ModelRunnerCore/MLXRuntimeCleanup.swift"

grep -Fq 'std::atomic<uint64_t> command_encoder_cache_state{0};' "$DEVICE_CPP"
grep -Fq 'static thread_local LastCommandEncoder cached;' "$DEVICE_CPP"
grep -Fq 'cached.stream_index == s.index' "$DEVICE_CPP"
grep -Fq 'cached.generation_state == cache_state' "$DEVICE_CPP"
grep -Fq 'command_encoder_cache_state.fetch_add(2' "$DEVICE_CPP"
grep -Fq 'compare_exchange_weak' "$DEVICE_CPP"
grep -Fq 'unordered_map rehash and insertion preserve pointers/references' "$DEVICE_CPP"
grep -Fq 'if ((cache_state & command_encoder_cache_enabled_bit) == 0)' "$DEVICE_CPP"
grep -Fq 'metal::invalidate_command_encoder_cache();' "$METAL_EVAL"
grep -Fq 'bool is_command_encoder_cache_enabled()' "$NO_METAL"
grep -Fq 'return false;' "$NO_METAL"
grep -Fq 'mlx::core::metal::set_command_encoder_cache_enabled(enabled);' "$C_STREAM"
grep -Fq 'public func setMetalCommandEncoderCacheEnabled(_ enabled: Bool)' "$SWIFT_API"
grep -Fq 'Copyright © 2026 Model Runner contributors' "$SWIFT_API"

grep -Fq 'MLX_SOURCE_METAL_COMMAND_ENCODER_CACHE_PATCH=' "$PACKAGE_ROOT/prepare-dependencies.sh"
grep -Fq 'mlx Metal command encoder cache' "$PACKAGE_ROOT/prepare-dependencies.sh"
grep -Fq 'mlx-c Metal command encoder cache API' "$PACKAGE_ROOT/prepare-dependencies.sh"
grep -Fq 'mlx-swift Metal command encoder cache API' "$PACKAGE_ROOT/prepare-dependencies.sh"
grep -Fq 'name: .customLong("metal-command-encoder-cache-ab")' "$RUNTIME_BENCHMARK"
grep -Fq 'label: "metal_command_encoder_cache_off"' "$RUNTIME_BENCHMARK"
grep -Fq 'label: "metal_command_encoder_cache_on"' "$RUNTIME_BENCHMARK"
grep -Fq 'useCompiledBlockTail: true, useMetalCommandEncoderCache: false' "$RUNTIME_BENCHMARK"
grep -Fq 'useCompiledBlockTail: true, useMetalCommandEncoderCache: true' "$RUNTIME_BENCHMARK"
grep -Fq '? [encoderCacheOffMode, encoderCacheOnMode]' "$RUNTIME_BENCHMARK"
grep -Fq ': [encoderCacheOnMode, encoderCacheOffMode]' "$RUNTIME_BENCHMARK"
grep -Fq 'defer { setModelRunnerMetalCommandEncoderCacheEnabled(false) }' "$RUNTIME_BENCHMARK"
grep -Fq 'quantization.bits == 4' "$RUNTIME_BENCHMARK"
grep -Fq 'setMetalCommandEncoderCacheEnabled(enabled)' "$RUNTIME_CLEANUP"

echo "MLX Metal command-encoder cache patch checks passed"
