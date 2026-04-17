# Check Conventional Commits Action

Verify that PR commits follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.  
Blocks merge and posts a comment when violations are found.

## Features

- Checks all commits in a Pull Request
- Posts detailed comment with violations and fix instructions
- Blocks merge via failed status check
- Configurable allowed types
- Optional scope requirement
- Ignores merge commits by default

## Quick Start

```yaml
name: Check Commits

on:
  pull_request:
    types: [opened, synchronize, reopened, edited]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: yoriito/actions/check-conventional-commits@v0
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `token` | GitHub Token | ✅ | - |
| `types` | Allowed commit types (comma-separated) | ❌ | `feat,fix,docs,style,refactor,perf,test,chore,ci,build` |
| `require-scope` | Require scope in commit message | ❌ | `false` |
| `ignore-merge-commits` | Ignore merge commits | ❌ | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `valid` | Whether all commits are valid (`true` / `false`) |
| `invalid-count` | Number of invalid commits |

## Conventional Commits Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Allowed Types (default)

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style changes (formatting, etc.) |
| `refactor` | Code refactoring |
| `perf` | Performance improvements |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |
| `ci` | CI/CD changes |
| `build` | Build system changes |

### Examples

```bash
# Valid commits
feat: add user authentication
fix(api): resolve null pointer exception
docs: update installation guide
feat!: redesign API endpoints
refactor(core): simplify validation logic

# Invalid commits
Add new feature          # Missing type
feature: add something   # Invalid type
feat add something       # Missing colon
feat:add something       # Missing space after colon
```

## Branch Protection

To block merging when commits don't comply:

1. Go to **Settings** → **Branches** → **Branch protection rules**
2. Add rule for your main branch (e.g., `main`)
3. Enable **Require status checks to pass before merging**
4. Search and select the check job name (e.g., `check`)

## PR Comment Example

When violations are found, a comment is posted:

---

## ❌ Conventional Commits Check Failed

The following commits do not follow the Conventional Commits specification:

| Commit | Message |
|--------|---------|
| abc1234 | `Add new feature` |
| def5678 | `fixed bug` |

### How to Fix

```bash
git rebase -i HEAD~N
# Change 'pick' to 'reword' for commits you want to rename
git push --force-with-lease
```

---

## Examples

See [examples/](./examples/) directory.
