# SPDX Markdown Report Generate Action

GitHub Actions workflow for automatically generating **Markdown license analysis reports** from SPDX JSON files in your repository.

---

## Overview & Main Features

This Action scans SPDX JSON reports and generates human-readable Markdown summaries for each file.

- **Batch conversion of SPDX JSON files:**  
  Recursively scans directories matching `security-reports*` and processes all `*.json` files.
- **Automatic Markdown report generation:**  
  For each SPDX JSON file, a corresponding `*.md` file is created in the same directory.
- **License compliance categorization:**  
  Each package is classified into compliance categories based on `licenseConcluded` / `licenseDeclared`.
- **Potential issue extraction:**  
  Packages requiring review are listed under "Potential Issues" for quick triage.
- **Expression-aware SPDX token handling:**  
  Supports basic SPDX expression parsing (`AND` / `OR` / `WITH`) and normalizes `+` suffix licenses (e.g., `GPL-2.0+` → `GPL-2.0`).
- **Safe Markdown output formatting:**  
  Escapes table-breaking characters and normalizes line breaks to keep reports readable.

---

## Quick Start
This Quick Start workflow automatically generates SPDX Markdown reports and pushes them back to the same branch when changes are detected.
```yaml
# .github/workflows/generate-sbom-markdown.yml
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

      - name: Run composite action from yoriito/actions repository
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

> The same example is available at: `sbom_md-report/examples/generate_sbom_md-report.yml`

---

## Expected Input Layout

The action scans directories named like:

- `security-reports`
- `security-reports-dev`
- `security-reports-2026`

and finds SPDX JSON files recursively:

- `security-reports/**/*.json`
- `security-reports*/**/*.json`

For each `xxx.json`, it generates `xxx.md` in the same location.

---

## Report Contents

Each generated Markdown report contains:

1. **Document metadata**
   - SPDX Version
   - Created timestamp
   - Data License
2. **Package table**
   - Package Name
   - Version
   - License Concluded
   - License Declared
   - Compliance Category
   - Review Status
3. **Potential Issues section**
   - Non-permissive, unknown, or uncategorized licenses summarized as bullet points

---

## Compliance Categories

The action currently maps licenses into the following categories:

- **Permissive**  
  Complies with organization policy. No review required.
- **Review Required**  
  Non-copyleft licenses that require review.
- **Uncategorized (Review Required)**  
  Licenses not covered by current automatic categorization.
- **Unspecified/Unknown (Review Required)**  
  License is missing/unknown (`NOASSERTION`, `NONE`, empty, etc.).
- **Restricted (Exception required)**  
  Copyleft or similarly restricted licenses. Review and explicit exception are required.

If a package includes multiple licenses in an SPDX expression, the strictest category is prioritized (e.g., any restricted token results in `Restricted`).

---

## Behavior Notes

- **Categorization priority:**  
  `licenseConcluded` is evaluated first, then `licenseDeclared`.
- **Unknown-only handling:**  
  If all detected license tokens are unknown/unspecified, category becomes `Unspecified/Unknown (Review Required)`.
- **Issue deduplication:**  
  Duplicate issue lines are collapsed in "Potential Issues".
- **No package case:**  
  If SPDX has no packages, an empty placeholder row is emitted in the table.

---

## Inputs

This composite action currently does not define user-configurable inputs in `action.yml`.

---

## Outputs

This composite action currently does not define explicit outputs in `action.yml`.

---

## Example Use Cases

- Generate review-ready license summaries from CI-produced SPDX JSON artifacts.
- Commit Markdown snapshots for audit trails in regulated environments.
- Provide non-legal reviewers with a concise, readable OSS license overview.

---

## Notes

- This action requires Python available on the runner environment (GitHub-hosted Ubuntu runners include it by default).
- The workflow needs `contents: write` permission only if you commit generated Markdown files back to the repository.
- If no target JSON files are found, no Markdown files are generated.
