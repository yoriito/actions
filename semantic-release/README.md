# Semantic Release Action

Automated semantic versioning, CHANGELOG generation, and release creation based on [Conventional Commits](https://www.conventionalcommits.org/).

## Features

- ✅ Automatic version calculation from commit history
- ✅ CHANGELOG.md generation
- ✅ GitHub Release creation
- ✅ Pre-release support (alpha, beta, rc)
- ✅ Rich outputs for post-processing (update CMakeLists.txt, Cargo.toml, etc.)

## Architecture

This action is implemented as a **composite action** with modular shell scripts:

```
semantic-release/
├── action.yml                          # Action orchestration (210 lines)
├── scripts/
│   ├── setup.sh                        # Git configuration (15 lines)
│   ├── analyze.sh                      # Commit analysis & version calculation (313 lines)
│   ├── changelog-generate.sh           # CHANGELOG generation (90 lines)
│   └── finalize.sh                     # Tag creation & GitHub release (85 lines)
└── README.md
```

### Design Principles

- **Modularity**: Each script has a single responsibility
- **Testability**: Scripts can be unit tested independently
- **Reusability**: Scripts can be invoked from other workflows
- **Maintainability**: Clear separation of concerns

---

## Version Bump Rules

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat!:` or `BREAKING CHANGE` | **Major** (x.0.0) | `feat!: redesign API` |
| `feat:` | **Minor** (0.x.0) | `feat: add parser` |
| Others (`fix:`, `docs:`, etc.) | **Patch** (0.0.x) | `fix: memory leak` |

## Quick Start

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
          fetch-tags: true

      - uses: yoriito/actions/semantic-release@v1
        id: release
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      # Update version file after release (optional)
      - if: steps.release.outputs.release-created == 'true'
        run: |
          # Example: Update CMakeLists.txt
          sed -i "s/VERSION [0-9.]*/VERSION ${{ steps.release.outputs.version-core }}/" CMakeLists.txt
          git add CMakeLists.txt
          git commit -m "chore: bump version to ${{ steps.release.outputs.version-core }}"
          git push
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `token` | GitHub Token with write access | ✅ | - |
| `phase` | Action phase: `all`, `prepare`, or `finalize` | ❌ | `all` |
| `default-branch` | Default branch name | ❌ | `main` |
| `changelog-path` | Path to CHANGELOG file | ❌ | `CHANGELOG.md` |
| `initial-development` | Enable initial development mode (for 0.X.X only) | ❌ | `false` |
| `prerelease` | Enable pre-release mode | ❌ | `false` |
| `prerelease-suffix` | Pre-release suffix (alpha, beta, rc, etc) | ❌ | `alpha` |
| `draft` | Create as draft release | ❌ | `false` |
| `tag-prefix` | Tag prefix | ❌ | `v` |

### Finalize Phase Inputs

These are required when using `phase: finalize`:

| Input | Description |
|-------|-------------|
| `finalize-version` | Version string from prepare phase |
| `finalize-version-core` | Core version without prerelease suffix |
| `finalize-tag-name` | Tag name to create |
| `finalize-changelog` | Changelog content for release notes |
| `finalize-is-prerelease` | Whether this is a prerelease |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `release-created` | Whether a release was created | `true` |
| `needs-release` | [prepare] Whether a release is needed | `true` |
| `version` | Full version string | `1.2.3` or `1.2.3-alpha.1` |
| `version-core` | Core version (no suffix) | `1.2.3` |
| `major` | Major version number | `1` |
| `minor` | Minor version number | `2` |
| `patch` | Patch version number | `3` |
| `prerelease-number` | Pre-release number | `1` |
| `is-initial-dev` | Whether the initial development mode is enabled | `true` / `false` |
| `is-prerelease` | Whether this is a pre-release | `true` / `false` |
| `tag-name` | Created tag name | `v1.2.3` |
| `release-url` | GitHub Release URL | `https://...` |
| `changelog` | Generated changelog content | (markdown) |
| `bump-type` | Type of version bump | `major` / `minor` / `patch` / `prerelease` |

## Post-Processing Examples

Use outputs to update version files in your project.

### Simple Usage (phase: all)

By default, the action runs all phases at once. Post-processing runs **after** the release:

```yaml
- uses: yoriito/actions/semantic-release@v1
  id: release
  with:
    token: ${{ secrets.GITHUB_TOKEN }}

# Post-release: version file update (separate commit after tag)
- if: steps.release.outputs.release-created == 'true'
  run: |
    sed -i "..." CMakeLists.txt
    git add CMakeLists.txt && git commit -m "chore: bump version" && git push
```

### Advanced Usage (phase: prepare + finalize)

For version files to be included **in the release tag**, split into two phases:

```
Flow: CHANGELOG commit → [Your version file updates] → Tag → Push → GitHub Release
```

```yaml
# Phase 1: Analyze commits, generate CHANGELOG, commit it
- uses: yoriito/actions/semantic-release@v1
  id: prepare
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    phase: prepare

# Your custom processing (CMakeLists.txt, Cargo.toml, etc.)
- name: Update version files
  if: steps.prepare.outputs.needs-release == 'true'
  run: |
    VERSION="${{ steps.prepare.outputs.version-core }}"
    sed -i "s/VERSION [0-9.]*/VERSION ${VERSION}/" CMakeLists.txt
    git add CMakeLists.txt
    git commit -m "chore: bump version to ${VERSION}"

# Phase 2: Create tag, push all commits, create GitHub Release
- uses: yoriito/actions/semantic-release@v1
  if: steps.prepare.outputs.needs-release == 'true'
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    phase: finalize
    finalize-version: ${{ steps.prepare.outputs.version }}
    finalize-version-core: ${{ steps.prepare.outputs.version-core }}
    finalize-tag-name: ${{ steps.prepare.outputs.tag-name }}
    finalize-changelog: ${{ steps.prepare.outputs.changelog }}
    finalize-is-prerelease: ${{ steps.prepare.outputs.is-prerelease }}
```

### Phase Comparison

| Phase | What it does |
|-------|--------------|
| `all` (default) | Everything in one step: analyze → CHANGELOG → commit → tag → push → release |
| `prepare` | Analyze commits, generate CHANGELOG, commit CHANGELOG (no push) |
| `finalize` | Create tag, push all commits, create GitHub Release |

## Pre-release Workflow

### Create Pre-releases

```yaml
- uses: yoriito/actions/semantic-release@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    prerelease: true
    prerelease-suffix: alpha  # or: beta, rc
```

### Pre-release Flow

```
v1.0.0 (stable)
    ↓ feat: new feature (prerelease: true, suffix: alpha)
v1.1.0-alpha.1
    ↓ fix: bug fix
v1.1.0-alpha.2
    ↓ (prerelease: true, suffix: beta)
v1.1.0-beta.1
    ↓ (prerelease: true, suffix: rc)
v1.1.0-rc.1
    ↓ (prerelease: false) → Stable release
v1.1.0
```

## Examples

See the [examples/](./examples/) directory:

- [`release-simple.yml`](./examples/release-simple.yml) - Simple configuration
- [`release-advanced.yml`](./examples/release-advanced.yml) - Advanced configuration

## Conventional Commits

This action recognizes the following commit formats:

```
feat: add new parser                     → Minor
feat(core): improve performance          → Minor
feat!: breaking API change               → Major
fix: memory leak in allocator            → Patch
fix(parser): handle edge case            → Patch
docs: update README                      → Patch
refactor: simplify logic                 → Patch
perf: optimize hot path                  → Patch
test: add unit tests                     → Patch
chore: update dependencies               → Patch
ci: fix workflow                         → Patch
build: update CMake config               → Patch

# Breaking change in footer
fix: important change

BREAKING CHANGE: This changes behavior   → Major
```

## Requirements

- GitHub-hosted runner (Linux, macOS, or Windows)
- `fetch-depth: 0` in checkout (full git history needed)
- `fetch-tags: true` in checkout (full git tags needed)
- `contents: write` permission

## Permissions and Branch Protection

This action pushes commits and tags directly to your repository.

If you have branch protection rules enabled, additional configuration is required.

### Required Workflow Permissions

```yaml
permissions:
  contents: write    # Required: push commits and tags
```

### Branch Protection Rules

If your default branch has protection rules (required reviews, status checks, etc.), the action will fail to push.

Choose one of the following solutions:

#### Option 1: Allow GitHub Actions to Bypass (Recommended)

1. Go to **Settings** → **Branches** → **Branch protection rules**
2. Edit your rule for `main` (or your default branch)
3. Enable **Allow specified actors to bypass required pull requests**
4. Add `github-actions[bot]` to the bypass list

#### Option 2: Use Rulesets (Newer GitHub Feature)

1. Go to **Settings** → **Rules** → **Rulesets**
2. Create or edit a ruleset
3. In **Bypass list**, add:
   - **Actor**: `github-actions[bot]`
   - Or **Role**: `GitHub Actions`

#### Option 3: Use a GitHub App or PAT

Instead of `GITHUB_TOKEN`, use a Personal Access Token (PAT) or GitHub App token with appropriate permissions.

These tokens are treated as user actions and may have different bypass rules.

```yaml
- uses: yoriito/actions/semantic-release@v1
  with:
    token: ${{ secrets.PAT_TOKEN }}  # Use PAT instead of GITHUB_TOKEN
```

> **Note**: Using PAT has security implications. The token owner's permissions apply.

#### Option 4: Use Deploy Keys

For repositories with strict security requirements:

1. Generate an SSH deploy key with write access
2. Add the public key to repository **Deploy keys**
3. Add the private key as a secret
4. Configure git to use the deploy key
