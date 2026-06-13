#!/usr/bin/env zsh
#
# 06_audit_music_library.zsh
#
# Post-run audit script for the music ingestion pipeline.
#
# Usage:
#   06_audit_music_library.zsh                 # Audit latest run
#   06_audit_music_library.zsh <RUN_ID>        # Audit specific run
#
# Example:
#   06_audit_music_library.zsh 20260511-130501
#
# Outputs:
#   reports/music-pipeline/<RUN_ID>/audit-report.txt
#   reports/music-pipeline/<RUN_ID>/audit-summary.csv
#
# Future Enhancements:
#   - Quality breakdown by format (FLAC vs MP3 vs M4A)
#   - Average bitrate and sample rate analysis
#   - Top artists/albums added in the run
#   - Missing artwork report
#   - Embedded vs external artwork analysis
#   - Duplicate candidate report using `beet duplicates`
#   - HTML dashboard report
#   - Trend analysis across runs
#   - Integration with Navidrome rescan API
#   - Email/Slack notifications
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.zsh"

###############################################################################
# Configuration
###############################################################################

REPORTS_ROOT="${REPORTS_ROOT:-/mnt/media/_downloads/reports/music-pipeline}"
LOGS_ROOT="${LOGS_ROOT:-/mnt/media/_downloads/logs/music-pipeline}"
MUSIC_ROOT="${MUSIC_ROOT:-/mnt/media/Music}"

###############################################################################
# Helpers
###############################################################################

die() {
  echo "ERROR: $*" >&2
  exit 1
}

count_csv_rows() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }
  local lines
  lines="$(wc -l < "$file" | tr -d ' ')"
  (( lines > 0 )) && echo $((lines - 1)) || echo 0
}

count_lines() {
  local file="$1"
  [[ -f "$file" ]] && wc -l < "$file" | tr -d ' ' || echo 0
}

find_latest_run() {
  ls -1 "$REPORTS_ROOT" 2>/dev/null | sort | tail -1
}

human_size() {
  local path="$1"
  [[ -e "$path" ]] && du -sh "$path" 2>/dev/null | awk '{print $1}' || echo "N/A"
}

###############################################################################
# Resolve Run ID
###############################################################################

RUN_ID="${1:-}"

if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(find_latest_run)"
fi

[[ -n "$RUN_ID" ]] || die "No run ID specified and no runs found."
REPORT_DIR="$REPORTS_ROOT/$RUN_ID"
LOG_DIR="$LOGS_ROOT/$RUN_ID"

[[ -d "$REPORT_DIR" ]] || die "Report directory not found: $REPORT_DIR"

###############################################################################
# Input Files
###############################################################################

RUN_SUMMARY="$REPORT_DIR/run_summary.txt"
LIBRARY_DIFF="$REPORT_DIR/library_diff.txt"
DUPLICATES_CSV="$REPORT_DIR/duplicates.csv"
QUARANTINE_CSV="$REPORT_DIR/quarantine.csv"
ARCHIVED_CSV="$REPORT_DIR/archived_files.csv"
ORGANIZED_CSV="$REPORT_DIR/organized_files.csv"
SIDECAR_CSV="$REPORT_DIR/sidecar_files.csv"
INGESTED_CSV="$REPORT_DIR/ingested_files.csv"

AUDIT_REPORT="$REPORT_DIR/audit-report.txt"
AUDIT_CSV="$REPORT_DIR/audit-summary.csv"

###############################################################################
# Gather Metrics
###############################################################################

INGESTED_COUNT=$(count_lines "$INGESTED_CSV")
ORGANIZED_COUNT=$(count_lines "$ORGANIZED_CSV")
SIDECAR_COUNT=$(count_lines "$SIDECAR_CSV")
IMPORTED_COUNT=$(count_lines "$LIBRARY_DIFF")
DUPLICATE_COUNT=$(count_lines "$DUPLICATES_CSV")
QUARANTINE_COUNT=$(count_lines "$QUARANTINE_CSV")
ARCHIVED_COUNT=$(count_lines "$ARCHIVED_CSV")

LIBRARY_TRACK_COUNT=$(find "$MUSIC_ROOT" -type f \
  \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.opus" -o -iname "*.ogg" \) \
  2>/dev/null | wc -l | tr -d ' ')

LIBRARY_SIZE=$(human_size "$MUSIC_ROOT")

STATUS="SUCCESS"
if (( QUARANTINE_COUNT > 0 )); then
  STATUS="SUCCESS_WITH_WARNINGS"
fi

###############################################################################
# Write Text Report
###############################################################################

cat > "$AUDIT_REPORT" <<EOF
Music Pipeline Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run ID:              $RUN_ID
Status:              $STATUS

Files Discovered
────────────────────────────────────
Ingested Files:      $INGESTED_COUNT
Organized Files:     $ORGANIZED_COUNT
Sidecar Files:       $SIDECAR_COUNT

Import Results
────────────────────────────────────
Imported Tracks:     $IMPORTED_COUNT
Duplicates Skipped:  $DUPLICATE_COUNT
Quarantined Files:   $QUARANTINE_COUNT
Archived Files:      $ARCHIVED_COUNT

Library Metrics
────────────────────────────────────
Total Tracks:        $LIBRARY_TRACK_COUNT
Library Size:        $LIBRARY_SIZE

Artifacts
────────────────────────────────────
Report Dir:          $REPORT_DIR
Log Dir:             $LOG_DIR
Audit Report:        $AUDIT_REPORT
Audit CSV:           $AUDIT_CSV
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

###############################################################################
# Write CSV Summary
###############################################################################

cat > "$AUDIT_CSV" <<EOF
metric,value
run_id,$RUN_ID
status,$STATUS
ingested_files,$INGESTED_COUNT
organized_files,$ORGANIZED_COUNT
sidecar_files,$SIDECAR_COUNT
imported_tracks,$IMPORTED_COUNT
duplicates_skipped,$DUPLICATE_COUNT
quarantined_files,$QUARANTINE_COUNT
archived_files,$ARCHIVED_COUNT
library_track_count,$LIBRARY_TRACK_COUNT
library_size,$LIBRARY_SIZE
EOF

###############################################################################
# Console Output
###############################################################################

cat "$AUDIT_REPORT"

echo
echo "Audit report written to:"
echo "  $AUDIT_REPORT"

echo
echo "CSV summary written to:"
echo "  $AUDIT_CSV"
