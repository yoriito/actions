# Update SRCREV Action

Automatically update SRCREV in Yocto/OpenEmbedded recipe files to the latest git revision.

## Features

- Parses `SRC_URI` (single line, continuation lines, multiple entries)
- Supports `git://` and `gitsm://` protocols
- Handles named sources (`SRCREV_main`, `SRCREV_sub`, etc.)
- Auto-detects branch from recipe
- Skips `AUTOREV` entries

## Quick Start

```yaml
- uses: yoriito/actions/update-srcrev@v0
  with:
    recipe-paths: |
      meta-mylayer/recipes-app/myapp_git.bb
      meta-mylayer/recipes-core/mylib.inc

- run: git push
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `recipe-paths` | Recipe file paths (space or newline separated) | ✅ | - |
| `token` | GitHub Token for private repositories | ❌ | `''` |

## Outputs

| Output | Description |
|--------|-------------|
| `updated` | Whether any recipes were updated (`true` / `false`) |
| `changes` | JSON array of changes |
| `summary` | Human-readable summary |

### Get the changes at JSON Format

You can get what recipes are changed via `changes` output in JSON format like the following:

```json
[
  {
    "recipe": "meta-app/recipes-core/myapp_git.bb",
    "name": "default",
    "uri": "git://github.com/example/myapp.git",
    "branch": "main",
    "old_rev": "abc123...",
    "new_rev": "def456..."
  }
]
```

## Commit Message Format

When changes are detected, this action automatically create a commit for all changes like the following:

```
chore: automatically update srcrev

myapp_git: main: abc123def456 -> def456789012
mylib: kirkstone: 111222333444 -> 555666777888
```

This action will create a commit, but it will not push the changes automatically.  
You need to run `git push` in your workflow after this action.

## Supported Recipe Formats

### `SRC_URI`

```bash
# Single line
SRC_URI = "git://github.com/example/repo.git;branch=main;protocol=https"

# Continuation lines
SRC_URI = "git://github.com/example/repo.git;branch=main \
           file://0001-fix.patch"

# Multiple git sources with names
SRC_URI = "git://github.com/example/main.git;branch=main;name=main \
           git://github.com/example/sub.git;branch=develop;name=sub"
```

### SRCREV

```bash
# Single source
SRCREV = "abc123def456..."

# Named sources
SRCREV_main = "abc123..."
SRCREV_sub = "def456..."
```

## Examples

See [examples/](./examples/) directory.
