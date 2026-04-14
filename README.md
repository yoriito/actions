# GitHub Actions Collection

A collection of reusable GitHub Composite Actions for CI/CD workflows.

## Available Actions

| Action | Description |
|--------|-------------|
| [semantic-release](./semantic-release) | Automated versioning and releases based on Conventional Commits |
| [update-srcrev](./update-srcrev) | Automatically update SRCREV in Yocto/OpenEmbedded recipes |
| [cmake-build-test](./cmake-build-test) | Run CMake build and tests in a devcontainer |
| [check-conventional-commits](./check-conventional-commits) | Verify PR commits follow Conventional Commits |
| [japanese-check](./japanese-check) | Scan files and commits for Japanese characters |

## Usage

All actions in this repository can be referenced using the following format:

```yaml
uses: yoriito/actions/<action-name>@<version>
```

### Versioning

We use semantic versioning for our actions:

- `@v1` - Major version
- `@v1.2.3` - Specific version
- `@main` - Latest development version

---

## Actions Overview

### semantic-release

Automates semantic versioning based on [Conventional Commits](https://www.conventionalcommits.org/):

**Version Bump Rules:**
- `feat!:` or `BREAKING CHANGE` → **Major** (x.0.0)
- `feat:` → **Minor** (0.x.0)
- All others (`fix:`, `docs:`, etc.) → **Patch** (0.0.x)

**Features:**
- Automatic version calculation
- CHANGELOG.md generation
- GitHub Release creation
- Initial release support (Don't do major updating on v0.X.X)
- Pre-release support (alpha, beta, rc)
- Outputs for post-processing (CMake, Cargo.toml, etc.)

**Example Usage:**
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

      # Update version files after release
      - if: steps.release.outputs.release-created == 'true'
        run: |
          # CMake
          sed -i "s/project(\([^)]*\) VERSION [0-9.]*)/project(\1 VERSION ${{ steps.release.outputs.version-core }})/" CMakeLists.txt
          git add CMakeLists.txt && git commit -m "chore: bump version" && git push
```

See [semantic-release README](./semantic-release/README.md) for full documentation.

### update-srcrev

Automatically update SRCREV in Yocto/OpenEmbedded recipe files to the latest git revision.

**Features**
- Parses `SRC_URI` (single line, continuation lines, multiple entries)
- Supports `git://` and `gitsm://` protocols
- Handles named sources (`SRCREV_main`, `SRCREV_sub`, etc.)
- Auto-detects branch from recipe
- Skips `AUTOREV` entries

**Example Usage:**
```yml
name: Update SRCREV

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  workflow_dispatch:

permissions:
  contents: write

jobs:
  update:
    name: Update SRCREV
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Find recipe files with SRC_URI and SRCREV
        id: find
        run: |
          # ... Find recipe files with SRC_URI and SRCREV ...
          # ... Users need to provide files should be updated to `recipe-paths` input ...

      - name: Update SRCREV
        if: steps.find.outputs.found == 'true'
        id: update
        uses: yoriito/actions/update-srcrev@v0
        with:
          recipe-paths: ${{ steps.find.outputs.recipes }}

      - name: Push changes
        if: steps.update.outputs.updated == 'true'
        run: git push
```

See [update-srcrev README](./update-srcrev/README.md) for full documentation.

### cmake-build-test

Run CMake For Build & Test on Yoriito devcontainer

**Features**
- Configure CMake project on Yoriito devcontainer
- Build CMake project on Yoriito devcontainer
- Run tests with CTest on Yoriito devcontainer

**Example Usage:**
```yml
name: CMake Build & Test

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: docker login
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build and Test
        uses: yoriito/actions/cmake-build-test@v0
```

See [cmake-build-test README](./cmake-build-test/README.md) for full documentation.

### check-conventional-commits

Verify that PR commits follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.  
Blocks merge and posts a comment when violations are found.

**Features**
- Checks all commits in a Pull Request
- Posts detailed comment with violations and fix instructions
- Blocks merge via failed status check
- Configurable allowed types
- Optional scope requirement
- Ignores merge commits by default

**Example Usage:**
```yml
name: Check Commits

on:
  pull_request:
    types: [opened, synchronize, reopened, edited]

permissions:
  pull-requests: write
  contents: read

jobs:
  check:
    name: Conventional Commits
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Check Conventional Commits
        uses: yoriito/actions/check-conventional-commits@v0
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

See [check-conventional-commits README](./check-conventional-commits/README.md) for full documentation.

### japanese-check

Automatically detects unintended Japanese characters  in modified files and commit messages to prevent their contamination in the codebase. For manual executions (`workflow_dispatch`), scans all files and all commit messages in the repository.

**Features**
- Checks only changes on Pull Request/Push (diff-based) or all files/commits on manual trigger (`workflow_dispatch`)
- Validates both file contents and new commit messages
- Flexible exclusions by regex, extension, or MIME type
- Customizable logging verbosity (`log_level`)
- Outputs CI results (validation status, number of violations) for downstream workflow use

**Example Usage:**
```yaml
name: Japanese contamination check

on:
  pull_request:
    types: [opened, synchronize, reopened, edited]
  push:
  workflow_dispatch:

permissions:
  pull-requests: read
  contents: read

jobs:
  check:
    name: Japanese_check
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Check Japanese contamination
        id: jp_check
        uses: yoriito/actions/japanese-check@main
        with:
          log_level: 'modified'   # 'error', 'modified', or 'all'
          exclude_patterns: ''    # (e.g.) 'README\.md\|docs/\|test/|\.yml'

      - name: Report status
        run: |
          IS_VALID="${{ (steps.jp_check.outputs.is_valid_files == 'true') && (steps.jp_check.outputs.is_valid_commits == 'true') }}"
          echo "All clean? = $IS_VALID"
          echo "Number of problematic files = ${{ steps.jp_check.outputs.invalid_file_count }}"
          echo "Number of problematic commits = ${{ steps.jp_check.outputs.invalid_commit_count }}"
          if [ "$IS_VALID" != "true" ]; then
            exit 1
          fi
```

See [japanese-check README](./japanese-check/README.md) for full documentation.

## Requirements

- GitHub Actions runner with `bash` shell
- `git` CLI
- `gh` CLI (GitHub CLI) - pre-installed on GitHub-hosted runners
- `jq` CLI
- `ninja` build system (for `cmake-build-test`)(optional, can change the cmake build system)

## Related Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Creating Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
