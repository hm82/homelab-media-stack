#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h:h}"

TEST_ROOT="/tmp/music-pipeline-e2e"
SOURCE_DIR="$TEST_ROOT/downloads"

echo "Preparing E2E test environment..."

rm -rf "$TEST_ROOT"
mkdir -p "$SOURCE_DIR/TestAlbum"

touch "$SOURCE_DIR/TestAlbum/test.mp3"

RUN_ID="pipeline-e2e-test" \
DRY_RUN=true \
ANALYZE=false \
SOURCE_DIR="$SOURCE_DIR" \
"$SCRIPT_DIR/00_run_music_pipeline.zsh"

REPORT_DIR="/mnt/media/_downloads/reports/music-pipeline/pipeline-e2e-test"

[[ -d "$REPORT_DIR" ]] || {
    echo "FAIL: Report directory missing"
    exit 1
}

[[ -f "$REPORT_DIR/pipeline-manifest.txt" ]] || {
    echo "FAIL: Pipeline manifest missing"
    exit 1
}

echo ""
echo "PASS: Full pipeline dry-run completed"
