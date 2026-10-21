# GitHub Actions Collection

A collection of reusable GitHub Composite Actions for CI/CD workflows.

## Available Actions

| Action | Description |
|--------|-------------|
| [semantic-release](./semantic-release) | Automated versioning and releases based on Conventional Commits |
| [update-srcrev](./update-srcrev) | Automatically update SRCREV in Yocto/OpenEmbedded recipes |
| [check-conventional-commits](./check-conventional-commits) | Verify PR commits follow Conventional Commits |
| [japanese-check](./japanese-check) | Scan files and commits for Japanese characters |
| [sbom_md-report](./sbom_md-report) | Generate human-readable Markdown reports from SPDX JSON files |
| [polaris](./polaris) | Run Polaris SCA scan and commit SCA / SBOM reports |

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

### sbom_md-report

Generate human-readable Markdown license analysis reports from SPDX JSON files.

**Features**
- Recursively scans `security-reports*` directories for `*.json` SPDX files
- Generates a corresponding `*.md` report for each SPDX JSON file
- Classifies packages by license compliance category
- Extracts potential issues for quick triage
- Supports basic SPDX expression parsing (`AND` / `OR` / `WITH`)
- Normalizes `+` suffix licenses such as `GPL-2.0+`
- Escapes table-breaking characters and normalizes line breaks for readable Markdown output

**Example Usage:**
```yml
name: Generate SPDX Markdown Reports

on:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout caller repo
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Run composite action from actions repository
        uses: yoriito/actions/sbom_md-report@main

      - name: Commit and push
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        shell: bash
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          if ! git diff --cached --quiet; then
            git commit -m "docs: generate SPDX markdown"
            git push https://x-access-token:${GITHUB_TOKEN}@github.com/${{ github.repository }}.git HEAD:${{ github.ref_name }}
          else
            echo "No changes"
          fi
```

See [sbom_md-report README](./sbom_md-report/README.md) for full documentation.

### polaris

Run Black Duck Polaris SCA security scan, download SCA / SBOM reports, and commit them back to the repository.

**Features**
- Polaris SCA scan via `blackduck-inc/black-duck-security-scan`
- Download SCA report (PDF) and SPDX SBOM (JSON)
- Auto-commit reports under `REPORT_DIR`
- SAST currently disabled (can be re-enabled in the action)

**Example Usage:**
```yml
name: Polaris Security Scan

on:
  push:
    branches: [main]
    paths-ignore:
      - 'security-reports/**'
  workflow_dispatch: {}

env:
  POLARIS_ACCESS_TOKEN: ${{ secrets.POLARIS_ACCESS_TOKEN }}
  REPORT_DIR: security-reports/polaris

permissions:
  contents: write

jobs:
  polaris:
    name: Polaris
    runs-on: ubuntu-latest
    steps:
      - name: Generate Github App Token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.RELEASE_BOT_ID }}
          private-key: ${{ secrets.RELEASE_BOT_KEY }}
          owner: ${{ github.repository_owner }}

      - uses: actions/checkout@v6
        with:
          token: ${{ steps.app-token.outputs.token }}
          fetch-depth: 0

      - name: Polaris Security Scan
        uses: yoriito/actions/polaris@main
        with:
          token: ${{ steps.app-token.outputs.token }}
          polaris_project_name: ${{ vars.POLARIS_PROJECT_NAME }}
          polaris_branch_name: ${{ github.ref_name }}
          detect_search_depth: ${{ vars.DETECT_SEARCH_DEPTH }}
```

See [polaris README](./polaris/README.md) for full documentation.

## Requirements

- GitHub Actions runner with `bash` shell
- `git` CLI
- `gh` CLI (GitHub CLI) - pre-installed on GitHub-hosted runners
- `jq` CLI

## Related Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Creating Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

## Notes
 
Some files in this directory may be generated automatically by CI tools.
