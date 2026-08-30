#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DARWIN_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-persistent-compiled-closures-darwin.patch"
LINUX_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-persistent-compiled-closures-linux.patch"
PREPARE_SCRIPT="$PACKAGE_ROOT/prepare-dependencies.sh"
MLX_SWIFT_CHECKOUT="$PACKAGE_ROOT/.build/checkouts/mlx-swift"
DARWIN_REVISION="72f3c3ad8aeee39bfc94f8fbeb446cac89e3a798"
LINUX_REVISION="2d2724006b62855c6c2a71df633baf4ee4ad8a0f"

require_added_count() {
  local expected="$1"
  local pattern="$2"
  local patch_file="$3"
  local actual
  actual="$(grep -F "$pattern" "$patch_file" | grep -c '^+' || true)"
  if [[ "$actual" -ne "$expected" ]]; then
    echo "Expected $expected added occurrence(s) of '$pattern' in $patch_file; found $actual" >&2
    exit 1
  fi
}

check_patch_round_trip() {
  local label="$1"
  local revision="$2"
  local patch_file="$3"
  local original="$TEST_ROOT/$label-original"
  local patched="$TEST_ROOT/$label-patched"

  if ! git -C "$MLX_SWIFT_CHECKOUT" cat-file -e "$revision^{commit}" >/dev/null 2>&1; then
    echo "Missing pinned $label revision $revision in $MLX_SWIFT_CHECKOUT" >&2
    exit 1
  fi

  mkdir -p "$original" "$patched"
  git -C "$MLX_SWIFT_CHECKOUT" archive "$revision" | tar -xf - -C "$original"
  git -C "$MLX_SWIFT_CHECKOUT" archive "$revision" | tar -xf - -C "$patched"

  git -C "$patched" apply --check --whitespace=error-all "$patch_file"
  git -C "$patched" apply "$patch_file"
  git -C "$patched" apply --reverse --check "$patch_file"
  git -C "$patched" apply --reverse "$patch_file"

  if ! diff -qr "$original" "$patched" >/dev/null; then
    echo "$label patch did not reverse to its immutable pinned baseline" >&2
    exit 1
  fi

  git -C "$patched" apply "$patch_file"
  grep -Fq 'private final class OwnedMLXClosure: @unchecked Sendable' \
    "$patched/Source/MLX/Transforms+Compile.swift"
  grep -Fq 'let source = new_mlx_closure { tracers in body(tracers) }' \
    "$patched/Source/MLX/Transforms+Compile.swift"
  grep -Fq 'let compileStatus = mlx_compile(&candidate, source, shapeless)' \
    "$patched/Source/MLX/Transforms+Compile.swift"
  grep -Fq 'if inputs.isEmpty && outputs.isEmpty' \
    "$patched/Source/MLX/Transforms+Compile.swift"
}

[[ -s "$DARWIN_PATCH" ]]
[[ -s "$LINUX_PATCH" ]]
[[ "$(grep -c '^diff --git ' "$DARWIN_PATCH")" -eq 1 ]]
[[ "$(grep -c '^diff --git ' "$LINUX_PATCH")" -eq 1 ]]
grep -Fqx \
  'diff --git a/Source/MLX/Transforms+Compile.swift b/Source/MLX/Transforms+Compile.swift' \
  "$DARWIN_PATCH"
grep -Fqx \
  'diff --git a/Source/MLX/Transforms+Compile.swift b/Source/MLX/Transforms+Compile.swift' \
  "$LINUX_PATCH"

for patch_file in "$DARWIN_PATCH" "$LINUX_PATCH"; do
  require_added_count 1 'public func setPersistentCompiledClosuresEnabled(' "$patch_file"
  require_added_count 1 'public func persistentCompiledClosuresEnabled() -> Bool' "$patch_file"
  require_added_count 1 'private final class OwnedMLXClosure: @unchecked Sendable' "$patch_file"
  require_added_count 1 '_ = mlx_closure_free(handle)' "$patch_file"
  require_added_count 1 'var hasPersistentCompiledClosureForTesting: Bool' "$patch_file"
  require_added_count 1 'var persistentCompiledClosureIdentityForTesting: UInt?' "$patch_file"
  require_added_count 1 'let body = f' "$patch_file"
  require_added_count 1 'let source = new_mlx_closure { tracers in body(tracers) }' "$patch_file"
  require_added_count 1 'defer { mlx_closure_free(source) }' "$patch_file"
  require_added_count 1 'let compileStatus = mlx_compile(&candidate, source, shapeless)' "$patch_file"
  require_added_count 1 'persistentCompiledClosure = owned' "$patch_file"
  require_added_count 1 'guard let compiled = persistentCompiledClosureHandle() else { return [] }' \
    "$patch_file"
  require_added_count 1 'if inputs.isEmpty && outputs.isEmpty' "$patch_file"
  require_added_count 0 'new_mlx_closure(inner' "$patch_file"
done

# Darwin's existing outer eval lock synchronizes the flag and permits a direct,
# lock-free read in the compiled hot path without increasing the macOS 14
# deployment target of the dependency package.
require_added_count 1 \
  'nonisolated(unsafe) private var persistentCompiledClosuresFlag = false' \
  "$DARWIN_PATCH"
require_added_count 2 'withEvalLock {' "$DARWIN_PATCH"
require_added_count 1 \
  'private func persistentCompiledClosuresEnabledAssumingEvalLock() -> Bool' \
  "$DARWIN_PATCH"
require_added_count 0 'import Synchronization' "$DARWIN_PATCH"

# The older Linux revision does not hold evalLock around the flag check, so use
# the platform-available atomic and take evalLock only for handle construction
# and application.
require_added_count 1 'import Synchronization' "$LINUX_PATCH"
require_added_count 1 'private let persistentCompiledClosuresFlag = Atomic<Bool>(false)' \
  "$LINUX_PATCH"
require_added_count 1 'persistentCompiledClosuresFlag.load(ordering: .relaxed)' "$LINUX_PATCH"
require_added_count 1 'evalLock.lock()' "$LINUX_PATCH"
require_added_count 1 'defer { evalLock.unlock() }' "$LINUX_PATCH"

grep -Fq \
  'MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_DARWIN_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-persistent-compiled-closures-darwin.patch"' \
  "$PREPARE_SCRIPT"
grep -Fq \
  'MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_LINUX_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-persistent-compiled-closures-linux.patch"' \
  "$PREPARE_SCRIPT"
grep -Fq \
  'MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_PATCH="$MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_DARWIN_PATCH"' \
  "$PREPARE_SCRIPT"
grep -Fq \
  'MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_PATCH="$MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_LINUX_PATCH"' \
  "$PREPARE_SCRIPT"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/model-runner-persistent-closures.XXXXXX")"
cleanup() {
  local status=$?
  trap - EXIT
  rm -rf "$TEST_ROOT"
  exit "$status"
}
trap cleanup EXIT

PREPARE_FLAT="$TEST_ROOT/prepare-dependencies.flat"
awk '
  {
    line = $0
    continued = sub(/[[:space:]]*\\[[:space:]]*$/, "", line)
    if (buffer == "") {
      buffer = line
    } else {
      buffer = buffer " " line
    }
    if (!continued) {
      gsub(/[[:space:]]+/, " ", buffer)
      print buffer
      buffer = ""
    }
  }
  END {
    if (buffer != "") print buffer
  }
' "$PREPARE_SCRIPT" > "$PREPARE_FLAT"

VERIFY_CALL='verify_checkout_revision "mlx-swift" "$MLX_SWIFT_CHECKOUT" "$MLX_SWIFT_EXPECTED_REVISION"'
PATCH_CALL='apply_dependency_patch "mlx-swift persistent compiled closures" "$MLX_SWIFT_CHECKOUT" "$MLX_SWIFT_PERSISTENT_COMPILED_CLOSURES_PATCH"'
[[ "$(grep -Fxc "$VERIFY_CALL" "$PREPARE_FLAT" || true)" -eq 1 ]]
[[ "$(grep -Fxc "$PATCH_CALL" "$PREPARE_FLAT" || true)" -eq 1 ]]
VERIFY_LINE="$(grep -Fn "$VERIFY_CALL" "$PREPARE_FLAT" | cut -d: -f1)"
PATCH_LINE="$(grep -Fn "$PATCH_CALL" "$PREPARE_FLAT" | cut -d: -f1)"
if [[ "$VERIFY_LINE" -ge "$PATCH_LINE" ]]; then
  echo "Pinned mlx-swift revision must be verified before the closure patch is applied" >&2
  exit 1
fi

check_patch_round_trip "mlx-swift-darwin" "$DARWIN_REVISION" "$DARWIN_PATCH"
check_patch_round_trip "mlx-swift-linux" "$LINUX_REVISION" "$LINUX_PATCH"

echo "MLX persistent compiled-closure patch persistence checks passed"
