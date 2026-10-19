#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Create and push git tag to origin for the new release version

set -e

export PHASE=${PHASE:-all}
export IS_PRERELEASE=${IS_PRERELEASE:-false}

# Skip if prepare phase determined no release needed (phase=all only)
if [ "$PHASE" = "all" -a "$NEEDS_RELEASE" != "true" ] || [ "$RELEASE_CREATED" = "false" ]; then
  printf 'No release needed, skipping tag creation\n'
  exit 0
fi

# If tag already exits, skip release
if git rev-parse "$TAG_NAME" > /dev/null 2>&1; then
  printf 'Warning: Tag %s already exists, skipping\n' "$TAG_NAME"
  printf 'release-created=false\n' >> ${GITHUB_OUTPUT}
  exit 0
fi

printf 'Finalizing release: %s\n' "$TAG_NAME"

# Create tag (before push, so it's included)
git tag -a "$TAG_NAME" -m "Release ${NEW_VERSION}"
printf 'Tag created: %s\n' "$TAG_NAME"

# Push commits and tag together
git push origin "$TAG_NAME"
printf 'Pushed tag\n'