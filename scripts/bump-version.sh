#!/usr/bin/env bash
# Stamps a new version into Info.plist, commits, and creates an annotated git tag.
# Usage: scripts/bump-version.sh <version>   e.g.  scripts/bump-version.sh 1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST="${PROJECT_DIR}/Sources/MarkdownEditor/Resources/Info.plist"

usage() {
    echo "Usage: $(basename "$0") <version>"
    echo "  Semver format required — e.g. 1.2.3 or 1.2.3-beta.1"
    exit 1
}

VERSION="${1:-}"
[[ -z "$VERSION" ]] && usage

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?$ ]]; then
    echo "Error: '${VERSION}' is not a valid semver string."
    usage
fi

TAG="v${VERSION}"

# Require a clean working tree
if ! git -C "$PROJECT_DIR" diff --quiet || ! git -C "$PROJECT_DIR" diff --cached --quiet; then
    echo "Error: Working tree has uncommitted changes. Commit or stash them first."
    exit 1
fi

# Reject duplicate tags
if git -C "$PROJECT_DIR" tag --list | grep -qx "$TAG"; then
    echo "Error: Tag '${TAG}' already exists."
    exit 1
fi

echo "==> Bumping version to ${VERSION}..."

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString ${VERSION}" \
    -c "Set :CFBundleVersion ${VERSION}" \
    "$PLIST"

echo "    Updated Info.plist"

git -C "$PROJECT_DIR" add "$PLIST"
git -C "$PROJECT_DIR" commit -m "chore: bump version to ${VERSION}"
git -C "$PROJECT_DIR" tag -a "$TAG" -m "Release ${TAG}"

echo ""
echo "==> Done. Created commit and tag ${TAG}."
echo ""
echo "    Push to trigger the release workflow:"
echo "    git push origin main && git push origin ${TAG}"
echo ""
