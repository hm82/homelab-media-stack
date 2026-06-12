#!/usr/bin/env zsh
set -euo pipefail

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"

DOWNLOADS_ROOT="/mnt/media/_downloads"
INBOX_DIR="$DOWNLOADS_ROOT/music-inbox"
STAGING_DIR="$DOWNLOADS_ROOT/music-staging"
ARCHIVE_ROOT="$DOWNLOADS_ROOT/music-imported"
QUARANTINE_ROOT="$DOWNLOADS_ROOT/music-quarantine"

REPORTS_ROOT="$DOWNLOADS_ROOT/reports/music-pipeline"
LOGS_ROOT="$DOWNLOADS_ROOT/logs/music-pipeline"

RUN_REPORT_DIR="$REPORTS_ROOT/$RUN_ID"
RUN_LOG_DIR="$LOGS_ROOT/$RUN_ID"

mkdir -p \
  "$INBOX_DIR" \
  "$STAGING_DIR" \
  "$ARCHIVE_ROOT" \
  "$QUARANTINE_ROOT" \
  "$RUN_REPORT_DIR" \
  "$RUN_LOG_DIR"

LOG_FILE="$RUN_LOG_DIR/pipeline.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

count_audio_files() {
  find "$1" -type f \
    \( -iname "*.flac" -o -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.opus" -o -iname "*.ogg" \) \
    | wc -l
}
