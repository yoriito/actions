#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
#
# Analyze commits and determine next version

set -e

export GITHUB_TOKEN=${GITHUB_TOKEN}
export DEFAULT_BRANCH=${DEFAULT_BRANCH:-main}
export TAG_PREFIX=${TAG_PREFIX:-v}
export INITIAL_DEVELOPMENT=${INITIAL_DEVELOPMENT:-false}
export PRERELEASE_MODE=${PRERELEASE_MODE:-false}
export PRERELEASE_SUFFIX=${PRERELEASE_SUFFIX:-alpha}

# Get the latest semver tag (including prerelease tags)
LATEST_TAG=$(git tag --merged HEAD --sort=-version:refname \
  | grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z][a-zA-Z0-9]*(\.[0-9]+)?)?$" \
  | head -1 || echo "")

printf 'Latest tag: %s\n' "$LATEST_TAG"

FIRST_RELEASE=false

if [ -z "$LATEST_TAG" ]; then
  printf 'This is the first release\n'
  CURRENT_MAJOR=0
  CURRENT_MINOR=1
  CURRENT_PATCH=0
  CURRENT_PRERELEASE=""
  CURRENT_PRERELEASE_NUM=0
  COMMITS_SINCE=""
  FIRST_RELEASE=true
else
  # Parse version from tag
  VERSION_STRING="${LATEST_TAG#$TAG_PREFIX}"
  
  # Separate prerelease part
  # Supported formats: 1.2.3, 1.2.3-alpha, 1.2.3-alpha.1
  if [[ "$VERSION_STRING" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([a-zA-Z]+)(\.([0-9]+))?)?$ ]]; then
    CURRENT_MAJOR="${BASH_REMATCH[1]}"
    CURRENT_MINOR="${BASH_REMATCH[2]}"
    CURRENT_PATCH="${BASH_REMATCH[3]}"
    CURRENT_PRERELEASE="${BASH_REMATCH[5]:-}"
    CURRENT_PRERELEASE_NUM="${BASH_REMATCH[7]:-0}"
    
    # Handle prerelease suffix without number (e.g., 1.2.3-alpha)
    if [ -n "$CURRENT_PRERELEASE" ] && [ "$CURRENT_PRERELEASE_NUM" = "0" ] && [ -z "${BASH_REMATCH[7]}" ]; then
      CURRENT_PRERELEASE_NUM=0
    fi
  else
    printf 'Warning: Could not parse version from tag: %s\n' "$VERSION_STRING"
    CURRENT_MAJOR=0
    CURRENT_MINOR=1
    CURRENT_PATCH=0
    CURRENT_PRERELEASE=""
    CURRENT_PRERELEASE_NUM=0
  fi
  
  COMMITS_SINCE="${LATEST_TAG}..HEAD"
fi

printf 'Current version: %s.%s.%s\n' "$CURRENT_MAJOR" "$CURRENT_MINOR" "$CURRENT_PATCH"
[ -n "$CURRENT_PRERELEASE" ] && printf 'Current prerelease: %s.%s\n' "$CURRENT_PRERELEASE" "$CURRENT_PRERELEASE_NUM"

# Detect prerelease -> stable promotion (no commits required)
NEED_FORCE_RELEASE=false
if [ "$PRERELEASE_MODE" = "false" ] && [ -n "$CURRENT_PRERELEASE" ]; then
  printf 'Promoting prerelease %s to stable %s.%s.%s\n' "$LATEST_TAG" "$CURRENT_MAJOR" "$CURRENT_MINOR" "$CURRENT_PATCH"
  NEED_FORCE_RELEASE=true
fi

# Analyze commit log
MAJOR_BUMP=false
MINOR_BUMP=false
PATCH_BUMP=false

FEATURES=""
FIXES=""
BREAKING=""
OTHERS=""

# Pre-fetch all commit bodies in one pass to avoid per-commit git calls
# Store commit bodies to a hash array with using a commit hash as a key
declare -A COMMIT_BODIES
_current_hash=""
while IFS= read -r _line; do
  if [[ "$_line" =~ ^BODYHASH:([0-9a-f]+)$ ]]; then
    _current_hash="${BASH_REMATCH[1]}"
    COMMIT_BODIES["$_current_hash"]=""
  elif [ -n "$_current_hash" ]; then
    COMMIT_BODIES["$_current_hash"]+="${_line}"$'\n'
  fi
done < <(git log $COMMITS_SINCE --no-merges --format="BODYHASH:%H%n%b" 2>/dev/null || true)

# Use \x01 (instead of |) as field separator to avoid collisions with commit message content
COMMIT_LOG=$(git log $COMMITS_SINCE --no-merges --pretty=format:"%s%x01%H" 2>/dev/null || echo "")

printf '=== Commits to analyze ===\n'
printf '%s\n' "$COMMIT_LOG"
printf '===========================\n'

# Exit if no commits
if [ -z "$COMMIT_LOG" ]; then
  if [ "$NEED_FORCE_RELEASE" = "true" ]; then
    printf 'No new commits, but promoting prerelease to stable\n'
  else
    printf 'No commits found that require a release\n'
    printf 'needs-release=false\n' >> $GITHUB_OUTPUT
    exit 0
  fi
fi

# Use `\x01` as a separator for corner case that | is used in a commit message
while IFS=$'\x01' read -r message hash; do
  [ -z "$message" ] && continue
  
  # Detect BREAKING CHANGE (feat!:, fix!:, BREAKING CHANGE)
  printf 'Checking: [%s]\n' "$message"
  if echo "$message" | grep -qE "^[a-z]+(\(.+\))?!:" || echo "$message" | grep -qE "^BREAKING CHANGE(\(.+\))?!?:"; then
    printf '  -> BREAKING CHANGE detected\n'
    MAJOR_BUMP=true
    BREAKING="${BREAKING}- ${message} (${hash})\n"
    continue
  fi

  # Detect BREAKING CHANGE in footer/body using pre-fetched commits
  if printf '%s' "${COMMIT_BODIES[$hash]}" | grep -qE "^BREAKING CHANGE(:|$)"; then
    printf '  -> BREAKING CHANGE detected in footer/body\n'
    MAJOR_BUMP=true
    BREAKING="${BREAKING}- ${message} (${hash})\n"
    continue
  fi

  # Detect feat: -> minor
  if echo "$message" | grep -qE "^feat(\(.+\))?:"; then
    printf '  -> Minor change detected\n'
    MINOR_BUMP=true
    FEATURES="${FEATURES}- ${message} (${hash})\n"
  # Detect fix: -> patch
  elif echo "$message" | grep -qE "^fix(\(.+\))?:"; then
    printf '  -> Patch change detected\n'
    PATCH_BUMP=true
    FIXES="${FIXES}- ${message} (${hash})\n"
  # Other Conventional Commits -> patch
  elif echo "$message" | grep -qE "^(docs|style|refactor|perf|test|chore|ci|build)(\(.+\))?:"; then
    printf '  -> Patch change detected\n'
    PATCH_BUMP=true
    OTHERS="${OTHERS}- ${message} (${hash})\n"
  fi
done <<< "$COMMIT_LOG"

# Exit if no releasable commits found
if [ "$MAJOR_BUMP" = false ] && [ "$MINOR_BUMP" = false ] && [ "$PATCH_BUMP" = false ]; then
  if [ "$NEED_FORCE_RELEASE" = "true" ]; then
     printf 'No new commits, but promoting prerelease to stable\n'
  else
    printf 'No Conventional Commits found that require a release\n'
    printf 'needs-release=false\n' >> $GITHUB_OUTPUT
    exit 0
  fi
fi

# Calculate version
NEW_MAJOR=$CURRENT_MAJOR
NEW_MINOR=$CURRENT_MINOR
NEW_PATCH=$CURRENT_PATCH
NEW_PRERELEASE_NUM=0

# Determine bump type
if [ "$MAJOR_BUMP" = true ]; then
  BUMP_TYPE="major"
elif [ "$MINOR_BUMP" = true ]; then
  BUMP_TYPE="minor"
else
  BUMP_TYPE="patch"
fi

# initial development mode
if [ "$INITIAL_DEVELOPMENT" = "true" ] && [ "$CURRENT_MAJOR" = "0" ]; then
  printf 'Initial development mode enabled\n'
  printf '=== Before initial-dev check ===\n'
  printf 'INITIAL_DEVELOPMENT=%s\n' "$INITIAL_DEVELOPMENT"
  printf 'CURRENT_MAJOR=%s\n' "$CURRENT_MAJOR"
  printf 'BUMP_TYPE=%s\n' "$BUMP_TYPE"
  printf 'MAJOR_BUMP=%s, MINOR_BUMP=%s, PATCH_BUMP=%s\n' "$MAJOR_BUMP" "$MINOR_BUMP" "$PATCH_BUMP"
  printf '=================================\n'
  case "$BUMP_TYPE" in
    major)
      printf 'Shifting major to minor\n'
      BUMP_TYPE="minor"
      MAJOR_BUMP=false
      MINOR_BUMP=true
      ;;
    minor | patch)
      printf 'Shifting minor/patch to patch\n'
      BUMP_TYPE="patch"
      MAJOR_BUMP=false
      MINOR_BUMP=false
      ;;
  esac
  printf '=== After initial-dev check ===\n'
  printf 'BUMP_TYPE=%s\n' "$BUMP_TYPE"
  printf 'MAJOR_BUMP=%s, MINOR_BUMP=%s, PATCH_BUMP=%s\n' "$MAJOR_BUMP" "$MINOR_BUMP" "$PATCH_BUMP"
  printf '=================================\n'
else
  printf 'Initial development mode not enabled or not applicable\n'
fi

# Pre-release mode
if [ "$PRERELEASE_MODE" = "true" ]; then
  # If current tag has the same prerelease suffix, increment the number
  if [ "$CURRENT_PRERELEASE" = "$PRERELEASE_SUFFIX" ]; then
    NEW_PRERELEASE_NUM=$((CURRENT_PRERELEASE_NUM + 1))
  else
    # Start new prerelease series - calculate core version first
    if [ "$MAJOR_BUMP" = true ]; then
      NEW_MAJOR=$((CURRENT_MAJOR + 1))
      NEW_MINOR=0
      NEW_PATCH=0
    elif [ "$MINOR_BUMP" = true ]; then
      NEW_MINOR=$((CURRENT_MINOR + 1))
      NEW_PATCH=0
    else
      NEW_PATCH=$((CURRENT_PATCH + 1))
    fi
    NEW_PRERELEASE_NUM=1
  fi
  
  NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}-${PRERELEASE_SUFFIX}.${NEW_PRERELEASE_NUM}"
  VERSION_CORE="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
  IS_PRERELEASE="true"
  BUMP_TYPE="prerelease"
else
  # Normal release mode
  # If current is prerelease, release that core version if the core version does not exist
  CURRENT_STABLE_VERSION="${TAG_PREFIX}${CURRENT_MAJOR}.${CURRENT_MINOR}.${CURRENT_PATCH}"
  if [ -n "$CURRENT_PRERELEASE" ] && ! git rev-parse "$CURRENT_STABLE_VERSION" > /dev/null 2>&1; then
    # Release from prerelease - keep the same version
    echo "promoting prerelease ${CURRENT_STABLE_VERSION} to stable"
    NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
  else
    # Normal version bump
    if [ "$MAJOR_BUMP" = true ]; then
      NEW_MAJOR=$((CURRENT_MAJOR + 1))
      NEW_MINOR=0
      NEW_PATCH=0
    elif [ "$MINOR_BUMP" = true ]; then
      NEW_MINOR=$((CURRENT_MINOR + 1))
      NEW_PATCH=0
    else
      NEW_PATCH=$((CURRENT_PATCH + 1))
    fi
    NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
  fi
  VERSION_CORE="$NEW_VERSION"
  IS_PRERELEASE="false"
  NEW_PRERELEASE_NUM=0
fi

# if first release, version is overrided to 0.1.0
if [ "$FIRST_RELEASE" = true ]; then
  echo "First release detected, overriding version to 0.1.0"
  NEED_RELEASE=true
  NEW_VERSION="0.1.0"
  VERSION_CORE="0.1.0"
  NEW_MAJOR=0
  NEW_MINOR=1
  NEW_PATCH=0
  IS_PRERELEASE="false"
  BUMP_TYPE="patch"
  NEW_PRERELEASE_NUM=0
fi

TAG_NAME="${TAG_PREFIX}${NEW_VERSION}"

printf 'New version: %s (bump type: %s)\n' "$NEW_VERSION" "$BUMP_TYPE"

printf 'needs-release=true\n' >> $GITHUB_OUTPUT
echo "new-version=$NEW_VERSION" >> $GITHUB_OUTPUT
echo "version-core=$VERSION_CORE" >> $GITHUB_OUTPUT
echo "major=$NEW_MAJOR" >> $GITHUB_OUTPUT
echo "minor=$NEW_MINOR" >> $GITHUB_OUTPUT
echo "patch=$NEW_PATCH" >> $GITHUB_OUTPUT
echo "prerelease-number=$NEW_PRERELEASE_NUM" >> $GITHUB_OUTPUT
echo "is-prerelease=$IS_PRERELEASE" >> $GITHUB_OUTPUT
echo "bump-type=$BUMP_TYPE" >> $GITHUB_OUTPUT
echo "tag-name=$TAG_NAME" >> $GITHUB_OUTPUT

# Save content for CHANGELOG
{
  printf 'features<<EOF\n'
  printf '%b' "$FEATURES"
  printf 'EOF\n'
} >> $GITHUB_OUTPUT

{
  printf 'fixes<<EOF\n'
  printf '%b' "$FIXES"
  printf 'EOF\n'
} >> $GITHUB_OUTPUT

{
  printf 'breaking<<EOF\n'
  printf '%b' "$BREAKING"
  printf 'EOF\n'
} >> $GITHUB_OUTPUT

{
  printf 'others<<EOF\n'
  printf '%b' "$OTHERS"
  printf 'EOF\n'
} >> $GITHUB_OUTPUT
