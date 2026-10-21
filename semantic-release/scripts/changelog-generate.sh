#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Generate CHANGELOG entry for new version

set -e

export NEW_VERSION=${NEW_VERSION}
export FEATURES=${FEATURES}
export FIXES=${FIXES}
export BREAKING=${BREAKING}
export OTHERS=${OTHERS}
export CHANGELOG_PATH=${CHANGELOG_PATH:-CHANGELOG.md}
export TAG_PREFIX=${TAG_PREFIX:-v}
export IS_PRERELEASE=${IS_PRERELEASE:-false}
export GITHUB_SERVER_URL=${GITHUB_SERVER_URL}
export GITHUB_REPOSITORY=${GITHUB_REPOSITORY}

DATE=$(date +%Y-%m-%d)

# Add label for pre-release
if [ "$IS_PRERELEASE" = "true" ]; then
  VERSION_LABEL="${NEW_VERSION} (Pre-release)"
else
  VERSION_LABEL="${NEW_VERSION}"
fi

# Generate new CHANGELOG entry with absolute URL
RELEASE_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/releases/tag/${TAG_PREFIX}${NEW_VERSION}"
CHANGELOG_ENTRY="## [${VERSION_LABEL}](${RELEASE_URL}) - ${DATE}"

if [ -n "$BREAKING" ]; then
  CHANGELOG_ENTRY="${CHANGELOG_ENTRY}

### ⚠ BREAKING CHANGES

${BREAKING}"
fi

if [ -n "$FEATURES" ]; then
  CHANGELOG_ENTRY="${CHANGELOG_ENTRY}

### ✨ Features

${FEATURES}"
fi

if [ -n "$FIXES" ]; then
  CHANGELOG_ENTRY="${CHANGELOG_ENTRY}

### 🐛 Bug Fixes

${FIXES}"
fi

if [ -n "$OTHERS" ]; then
  CHANGELOG_ENTRY="${CHANGELOG_ENTRY}

### 🔧 Other Changes

${OTHERS}"
fi

# Update CHANGELOG file
if [ -f "$CHANGELOG_PATH" ]; then
  # Prepend to existing CHANGELOG
  TEMP_FILE=$(mktemp)
  
  # Write header to temp file
  printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n%s\n' "$CHANGELOG_ENTRY" > "$TEMP_FILE"
  
  # Find first version entry and append from there
  FIRST_ENTRY_LINE=$(grep -n "^## \[" "$CHANGELOG_PATH" | head -1 | cut -d: -f1)
  if [ -n "$FIRST_ENTRY_LINE" ]; then
    tail -n +"$FIRST_ENTRY_LINE" "$CHANGELOG_PATH" >> "$TEMP_FILE" 2>/dev/null || true
  fi
  
  mv "$TEMP_FILE" "$CHANGELOG_PATH"
else
  # Create new file
  printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n%s\n' "$CHANGELOG_ENTRY" > "$CHANGELOG_PATH"
fi

# Save for release notes
{
  printf 'content<<EOF\n%s\nEOF' "$CHANGELOG_ENTRY"
} >> $GITHUB_OUTPUT

printf 'CHANGELOG generated at %s\n' "$CHANGELOG_PATH"
