#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Commit and push updated CHANGELOG to origin

set -e

export IS_PRERELEASE=${IS_PRERELEASE:-false}
export CHANGELOG_PATH=${CHANGELOG_PATH:-CHANGELOG.md}

# Skip if prepare phase determined no release needed (phase=all only)
if [ "$PHASE" = "all" -a "$NEEDS_RELEASE" != "true" ]; then
  printf 'No release needed, skipping finalize\n'
  printf 'release-created=false\n' >> $GITHUB_OUTPUT
  exit 0
fi

# Validate required inputs for finalize phase
if [ -z "$NEW_VERSION" -a -z "$TAG_NAME" ]; then
  printf 'Error: Missing required inputs for finalize phase\n'
  printf 'NEW_VERSION=%s\n' "$NEW_VERSION"
  printf 'TAG_NAME=%s\n' "$TAG_NAME"
  exit 1
fi

git add "$CHANGELOG_PATH"
        
if git diff --cached --quiet; then
  printf 'No CHANGELOG changes to commit\n'
else
  if [ "$IS_PRERELEASE" = "true" ]; then
    git commit -m "chore: release ${NEW_VERSION} (pre-release)"
  else
    git commit -m "chore: release ${NEW_VERSION}"
  fi
  git push origin HEAD
  printf 'Committed and pushed CHANGELOG to origin\n'
fi