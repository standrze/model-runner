#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INCREMENTAL_PATCH="$ROOT/Patches/swift-transformers-incremental-bytelevel-decoder.patch"
CACHE_PATCH="$ROOT/Patches/swift-transformers-stable-string-cache.patch"
PREPARE="$ROOT/prepare-dependencies.sh"
CHECKOUT="$ROOT/.build/checkouts/swift-transformers"
EXPECTED_REVISION="2fa33e1f5e7131a7fc64c28e6d161dcec0d24820"

[[ -s "$INCREMENTAL_PATCH" ]]
[[ -s "$CACHE_PATCH" ]]
[[ "$(grep -c '^diff --git ' "$CACHE_PATCH" || true)" -eq 2 ]]
grep -Fq 'maximumStableStringCacheTokenCount = 262_144' "$CACHE_PATCH"
grep -Fq 'maximumCachedStableStringUTF8Count = 15' "$CACHE_PATCH"
grep -Fq 'let stableShortChunks: [String?]?' "$CACHE_PATCH"
grep -Fq 'pendingBytes.isEmpty, withheldText.isEmpty' "$CACHE_PATCH"
grep -Fq 'pendingUTF8BypassesStableChunkCache' "$CACHE_PATCH"
grep -Fq 'stableStringCacheVocabularyCap' "$CACHE_PATCH"

if ! git -C "$CHECKOUT" cat-file -e "${EXPECTED_REVISION}^{commit}" >/dev/null 2>&1; then
  echo "Missing pinned swift-transformers revision $EXPECTED_REVISION" >&2
  exit 1
fi

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/model-runner-stable-string-cache.XXXXXX")"
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
    buffer = buffer == "" ? line : buffer " " line
    if (!continued) {
      gsub(/[[:space:]]+/, " ", buffer)
      print buffer
      buffer = ""
    }
  }
  END { if (buffer != "") print buffer }
' "$PREPARE" > "$PREPARE_FLAT"

REVISION_DECL='SWIFT_TRANSFORMERS_EXPECTED_REVISION="2fa33e1f5e7131a7fc64c28e6d161dcec0d24820"'
VERIFY_CALL='verify_checkout_revision "swift-transformers" "$SWIFT_TRANSFORMERS_CHECKOUT" "$SWIFT_TRANSFORMERS_EXPECTED_REVISION"'
INCREMENTAL_DECL='SWIFT_TRANSFORMERS_INCREMENTAL_BYTELEVEL_PATCH="$PACKAGE_ROOT/Patches/swift-transformers-incremental-bytelevel-decoder.patch"'
CACHE_DECL='SWIFT_TRANSFORMERS_STABLE_STRING_CACHE_PATCH="$PACKAGE_ROOT/Patches/swift-transformers-stable-string-cache.patch"'
INCREMENTAL_APPLY='apply_dependency_patch "swift-transformers incremental ByteLevel decoder" "$SWIFT_TRANSFORMERS_CHECKOUT" "$SWIFT_TRANSFORMERS_INCREMENTAL_BYTELEVEL_PATCH"'
CACHE_APPLY='apply_dependency_patch "swift-transformers stable short-string cache" "$SWIFT_TRANSFORMERS_CHECKOUT" "$SWIFT_TRANSFORMERS_STABLE_STRING_CACHE_PATCH"'
MLXLM_APPLY='apply_dependency_patch "mlx-swift-lm incremental ByteLevel streaming" "$MLX_SWIFT_LM_CHECKOUT" "$MLX_SWIFT_LM_INCREMENTAL_BYTELEVEL_STREAMING_PATCH"'

for statement in \
  "$REVISION_DECL" "$VERIFY_CALL" "$INCREMENTAL_DECL" "$CACHE_DECL" \
  "$INCREMENTAL_APPLY" "$CACHE_APPLY" "$MLXLM_APPLY"; do
  if [[ "$(grep -Fxc "$statement" "$PREPARE_FLAT" || true)" -ne 1 ]]; then
    echo "Expected exactly one prepare-dependencies statement: $statement" >&2
    exit 1
  fi
done

line_of() {
  grep -Fn "$1" "$PREPARE_FLAT" | cut -d: -f1
}

if [[ "$(line_of "$REVISION_DECL")" -ge "$(line_of "$VERIFY_CALL")" ]] \
  || [[ "$(line_of "$VERIFY_CALL")" -ge "$(line_of "$INCREMENTAL_APPLY")" ]] \
  || [[ "$(line_of "$INCREMENTAL_DECL")" -ge "$(line_of "$INCREMENTAL_APPLY")" ]] \
  || [[ "$(line_of "$CACHE_DECL")" -ge "$(line_of "$CACHE_APPLY")" ]] \
  || [[ "$(line_of "$INCREMENTAL_APPLY")" -ge "$(line_of "$CACHE_APPLY")" ]] \
  || [[ "$(line_of "$CACHE_APPLY")" -ge "$(line_of "$MLXLM_APPLY")" ]]; then
  echo "Stable-string cache dependency ordering is invalid" >&2
  exit 1
fi

SOURCE_ROOT="$TEST_ROOT/swift-transformers"
INCREMENTAL_BASELINE="$TEST_ROOT/incremental-baseline"
PINNED_BASELINE="$TEST_ROOT/pinned-baseline"
mkdir -p "$SOURCE_ROOT/Sources/Tokenizers" "$PINNED_BASELINE/Sources/Tokenizers"

for relative in Sources/Tokenizers/Decoder.swift Sources/Tokenizers/Tokenizer.swift; do
  git -C "$CHECKOUT" show "$EXPECTED_REVISION:$relative" > "$SOURCE_ROOT/$relative"
  cp "$SOURCE_ROOT/$relative" "$PINNED_BASELINE/$relative"
done

git -C "$SOURCE_ROOT" apply --check --whitespace=error-all "$INCREMENTAL_PATCH"
git -C "$SOURCE_ROOT" apply "$INCREMENTAL_PATCH"
mkdir -p "$INCREMENTAL_BASELINE/Sources/Tokenizers" \
  "$INCREMENTAL_BASELINE/Tests/TokenizersTests"
cp "$SOURCE_ROOT/Sources/Tokenizers/Decoder.swift" \
  "$INCREMENTAL_BASELINE/Sources/Tokenizers/Decoder.swift"
cp "$SOURCE_ROOT/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift" \
  "$INCREMENTAL_BASELINE/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift"

git -C "$SOURCE_ROOT" apply --check --whitespace=error-all "$CACHE_PATCH"
git -C "$SOURCE_ROOT" apply "$CACHE_PATCH"
grep -Fq 'let stableShortChunks: [String?]?' \
  "$SOURCE_ROOT/Sources/Tokenizers/Decoder.swift"
grep -Fq 'func pendingUTF8BypassesStableChunkCache()' \
  "$SOURCE_ROOT/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift"

git -C "$SOURCE_ROOT" apply --reverse --check "$CACHE_PATCH"
git -C "$SOURCE_ROOT" apply --reverse "$CACHE_PATCH"
cmp "$SOURCE_ROOT/Sources/Tokenizers/Decoder.swift" \
  "$INCREMENTAL_BASELINE/Sources/Tokenizers/Decoder.swift"
cmp "$SOURCE_ROOT/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift" \
  "$INCREMENTAL_BASELINE/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift"

git -C "$SOURCE_ROOT" apply --reverse --check "$INCREMENTAL_PATCH"
git -C "$SOURCE_ROOT" apply --reverse "$INCREMENTAL_PATCH"
cmp "$SOURCE_ROOT/Sources/Tokenizers/Decoder.swift" \
  "$PINNED_BASELINE/Sources/Tokenizers/Decoder.swift"
cmp "$SOURCE_ROOT/Sources/Tokenizers/Tokenizer.swift" \
  "$PINNED_BASELINE/Sources/Tokenizers/Tokenizer.swift"
[[ ! -e "$SOURCE_ROOT/Tests/TokenizersTests/IncrementalByteLevelDecoderTests.swift" ]]

echo "stable short-string cache patch checks passed"
