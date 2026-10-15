#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/screenmate-clang-cache"
swift test --disable-sandbox --cache-path "${TMPDIR:-/tmp}/screenmate-swift-cache"
