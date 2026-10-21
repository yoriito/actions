#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Create a GitHub Release with CHANGELOG content and metadata

set -e

export PHASE=${PHASE:-all}
export IS_PRERELEASE=${IS_PRERELEASE:-false}
export DRAFT=${DRAFT:-false}

# Skip if prepare phase determined no release needed (phase=all only)
if [ "$PHASE" = "all" -a "$NEEDS_RELEASE" != "true" ] || [ "$RELEASE_CREATED" = "false" ]; then
  printf 'No release needed, skipping release creation\n'
  exit 0
fi

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
