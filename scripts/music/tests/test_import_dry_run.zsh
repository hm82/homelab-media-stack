#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h:h}"

TEST_ROOT="/tmp/music-pipeline-test"
STAGING="$TEST_ROOT/music-staging/TestAlbum"

echo "Preparing test environment..."

rm -rf "$TEST_ROOT"
mkdir -p "$STAGING"

# Placeholder file.
# We only care that the script executes its dry-run path.
touch "$STAGING/test.mp3"

echo "Running Stage 05 dry-run..."

STAGING_DIR="$TEST_ROOT/music-staging" \
RUN_ID="test-import-dry-run" \
"$SCRIPT_DIR/05_import_music_library.zsh" dry-run

echo ""
echo "Validating artifacts..."

REPORT_DIR="/mnt/media/_downloads/reports/music-pipeline/test-import-dry-run"
LOG_DIR="/mnt/media/_downloads/logs/music-pipeline/test-import-dry-run"

[[ -d "$REPORT_DIR" ]] || {
    echo "FAIL: Report directory not created"
    exit 1
}

[[ -d "$LOG_DIR" ]] || {
    echo "FAIL: Log directory not created"
    exit 1
}

[[ -f "$LOG_DIR/beets-import.log" ]] || {
    echo "FAIL: Import log not created"
    exit 1
}

[[ -f "$REPORT_DIR/import-summary.txt" ]] || {
    echo "FAIL: import-summary.txt not created"
    exit 1
}

echo ""
echo "PASS: Stage 05 dry-run completed successfully"
