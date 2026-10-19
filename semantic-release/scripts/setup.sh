#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 JASPAR
# 
# Setup Git configuration for release automation

set -e

printf 'Setting up Git configuration...\n'
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

printf 'Git setup complete\n'
