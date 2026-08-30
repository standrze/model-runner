#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_FILE="$ROOT/Patches/mlx-swift-lm-token-loop-decoder-in-place.patch"
PREPARE="$ROOT/prepare-dependencies.sh"
CHECKOUT="$ROOT/.build/checkouts/mlx-swift-lm"
EXPECTED_REVISION="14414441fa44f45eee35a61e9fa0bab577cf9734"
SOURCE_RELATIVE="Libraries/MLXLMCommon/Evaluate.swift"

[[ -s "$PATCH_FILE" ]]
[[ "$(grep -c '^diff --git ' "$PATCH_FILE" || true)" -eq 1 ]]
grep -Fqx \
  "diff --git a/$SOURCE_RELATIVE b/$SOURCE_RELATIVE" \
  "$PATCH_FILE"

# The production patch is deliberately limited to removing two existential
# copy/write-back pairs and making the event router independent of self.
[[ "$(grep -Ec '^\+[^+]' "$PATCH_FILE" || true)" -eq 3 ]]
[[ "$(grep -Ec '^-[^-]' "$PATCH_FILE" || true)" -eq 7 ]]
[[ "$(grep -Fc -- '-        var decoder = self.decoder' "$PATCH_FILE" || true)" -eq 2 ]]
[[ "$(grep -Fc -- '-        self.decoder = decoder' "$PATCH_FILE" || true)" -eq 2 ]]
[[ "$(grep -Fc -- '-            disposition = process(event, emit: emit)' "$PATCH_FILE" || true)" -eq 2 ]]
[[ "$(grep -Fc -- '+            disposition = Self.process(event, emit: emit)' "$PATCH_FILE" || true)" -eq 2 ]]
grep -Fqx -- '-    private mutating func process(' "$PATCH_FILE"
grep -Fqx -- '+    private static func process(' "$PATCH_FILE"

if ! git -C "$CHECKOUT" cat-file -e "${EXPECTED_REVISION}^{commit}" >/dev/null 2>&1; then
  echo "Missing pinned mlx-swift-lm revision $EXPECTED_REVISION" >&2
  exit 1
fi

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/model-runner-decoder-in-place-patch.XXXXXX")"
cleanup() {
  local status=$?
  trap - EXIT
  rm -rf "$TEST_ROOT"
  exit "$status"
}
trap cleanup EXIT

# Flatten continued shell statements before checking that dependency setup
# declares and applies the patch exactly once and only after revision checks.
PREPARE_FLAT="$TEST_ROOT/prepare-dependencies.flat"
awk '
  {
    line = $0
    continued = sub(/[[:space:]]*\\[[:space:]]*$/, "", line)
    buffer = buffer == "" ? line : buffer " " line
    if (!continued) {
      gsub(/[[:space:]]+/, " ", buffer)
      print buffer
      buffer = ""
    }
  }
  END { if (buffer != "") print buffer }
' "$PREPARE" > "$PREPARE_FLAT"

PATCH_DECL='MLX_SWIFT_LM_TOKEN_LOOP_DECODER_IN_PLACE_PATCH="$PACKAGE_ROOT/Patches/mlx-swift-lm-token-loop-decoder-in-place.patch"'
REVISION_DECL='MLX_SWIFT_LM_EXPECTED_REVISION="14414441fa44f45eee35a61e9fa0bab577cf9734"'
VERIFY_CALL='verify_checkout_revision "mlx-swift-lm" "$MLX_SWIFT_LM_CHECKOUT" "$MLX_SWIFT_LM_EXPECTED_REVISION"'
PATCH_CALL='apply_dependency_patch "mlx-swift-lm token-loop decoder in-place fast path" "$MLX_SWIFT_LM_CHECKOUT" "$MLX_SWIFT_LM_TOKEN_LOOP_DECODER_IN_PLACE_PATCH"'

for statement in \
  "$PATCH_DECL" "$REVISION_DECL" "$VERIFY_CALL" "$PATCH_CALL"; do
  if [[ "$(grep -Fxc "$statement" "$PREPARE_FLAT" || true)" -ne 1 ]]; then
    echo "Expected exactly one prepare-dependencies statement: $statement" >&2
    exit 1
  fi
done

PATCH_DECL_LINE="$(grep -Fn "$PATCH_DECL" "$PREPARE_FLAT" | cut -d: -f1)"
REVISION_DECL_LINE="$(grep -Fn "$REVISION_DECL" "$PREPARE_FLAT" | cut -d: -f1)"
VERIFY_LINE="$(grep -Fn "$VERIFY_CALL" "$PREPARE_FLAT" | cut -d: -f1)"
PATCH_CALL_LINE="$(grep -Fn "$PATCH_CALL" "$PREPARE_FLAT" | cut -d: -f1)"

if [[ "$PATCH_DECL_LINE" -ge "$PATCH_CALL_LINE" ]] \
  || [[ "$REVISION_DECL_LINE" -ge "$VERIFY_LINE" ]] \
  || [[ "$VERIFY_LINE" -ge "$PATCH_CALL_LINE" ]]; then
  echo "Pinned revision must precede the decoder patch" >&2
  exit 1
fi

SOURCE_FILE="$TEST_ROOT/$SOURCE_RELATIVE"
BASELINE_FILE="$TEST_ROOT/Evaluate.baseline.swift"
mkdir -p "$(dirname "$SOURCE_FILE")"
git -C "$CHECKOUT" show "$EXPECTED_REVISION:$SOURCE_RELATIVE" > "$SOURCE_FILE"
cp "$SOURCE_FILE" "$BASELINE_FILE"

# Prove that the decoder patch applies independently to the pinned upstream.
git -C "$TEST_ROOT" apply --check --whitespace=error-all "$PATCH_FILE"
git -C "$TEST_ROOT" apply "$PATCH_FILE"

[[ "$(grep -Fc 'var decoder = self.decoder' "$SOURCE_FILE" || true)" -eq 0 ]]
[[ "$(grep -Fc 'self.decoder = decoder' "$SOURCE_FILE" || true)" -eq 0 ]]
[[ "$(grep -Fc 'disposition = Self.process(event, emit: emit)' "$SOURCE_FILE" || true)" -eq 2 ]]
[[ "$(grep -Fc 'private static func process(' "$SOURCE_FILE" || true)" -eq 1 ]]
[[ "$(grep -Fc 'private mutating func process(' "$SOURCE_FILE" || true)" -eq 1 ]]
[[ "$(grep -Fc 'let completed = decoder.push(token)' "$SOURCE_FILE" || true)" -eq 1 ]]
[[ "$(grep -Fc '_ = decoder.finish' "$SOURCE_FILE" || true)" -eq 1 ]]

git -C "$TEST_ROOT" apply --reverse --check "$PATCH_FILE"
git -C "$TEST_ROOT" apply --reverse "$PATCH_FILE"
cmp "$SOURCE_FILE" "$BASELINE_FILE"

echo "mlx-swift-lm token-loop decoder in-place patch checks passed"
