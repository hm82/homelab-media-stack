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

# use for CSV files with header row
count_csv_rows() {
  local file="$1"

  [[ -s "$file" ]] || {
    echo 0
    return
  }

  local lines
  lines=$(wc -l < "$file")

  (( lines > 1 )) && echo $(( lines - 1 )) || echo 0
}

# use for txt files 
count_text_lines() {
  local file="$1"
  [[ -f "$file" ]] && wc -l < "$file" | tr -d ' ' || echo 0
}

find_latest_run() {
  ls -1 "$REPORTS_ROOT" 2>/dev/null | sort | tail -1
}

human_size() {
  local music_dir_path="$1"

  [[ -e "$music_dir_path" ]] || {
    echo "N/A"
    return 0
  }

  local music_lib_size

  music_lib_size=$(command du -sh "$music_dir_path" 2>/dev/null) || {
    echo "N/A"
    return 0
  }
  echo "${music_lib_size%%[[:space:]]*}"
}


###############################################################################
# Resolve Run ID
###############################################################################

RUN_ID="${RUN_ID:-${1:-}}"

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
DUPLICATE_TRACKS_FILE="$REPORT_DIR/duplicate-tracks.txt"
DUPLICATE_ALBUMS_FILE="$REPORT_DIR/duplicate-albums.txt"
QUARANTINE_CSV="$REPORT_DIR/quarantine.csv"
UNKNOWN_METADATA_CSV="$REPORT_DIR/unknown_metadata.csv"
ARCHIVED_CSV="$REPORT_DIR/archived_files.csv"
ORGANIZED_CSV="$REPORT_DIR/organized_files.csv"
SIDECAR_CSV="$REPORT_DIR/sidecar_files.csv"
INGESTED_CSV="$REPORT_DIR/ingested_files.csv"

AUDIT_REPORT="$REPORT_DIR/audit-report.txt"
AUDIT_CSV="$REPORT_DIR/audit-summary.csv"

###############################################################################
# Gather Metrics
###############################################################################

INGESTED_COUNT=$(count_csv_rows "$INGESTED_CSV")
ORGANIZED_COUNT=$(count_csv_rows "$ORGANIZED_CSV")
SIDECAR_COUNT=$(count_csv_rows "$SIDECAR_CSV")
IMPORTED_COUNT=$(count_text_lines "$LIBRARY_DIFF")
DUPLICATE_TRACK_COUNT=$(count_text_lines "$DUPLICATE_TRACKS_FILE")
DUPLICATE_ALBUM_COUNT=$(count_text_lines "$DUPLICATE_ALBUMS_FILE")
DUPLICATE_COUNT=$(( DUPLICATE_TRACK_COUNT + DUPLICATE_ALBUM_COUNT ))
QUARANTINE_COUNT=$(count_csv_rows "$QUARANTINE_CSV")
UNKNOWN_METADATA_COUNT=$(count_csv_rows "$UNKNOWN_METADATA_CSV")
ARCHIVED_COUNT=$(count_csv_rows "$ARCHIVED_CSV")

WARNING_COUNT=0
(( DUPLICATE_COUNT > 0 )) && ((WARNING_COUNT++))
(( UNKNOWN_METADATA_COUNT > 0 )) && ((WARNING_COUNT++))
(( QUARANTINE_COUNT > 0 )) && ((WARNING_COUNT++))

LIBRARY_TRACK_COUNT=$(find "$MUSIC_ROOT" -type f \
  \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.opus" -o -iname "*.ogg" \) \
  2>/dev/null | wc -l | tr -d ' ')

LIBRARY_SIZE=$(human_size "$MUSIC_ROOT")

STATUS="SUCCESS"

if (( DUPLICATE_COUNT > 0 || \
      UNKNOWN_METADATA_COUNT > 0 || \
      QUARANTINE_COUNT > 0 )); then
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
Warnings:	     $WARNING_COUNT

Files Discovered
────────────────────────────────────
Ingested Files:      $INGESTED_COUNT
Organized Files:     $ORGANIZED_COUNT
Sidecar Files:       $SIDECAR_COUNT

Import Results
────────────────────────────────────
Imported Tracks:     $IMPORTED_COUNT
Duplicates Skipped:  $DUPLICATE_COUNT
Unknown Metadata:    $UNKNOWN_METADATA_COUNT
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


###############################################################################
# Exit Status   
###############################################################################

if [[ "$STATUS" == "SUCCESS" ]]; then
    exit 0
else
    exit 0
fi
