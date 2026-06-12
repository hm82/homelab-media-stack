#!/usr/bin/env zsh
#
# Music Library Processing Pipeline
#
# Flow:
#   1. Analyze source downloads
#   2. Ingest files into inbox
#   3. Analyze inbox contents
#   4. Organize albums for beets import
#   5. Import into library via beets
#   6. Audit results
#
# Environment Variables:
#   RUN_ID=<id>                Override pipeline run identifier
#   ANALYZE=true|false         Enable pre/post analysis reports
#   DRY_RUN=true|false         Pass through to child scripts
#
# Stage Controls:
#   SKIP_INGEST=true
#   SKIP_ORGANIZE=true
#   SKIP_IMPORT=true
#   SKIP_AUDIT=true
#
# Examples:
#   ANALYZE=false ./run_music_pipeline.zsh
#   ANALYZE=true ~/media-stack/scripts/music/run_music_pipeline.zsh /mnt/media/_downloads/music
#   SKIP_IMPORT=true ./run_music_pipeline.zsh
#   DRY_RUN=true ./run_music_pipeline.zsh
#
# Reports:
#   /mnt/media/_downloads/reports/music-pipeline/$RUN_ID
#
# Logs:
#   /mnt/media/_downloads/logs/music-pipeline/$RUN_ID
#

set -euo pipefail

SCRIPT_DIR="${0:A:h}"

export RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
export DRY_RUN="${DRY_RUN:-false}"

SOURCE_DIR="${1:-/mnt/media/_downloads/music}"
INBOX_DIR="/mnt/media/_downloads/music-inbox"

SECONDS=0
PIPELINE_START_TS="$(date '+%F %T')"

REPORT_DIR="/mnt/media/_downloads/reports/music-pipeline/$RUN_ID"
LOG_DIR="/mnt/media/_downloads/logs/music-pipeline/$RUN_ID"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

log() {
  echo "[$(date '+%F %T')] $*"
}

run_stage() {
  local stage="$1"
  shift

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "Starting: $stage"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  "$@"

  log "Completed: $stage"
}

trap '
echo ""
echo "ERROR: Music pipeline failed"
echo "Line: $LINENO"
echo "Run ID: $RUN_ID"
' ERR

# Pipeline Manifest
cat > "$REPORT_DIR/pipeline-manifest.txt" <<MANIFEST
RUN_ID=$RUN_ID
START=$PIPELINE_START_TS
HOST=$(hostname)
SOURCE_DIR=$SOURCE_DIR
INBOX_DIR=$INBOX_DIR
ANALYZE=${ANALYZE:-true}
DRY_RUN=$DRY_RUN
SKIP_INGEST=${SKIP_INGEST:-false}
SKIP_ORGANIZE=${SKIP_ORGANIZE:-false}
SKIP_IMPORT=${SKIP_IMPORT:-false}
SKIP_AUDIT=${SKIP_AUDIT:-false}
MANIFEST

#
# Stage 1: Analyze raw downloads
#

if [[ "${ANALYZE:-false}" == "true" ]]; then
  run_stage "Analyze source downloads" \
    "$SCRIPT_DIR/analyze_music_directory.zsh" "$SOURCE_DIR"
fi

#
# Stage 2: Ingest downloads into inbox
#

if [[ "${SKIP_INGEST:-false}" != "true" ]]; then
  run_stage "Ingest files" \
    "$SCRIPT_DIR/ingest_music_downloads.zsh" "$SOURCE_DIR"
else
  log "Skipping ingest stage."
fi

#
# Stage 3: Analyze inbox after ingestion
#

if [[ "${ANALYZE:-false}" == "true" ]]; then
  run_stage "Analyze inbox" \
    "$SCRIPT_DIR/analyze_music_directory.zsh" "$INBOX_DIR"
fi

# Optional metadata repair stage.
# Recommended manual use:
#   "$SCRIPT_DIR/repair_music_metadata.zsh" report
# Later, once trusted:
#   MIN_CONFIDENCE=90 "$SCRIPT_DIR/repair_music_metadata.zsh" apply

#
# Stage 4: Organize files for beets
#

if [[ "${SKIP_ORGANIZE:-false}" != "true" ]]; then
  run_stage "Organize files for Beets" \
    "$SCRIPT_DIR/organize_music_library.zsh"
else
  log "Skipping organize stage."
fi

#
# Stage 5: Import into library
#
 
if [[ "${SKIP_IMPORT:-false}" != "true" ]]; then
  run_stage "Import with Beets" \
    "$SCRIPT_DIR/import_beets_library.zsh" run
else
  log "Skipping import stage."
fi

#
# Stage 6: Audit results
#

if [[ "${SKIP_AUDIT:-false}" != "true" ]]; then
  run_stage "Audit import run" \
    "$SCRIPT_DIR/audit_music_pipeline.zsh"
else
  log "Skipping audit stage."
fi

ELAPSED_SECONDS=$SECONDS
PIPELINE_END_TS="$(date '+%F %T')"

cat >> "$REPORT_DIR/pipeline-manifest.txt" <<MANIFEST
END=$PIPELINE_END_TS
ELAPSED_SECONDS=$ELAPSED_SECONDS
MANIFEST

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Music pipeline completed successfully"
echo "Run ID: $RUN_ID"
echo "Elapsed: ${ELAPSED_SECONDS}s"
echo "Reports: $REPORT_DIR"
echo "Logs:    $LOG_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"