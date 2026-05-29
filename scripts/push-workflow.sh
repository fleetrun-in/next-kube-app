#!/usr/bin/env bash
# GitHub blocks workflow file pushes unless the credential has the `workflow` scope.
set -euo pipefail
echo "Grant workflow scope, then push:"
echo "  gh auth refresh -h github.com -s workflow"
echo "  git push origin main"
