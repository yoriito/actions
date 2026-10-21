# Polaris Security Scan Action

Run Black Duck Polaris SCA security scan, download SCA / SBOM reports, and commit them back to the repository.

Official quickstart: [Black Duck Security Scan Action with Polaris](https://documentation.blackduck.com/bundle/bridge/page/documentation/t_github-polaris-quickstart.html)

---

## Overview & Main Features

- **Polaris SCA scan** via `blackduck-inc/black-duck-security-scan`
- **Report generation & download**
  - SCA report (PDF)
  - SBOM (SPDX JSON)
- **Auto-commit** of reports under `REPORT_DIR`

---

## Prerequisites

| Item | Description |
|------|-------------|
| Env `POLARIS_ACCESS_TOKEN` | Polaris API access token |
| Env `REPORT_DIR` | Directory to store reports |
| Repository variable `POLARIS_PROJECT_NAME` | Polaris project name for this repository |
| Repository variable `DETECT_SEARCH_DEPTH` | Detect search depth |
| Workflow permission `contents: write` | Required to push report commits |
| GitHub token with write access | For committing reports (GitHub App token) |

---

## Quick Start

```yaml
# .github/workflows/polaris.yml
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

> The same example is available at: `polaris/examples/polaris.yml`

---

## Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `token` | GitHub token with write access | ✅ |
| `polaris_project_name` | Polaris project name | ✅ |
| `polaris_branch_name` | Polaris branch name | ✅ |
| `detect_search_depth` | Detect search depth | ✅ |

---

## Outputs

This composite action currently does not define explicit outputs in `action.yml`.

---

## Generated Reports

| File name | Format | Description |
|-----------|--------|-------------|
| `SCA.pdf` | PDF | SCA findings report |
| `SBOM.json` | JSON | SPDX SBOM |

---

## Behavior Notes

- Currently supports SCA scanning and SBOM report generation.
- SAST is currently commented out.
