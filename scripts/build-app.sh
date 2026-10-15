#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build native by default. A universal release runs on Apple Silicon and Intel.
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--universal" ) ]]; then
  printf 'Usage: bash scripts/build-app.sh [--universal]\n' >&2
  exit 2
fi
version="$(tr -d '\n' < VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'VERSION must contain a semantic version such as 0.1.0\n' >&2
  exit 1
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/screenmate-clang-cache"
cache_path="${TMPDIR:-/tmp}/screenmate-swift-cache"
app_dir="$PWD/dist/ScreenMate.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

build_arch() {
  local arch="$1"
  swift build -c release --scratch-path ".build/release-$arch" --triple "$arch-apple-macosx13.0" -debug-info-format none --disable-sandbox --cache-path "$cache_path"
}
bin_path() {
  swift build -c release --scratch-path ".build/release-$1" --triple "$1-apple-macosx13.0" --disable-sandbox --show-bin-path --cache-path "$cache_path"
}

if [[ "${1:-}" == "--universal" ]]; then
  build_arch arm64
  arm_bin="$(bin_path arm64)"
  build_arch x86_64
  intel_bin="$(bin_path x86_64)"
  lipo -create "$arm_bin/ScreenMate" "$intel_bin/ScreenMate" -output "$app_dir/Contents/MacOS/ScreenMate"
  resources_bin="$arm_bin"
else
  build_arch "$(uname -m)"
  resources_bin="$(bin_path "$(uname -m)")"
  cp "$resources_bin/ScreenMate" "$app_dir/Contents/MacOS/ScreenMate"
fi

ditto "$resources_bin/ScreenMate_Localization.bundle" "$app_dir/Contents/Resources/ScreenMate_Localization.bundle"
bash scripts/build-icon.sh
cp assets/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
cp Packaging/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app_dir/Contents/Info.plist"
# Ad-hoc signing requires no paid Apple developer account. This is not notarization.
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
"$app_dir/Contents/MacOS/ScreenMate" --check-resources
printf '\nBuilt: %s\n' "$app_dir"
