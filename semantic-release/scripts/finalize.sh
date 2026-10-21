#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Create git tag, push, and create GitHub release

set -e

export GITHUB_TOKEN=${GITHUB_TOKEN}
export PHASE=${PHASE:-all}
export NEW_VERSION=${NEW_VERSION}
export VERSION_CORE=${VERSION_CORE}
export TAG_NAME=${TAG_NAME}
export IS_PRERELEASE=${IS_PRERELEASE:-false}
export CHANGELOG_CONTENT=${CHANGELOG_CONTENT}
export NEEDS_RELEASE=${NEEDS_RELEASE}
export DRAFT=${DRAFT:-false}
export TAG_PREFIX=${TAG_PREFIX:-v}

# Skip if prepare phase determined no release needed (phase=all only)
if [ "$PHASE" = "all" ] && [ "$NEEDS_RELEASE" != "true" ]; then
  printf 'No release needed, skipping finalize\n'
  printf 'release-created=false\n' >> $GITHUB_OUTPUT
  exit 0
fi

# Validate required inputs for finalize phase
if [ -z "$NEW_VERSION" ] || [ -z "$TAG_NAME" ]; then
  printf 'Error: Missing required inputs for finalize phase\n'
  printf 'NEW_VERSION=%s\n' "$NEW_VERSION"
  printf 'TAG_NAME=%s\n' "$TAG_NAME"
  exit 1
fi

printf 'Finalizing release: %s\n' "$TAG_NAME"

# If tag already exits, skip release
if git rev-parse "$TAG_NAME" > /dev/null 2>&1; then
  printf 'Warning: Tag %s already exists, skipping\n' "$TAG_NAME"
  printf 'release-created=false\n' >> ${GITHUB_OUTPUT}
  exit 0
fi

# Create tag (before push, so it's included)
git tag -a "$TAG_NAME" -m "Release ${NEW_VERSION}"
printf 'Tag created: %s\n' "$TAG_NAME"

# Push commits and tag together
git push origin HEAD --follow-tags
printf 'Pushed commits and tag\n'

# Create GitHub Release
PRERELEASE_FLAG=""
[ "$IS_PRERELEASE" = "true" ] && PRERELEASE_FLAG="--prerelease"

DRAFT_FLAG=""
[ "$DRAFT" = "true" ] && DRAFT_FLAG="--draft"

if [ "$IS_PRERELEASE" = "true" ]; then
  RELEASE_TITLE="Pre-release ${NEW_VERSION}"
else
  RELEASE_TITLE="Release ${NEW_VERSION}"
fi

# Create release notes file
NOTES_FILE=$(mktemp)
printf '%s' "$CHANGELOG_CONTENT" > "$NOTES_FILE"

# Create release with proper error handling
if RELEASE_URL=$(gh release create "$TAG_NAME" \
                --title "$RELEASE_TITLE" \
                --notes-file "$NOTES_FILE" \
                $PRERELEASE_FLAG \
                $DRAFT_FLAG); then
  printf 'release-created=true\n' >> $GITHUB_OUTPUT
  printf 'release-url=%s\n' "$RELEASE_URL" >> $GITHUB_OUTPUT
  printf 'GitHub Release created: %s\n' "$RELEASE_URL"
  printf 'Release finalized: %s\n' "$TAG_NAME"
else
  printf 'Warning: gh release create failed\n' >&2
  printf 'release-created=false\n' >> $GITHUB_OUTPUT
fi

rm -f "$NOTES_FILE"


