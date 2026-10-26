#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
# 
# Fetch repository history and tags for release automation

set -e

printf 'Fetching repository history and tags...\n'
git fetch --unshallow || true
git fetch --tags --force --all

printf 'Fetch repository complete\n'
