#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"

echo ""
echo "=================================="
echo "Music Pipeline Test Suite"
echo "=================================="

echo ""
echo "1. Syntax Smoke Test"
"$SCRIPT_DIR/tests/smoke_test.zsh"

echo ""
echo "2. Stage 05 Dry Run"
"$SCRIPT_DIR/tests/test_import_dry_run.zsh"

## echo ""
## echo "3. Full Pipeline Dry Run"
## "$SCRIPT_DIR/tests/test_pipeline_dry_run.zsh"

echo ""
echo "=================================="
echo "ALL TESTS PASSED"
echo "=================================="
