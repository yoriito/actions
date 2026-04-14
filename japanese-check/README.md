# Japanese Character Contamination Check Action

GitHub Actions workflow for automatically detecting Japanese characters (including full-width alphanumerics and symbols) in **modified files and commit messages** in your repository.

---

## Overview & Main Features

This Action helps prevent unintended introduction of Japanese characters into codebases by scanning:

- **Diff-based checks on Pull Requests and Push events:**  
  Only files and commit messages changed in the diff between the head and the merge-base with the base branch are checked (changes that exist only on the base branch are not re-scanned).
- **Full repository scan on workflow_dispatch:**  
  All files and the entire commit history are validated when triggered manually, regardless of diffs.
- **Commit message as well as file content validation:**  
  Not only file contents, but also new commit messages are checked for Japanese contamination.
- **Text-based file checking:**  
  Only text-based files are scanned.  
  Although `.svg` and `.drawio` `(.dio)` files are technically text-based formats, files that are primarily used as diagrams or illustrations are excluded.
- **Flexible exclusion:**  
  Files or directories can be excluded using regex patterns, extensions, or MIME types.  
  By specifying conditions such as file names, path, or extensions in the `exclude_patterns`, you can add repository-specific exclusion files.
- **Configurable logging verbosity:**  
  The amount and type of information printed to the console can be customized with the `log_level` input.
- **Clear outputs for CI/CD workflows:**  
  Validation status and the number of problematic files/commits are exposed as outputs for use in workflow steps.

> **What counts as "Japanese contamination"?**  
> By default, any character in `[ぁ-んァ-ン一-龥Ａ-Ｚａ-ｚ０-９！-～、。「」『』【】（）＜＞［］｛｝：；？＠￥％＆＋＊＝ー―＿]`
> is considered Japanese or a related full-width symbol.

---

## Console Output Control (`log_level`)

You can choose how much information is shown in GitHub Actions logs by setting the `log_level` input:

- `"error"`: Only outputs files/commits where errors are found and those that are skipped.
- `"modified"` (**default**): As above, but also lists all checked files/commits for PUSH and PR events.
- `"all"`: Lists all checked files/commits for any event type, including workflow_dispatch (full scan).

This allows you to adapt noise level and observability based on your CI scenario.

---

## Quick Start

```yaml
# .github/workflows/japanese-check.yml
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
          log_level: 'modified'   # Options: 'error', 'modified', 'all'
          exclude_patterns: ''    # (e.g.) 'README\.md\|docs/\|test/|\.yml'

      - name: Report Japanese contamination status
        run: |
          IS_VALID="${{ (steps.jp_check.outputs.is_valid_files == 'true') && (steps.jp_check.outputs.is_valid_commits == 'true') }}"

          echo "All files and commits don't have Japanese? = $IS_VALID"
          echo "Number of Japanese files = ${{ steps.jp_check.outputs.invalid_file_count }}"
          echo "Number of Japanese commits = ${{ steps.jp_check.outputs.invalid_commit_count }}"

          if [ "$IS_VALID" != "true" ]; then
            exit 1
          fi
```

---

## Event Behavior Summary

- **Pull Request / Push:**  
  Only the **diff** (changed files and commits) is checked for Japanese contamination.
- **workflow_dispatch:**  
  The **entire repository** (all files and all commit messages in history) is scanned.

---

## Inputs
| Input             | Description                                                                                        | Required |
|-------------------|---------------------------------------------------------------------------------------------------|----------|
| `token`           | GitHub Token (not usually needed; workflow token used by default)                                  | ❌       |
| `pattern`         | Regex pattern for Japanese/full-width character detection                                          | ❌       |
| `exclude_patterns`| Input for excluding additional specific files or directories; accepts regex patterns separated by `\|` (e.g. `README\.md\|docs/\|test/`) | ❌       |
| `skip_list_ext`   | Excluded extensions (`\|` separated; e.g. `png\|jpg\|pdf`).                                          | ❌       |
| `skip_list_mime`  | MIME prefixes to exclude (`\|` separated)                                                          | ❌       |
| `checklist_mime`  | Exception MIME-types (pattern) to check even if skipped by above                                  | ❌       |
| `log_level`       | Log verbosity for console output (`error`, `modified`, or `all`). See details above.               | ❌       |

### Default values for inputs
<details>
  <summary>Click to expand</summary>

  - `token`: `''`
  - `pattern`: `[ぁ-んァ-ン一-龥Ａ-Ｚａ-ｚ０-９！-～、。「」『』【】（）＜＞［］｛｝：；？＠￥％＆＋＊＝ー―＿]`
  - `exclude_patterns`: `''`
  - `skip_list_ext`: `doc|docx|xls|xlsx|ppt|pptx|zip|pdf|png|jpg|jpeg|gif|exe|elf|dll|so|o|a|jar|war|tar|gz|tgz|bz2|xz|7z|mp3|mp4|mov|avi|flv|webm|ico|woff|woff2|ttf|eot|bmp|psd|apk|bin|dat|dmg|pack|svg|drawio|dio`
  - `skip_list_mime`: `application/|image/|audio/|video/`
  - `checklist_mime`: `image/.*xml|application/.*xml|application/.*json|application/.*yaml|application/.*jwt|application/x-.*|application/javascript|application/rtf|application/ecmascript|application/sql`
  - `log_level`: `'modified'`
</details>


---

## Outputs

| Output               | Description                                                                  |
|----------------------|------------------------------------------------------------------------------|
| `is_valid_files`     | Are all relevant files free of Japanese contamination? (`true`/`false`)      |
| `is_valid_commits`   | Are all relevant commit messages clean? (`true`/`false`)                     |
| `invalid_file_count` | Number of problematic files detected                                         |
| `invalid_commit_count` | Number of problematic commit messages detected                             |

**Example usage in workflow:**

```sh
IS_VALID="${{ (steps.jp_check.outputs.is_valid_files == 'true') && (steps.jp_check.outputs.is_valid_commits == 'true') }}"
if [ "$IS_VALID" != "true" ]; then
  exit 1
fi
```

---

## Logic Details

1. **Target selection**  
   - On Pull Request/Push: Collects only the files and commits introduced in the diff.
   - On workflow_dispatch: Selects all files and the full commit history.
2. **File checking**  
   - Skips files according to pattern, extension and MIME rules.
   - Checks all remaining text files for Japanese contamination, logs failing files and lines.
   - The set of checked files shown in logs depends on your `log_level`.
3. **Commit message checking**  
   - Analyzes each relevant commit message using the detection pattern.
   - Again, log output is subject to the `log_level`.
4. **Results**  
   - Outputs indicate both file/commit results and number of violations.
   - Either file or commit message contamination will fail the workflow.

---

## Notes

- **Diff/whole-scan logic is event-driven:**  
  No manual input is needed to switch between diff or repository-wide scan.
- **Highly customizable:**  
  Exclusion lists and patterns can be adapted to your project.
- **Verbose logging for failures and customizable logging for checks:**  
  Use `log_level` to choose between silent (only show errors/skips), modified-only listing, or always listing all targets.
- **Non-ASCII quotes:**  
  Unicode `’` (U+2019), `”` (U+201D) were previously included in the Japanese detection set by default, but are now excluded from detection. 
- **Exclusion of text-based diagrams:**  
  Files primarily used as diagrams or illustrations (e.g., `.svg`, `.drawio`, `.dio`) are excluded from scanning, despite being text-based formats.
