#!/usr/bin/env zsh
#
# Stage 5 - Library Import
#
# Imports organized music from staging into the
# Beets-managed library.
#
# Responsibilities:
#   - Validate import environment
#   - Report import policy
#   - Execute Beets import
#   - Generate import artifacts
#   - Archive source material
#   - Cleanup staging
#

set -euo pipefail

MODE="${1:-run}"

BASE="/mnt/media"
DOWNLOADS="$BASE/_downloads"

INBOX="${INBOX_DIR:-$DOWNLOADS/music-inbox}"
STAGING="${STAGING_DIR:-$DOWNLOADS/music-staging}"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$DOWNLOADS/music-imported}"
BEETS_CONFIG="${BEETS_CONFIG:-$BASE/config/beets/config.yaml}"

# Fail the import only if unreadable files exceed this threshold.
# Small numbers of corrupt files are reported but do not stop the pipeline.
MAX_UNREADABLE_FILES="${MAX_UNREADABLE_FILES:-10}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
REPORT_DIR="${RUN_REPORT_DIR:-$DOWNLOADS/reports/music-pipeline/$RUN_ID}"
LOG_DIR="${RUN_LOG_DIR:-$DOWNLOADS/logs/music-pipeline/$RUN_ID}"
RUN_ARCHIVE="$ARCHIVE_ROOT/$(date +%F)/$RUN_ID"

LOG_FILE="$LOG_DIR/beets-import.log"
ARCHIVED_CSV="$REPORT_DIR/archived_files.csv"
IMPORT_SUMMARY="$REPORT_DIR/import-summary.txt"
LIBRARY_BEFORE="$REPORT_DIR/library_before.txt"
LIBRARY_AFTER="$REPORT_DIR/library_after.txt"
LIBRARY_DIFF="$REPORT_DIR/library_diff.txt"
PRE_IMPORT_AUDIT="$REPORT_DIR/pre-import-audit.txt"
DUPLICATE_TRACKS="$REPORT_DIR/duplicate-tracks.txt"
DUPLICATE_ALBUMS="$REPORT_DIR/duplicate-albums.txt"
UNREADABLE_REVIEW="$REPORT_DIR/unreadable-files.txt"

mkdir -p "$REPORT_DIR" "$LOG_DIR" "$ARCHIVE_ROOT"

AUDIO_EXPR=(-iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav" -o -iname "*.alac" -o -iname "*.aiff" -o -iname "*.ape" -o -iname "*.wv")

log() {
  print "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

count_audio_files() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo 0; return; }
  find "$dir" -type f \( "${AUDIO_EXPR[@]}" \) 2>/dev/null | wc -l | tr -d ' '
}

snapshot_library() {
  local output="$1"
  beet -c "$BEETS_CONFIG" ls -f '$path' 2>/dev/null | sort > "$output" || true
}

show_summary() {
  log "Mode:           $MODE"
  log "Run ID:         $RUN_ID"
  log "Inbox:          $INBOX"
  log "Staging:        $STAGING"
  log "Archive:        $RUN_ARCHIVE"
  log "Beets config:   $BEETS_CONFIG"
  log "Report dir:     $REPORT_DIR"
  log "Log dir:        $LOG_DIR"
  log "Staged audio:   $(count_audio_files "$STAGING")"
}

# Environment Validation
validate() {
  require_cmd beet
  require_cmd find
  require_cmd rsync
  require_cmd grep
  require_cmd comm

  [[ -f "$BEETS_CONFIG" ]] || die "Beets config not found: $BEETS_CONFIG"
  [[ -d "$STAGING" ]] || die "Staging directory not found: $STAGING"

  local staged_count
  staged_count="$(count_audio_files "$STAGING")"
  [[ "$staged_count" -gt 0 ]] || die "No audio files found in staging: $STAGING"
}

#
# Report effective Beets import policy.
#
# Informational only.
# Does not enforce configuration.
#
#
show_import_policy() {

    log "Beets Import Policy"

    local dup_action

    dup_action=$(
        beet -c "$BEETS_CONFIG" config \
        | awk '
            /^import:/ { in_import=1; next }
            /^[^ ]/ && in_import { exit }
            in_import && /duplicate_action:/ { print $2 }
        '
    )

    log "Duplicate Policy: ${dup_action:-unknown}"

    case "$dup_action" in
        keep)
            log "Library preservation mode enabled."
            ;;
        skip)
            log "Duplicate imports will be skipped."
            ;;
        merge)
            log "Duplicate albums may be merged."
            ;;
        *)
            log "Using Beets duplicate policy: $dup_action"
            ;;
    esac
}

pre_import_audit() {

    log "Running pre-import audit..."

    cat > "$PRE_IMPORT_AUDIT" <<EOF
Pre-Import Audit
================

Run ID: $RUN_ID

Generated:
$(date)

Staging Directory:
$STAGING

Audio Files:
$(count_audio_files "$STAGING")

Albums:
$(find "$STAGING" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

EOF
}

# Duplicate Risk Report 
# Identify Duplicate Tracks and Albums
# (Import Everything, Review Later)
run_duplicate_risk_report() {

    log "Generating duplicate reports..."

    beet -c "$BEETS_CONFIG" duplicates -F \
        > "$DUPLICATE_TRACKS" 2>/dev/null || true

    beet -c "$BEETS_CONFIG" duplicates -a -F \
        > "$DUPLICATE_ALBUMS" 2>/dev/null || true

    log "Duplicate track report: $DUPLICATE_TRACKS"
    log "Duplicate album report: $DUPLICATE_ALBUMS"
}

execute_import() {
  # Snapshot library before import so we can
  # calculate imported items after completion.
  log "Taking pre-import library snapshot..."
  snapshot_library "$LIBRARY_BEFORE"

  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN: would run:"
    log "  beet -c '$BEETS_CONFIG' import -A '$STAGING'"
    return
  fi

  log "Running Beets import using existing tags preserved (-A)..."
  log "Command: beet -c '$BEETS_CONFIG' import -A '$STAGING'"

  beet -c "$BEETS_CONFIG" import -A "$STAGING" 2>&1 | tee -a "$LOG_FILE"

  log "Taking post-import library snapshot..."
  snapshot_library "$LIBRARY_AFTER"

  if [[ -f "$LIBRARY_BEFORE" && -f "$LIBRARY_AFTER" ]]; then
    comm -13 "$LIBRARY_BEFORE" "$LIBRARY_AFTER" > "$LIBRARY_DIFF" || true
  fi
}

post_import_audit() {

    log "Running post-import audit..."

    # Future:
    # audit_album_years
    # audit_track_numbers
    # audit_navidrome
}

archive_inbox() {
  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN: would archive inbox contents:"
    log "  $INBOX -> $RUN_ARCHIVE"
    return
  fi

  [[ -d "$INBOX" ]] || {
    log "Inbox does not exist; nothing to archive."
    return
  }

  if ! find "$INBOX" -mindepth 1 -maxdepth 1 | read; then
    log "Inbox is empty; nothing to archive."
    return
  fi

  log "Archiving original inbox to: $RUN_ARCHIVE"
  mkdir -p "$RUN_ARCHIVE"

  echo "source_path,archive_path" > "$ARCHIVED_CSV"

  find "$INBOX" -mindepth 1 -maxdepth 1 -print0 |
    while IFS= read -r -d '' item; do
      base="$(basename "$item")"
      dest="$RUN_ARCHIVE/$base"

      mv "$item" "$dest"

      printf '"%s","%s"\n' "$item" "$dest" >> "$ARCHIVED_CSV"
      log "Archived: $item -> $dest"
    done
}

# Cleanup staging after import (whether dry-run or real)
cleanup_staging() {
  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN: would clean staging: $STAGING"
    return
  fi

  log "Cleaning staging directory..."
  find "$STAGING" -mindepth 1 -delete || true
}

check_unreadable_files() {
  if [[ "$MODE" == "dry-run" ]]; then
    log "Unreadable file check: SKIPPED (dry-run)"
    return 0
  fi

  local log_file="$1"
  local report_file="$2"
  local count=0

  [[ -f "$log_file" ]] || return 0

  grep -Ei "unreadable file:" "$log_file" \
    | sed -E 's/^.*unreadable file:[[:space:]]*//' \
    > "$report_file" || true

  [[ -f "$report_file" ]] && count=$(wc -l < "$report_file" | tr -d ' ')

  if (( count > MAX_UNREADABLE_FILES )); then
    log "ERROR: $count unreadable files detected."
    log "Review: $report_file"
    return 1
  fi

  if (( count > 0 )); then
    log "WARNING: $count unreadable files detected."
    log "Review: $report_file"
    return 0
  fi

  log "Unreadable file check: PASS"
  return 0
}

write_summary() {
  local imported_count duplicate_tracks duplicate_albums archived_count staged_count

  imported_count=0
  duplicate_tracks=0
  duplicate_albums=0
  archived_count=0
  staged_count="$(count_audio_files "$STAGING")"

  if [[ "$MODE" == "dry-run" ]]; then
    LIBRARY_AFTER="N/A (dry-run)"
    LIBRARY_DIFF="N/A (dry-run)"
  fi

  [[ -f "$LIBRARY_DIFF" ]] && imported_count="$(wc -l < "$LIBRARY_DIFF" | tr -d ' ')"
  [[ -f "$ARCHIVED_CSV" ]] && archived_count="$(( $(wc -l < "$ARCHIVED_CSV" | tr -d ' ') - 1 ))"
  [[ -f "$DUPLICATE_TRACKS" ]] && duplicate_tracks=$(wc -l < "$DUPLICATE_TRACKS" | tr -d ' ')
  [[ -f "$DUPLICATE_ALBUMS" ]] && duplicate_albums=$(wc -l < "$DUPLICATE_ALBUMS" | tr -d ' ')

  cat > "$IMPORT_SUMMARY" <<EOF
Beets Import Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run ID:              $RUN_ID
Mode:                $MODE
Staging Dir:         $STAGING
Inbox Dir:           $INBOX
Archive Dir:         $RUN_ARCHIVE

Results
────────────────────────────────────
Library Diff Count:  $imported_count
Duplicate Tracks:    $duplicate_tracks
Duplicate Albums:    $duplicate_albums
Archived Items:      $archived_count
Remaining Staged:    $staged_count

Artifacts
────────────────────────────────────
Import Log:          $LOG_FILE
Library Before:      $LIBRARY_BEFORE
Library After:       $LIBRARY_AFTER
Library Diff:        $LIBRARY_DIFF
Duplicate Albums:    $DUPLICATE_ALBUMS
Duplicate Tracks:    $DUPLICATE_TRACKS
Archived CSV:        $ARCHIVED_CSV
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

  cat "$IMPORT_SUMMARY"
}

usage() {
  cat <<EOF
Usage:
  import_beets_library.zsh [dry-run|run|tag|duplicates]

Modes:
  dry-run     Validate and preview Beets import/archive actions
  run         Import staging with Beets, archive inbox, clean staging
  tag         Run full Beets autotag import against staging
  duplicates  Run duplicate report only

Default:
  run
EOF
}

main() {
  case "$MODE" in
    dry-run|run)
      validate
      show_summary
      show_import_policy
      pre_import_audit
      run_duplicate_risk_report
      execute_import

      check_unreadable_files \
	"$LOG_FILE" \
	"$UNREADABLE_REVIEW" 

      post_import_audit
      archive_inbox
      cleanup_staging
      write_summary
      ;;

    tag)
      validate
      show_summary
      show_import_policy

      log "Running Beets MusicBrainz autotag import against staging..."

      beet -c "$BEETS_CONFIG" import "$STAGING" 2>&1 | tee -a "$LOG_FILE"

      UNREADABLE_REVIEW="$REPORT_DIR/unreadable-files.txt"

      check_unreadable_files \
  	"$LOG_FILE" \
  	"$UNREADABLE_REVIEW" || die \
  	"Beets reported unreadable files. Review: $UNREADABLE_REVIEW"

      write_summary
      ;;

    duplicates)
      require_cmd beet
      [[ -f "$BEETS_CONFIG" ]] || die "Beets config not found: $BEETS_CONFIG"

      show_summary
      run_duplicate_risk_report
      ;;

    -h|--help|help)
      usage
      ;;

    *)
      usage
      exit 1
      ;;
  esac
}

main
