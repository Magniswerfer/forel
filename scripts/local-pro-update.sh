#!/usr/bin/env bash
# Rebuilds Forel Pro for a new upstream release, used by the app's updater on
# the local-pro branch instead of downloading the official (Free) DMG.
#
# Usage: scripts/local-pro-update.sh <tag> <dmg-out>
# Merges <tag> from upstream into local-pro, runs the tests, packages the app
# with that version, and copies the DMG to <dmg-out>. On a merge conflict or a
# test failure, local-pro is put back exactly as it was.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

tag="$1"
dmg_out="$2"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
arch="$(uname -m)"
cd "$repo_root"

fail() {
  echo
  echo "UPDATE FAILED: $*"
  echo "Your installed Forel was not changed."
  exit 1
}

echo "Updating Forel Pro to $tag from $repo_root ($(date))"

branch="$(git branch --show-current)"
[[ "$branch" == "local-pro" ]] ||
  fail "The forel checkout is on '$branch', not local-pro. Switch to local-pro and try again."
[[ -z "$(git status --porcelain)" ]] ||
  fail "The forel checkout has uncommitted changes. Commit or stash them and try again."

git fetch upstream --tags --quiet ||
  fail "Could not fetch from upstream. Check your internet connection and try again."

before="$(git rev-parse HEAD)"
if ! git merge --no-edit "$tag"; then
  git merge --abort || true
  fail "$tag conflicts with the Pro change on local-pro. Merge it by hand: git merge $tag"
fi

if ! swift test; then
  git reset --hard --quiet "$before"
  fail "Tests failed after merging $tag, so local-pro was rolled back. See the test output above."
fi

./build.sh package ad-hoc "$arch" "$tag" ||
  { git reset --hard --quiet "$before"; fail "Building $tag failed, so local-pro was rolled back. See the build output above."; }

cp "dist/release/Forel-$tag-darwin-$arch.dmg" "$dmg_out"

git push --quiet origin local-pro ||
  echo "Warning: could not push local-pro to origin; the update is still installed."

echo "Built $tag; installing."
