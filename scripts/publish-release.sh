#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$source_dir"
repo="tigerlaibao/ScreenMate"
version="$(tr -d '\n' < VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid VERSION\n' >&2; exit 1; }
tag="v$version"
archive="ScreenMate-$version-macOS-universal.zip"
notes="docs/releases/$tag.md"
gh auth status --hostname github.com
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  printf 'Release %s already exists; refusing to overwrite published assets.\n' "$tag" >&2
  exit 1
fi
test -f "$notes"
bash scripts/test.sh
bash scripts/package-release.sh
(cd dist && shasum -a 256 -c "$archive.sha256")

# A temporary checkout also supports source folders that do not have a local .git directory.
checkout="$(mktemp -d "${TMPDIR:-/tmp}/screenmate-publish.XXXXXX")"
trap 'rm -rf "$checkout"' EXIT
git clone --branch main "https://github.com/$repo.git" "$checkout"
login="$(gh api user --jq .login)"
git -C "$checkout" config user.name "$login"
git -C "$checkout" config user.email "$login@users.noreply.github.com"
for directory in Sources Tests Packaging assets docs scripts .github; do
  mkdir -p "$checkout/$directory"
  rsync -a --exclude='.DS_Store' --exclude='__pycache__' "$source_dir/$directory/" "$checkout/$directory/"
done
for file in .gitignore AGENTS.md CHANGELOG.md CONTRIBUTING.md LICENSE Package.swift README.md SECURITY.md VERSION; do
  cp "$source_dir/$file" "$checkout/$file"
done
git -C "$checkout" add Sources Tests Packaging assets docs scripts .github .gitignore AGENTS.md CHANGELOG.md CONTRIBUTING.md LICENSE Package.swift README.md SECURITY.md VERSION
git -C "$checkout" diff --cached --check
if ! git -C "$checkout" diff --cached --quiet; then
  git -C "$checkout" commit -m "Release ScreenMate $version"
fi
git -C "$checkout" -c 'credential.helper=!gh auth git-credential' push origin HEAD:main
commit="$(git -C "$checkout" rev-parse HEAD)"
gh release create "$tag" "$source_dir/dist/$archive" "$source_dir/dist/$archive.sha256" \
  --repo "$repo" --target "$commit" --title "ScreenMate $version" --notes-file "$source_dir/$notes"
printf '\nPublished: https://github.com/%s/releases/tag/%s\n' "$repo" "$tag"
