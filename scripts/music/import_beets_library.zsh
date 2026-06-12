#!/usr/bin/env zsh
set -euo pipefail

MODE="${1:-run}"

BASE="/mnt/media"
DOWNLOADS="$BASE/_downloads"

INBOX="${INBOX_DIR:-$DOWNLOADS/music-inbox}"
STAGING="${STAGING_DIR:-$DOWNLOADS/music-staging}"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$DOWNLOADS/music-imported}"
BEETS_CONFIG="${BEETS_CONFIG:-$BASE/config/beets/config.yaml}"
MAX_UNREADABLE_FILES="${MAX_UNREADABLE_FILES:-10}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
REPORT_DIR="${RUN_REPORT_DIR:-$DOWNLOADS/reports/music-pipeline/$RUN_ID}"
LOG_DIR="${RUN_LOG_DIR:-$DOWNLOADS/logs/music-pipeline/$RUN_ID}"
RUN_ARCHIVE="$ARCHIVE_ROOT/$(date +%F)/$RUN_ID"

LOG_FILE="$LOG_DIR/beets-import.log"
DUPLICATES_REVIEW="$REPORT_DIR/duplicates-review.txt"
ARCHIVED_CSV="$REPORT_DIR/archived_files.csv"
IMPORT_SUMMARY="$REPORT_DIR/import-summary.txt"
LIBRARY_BEFORE="$REPORT_DIR/library_before.txt"
LIBRARY_AFTER="$REPORT_DIR/library_after.txt"
LIBRARY_DIFF="$REPORT_DIR/library_diff.txt"

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

check_config() {
  log "Checking Beets configuration..."
  beet -c "$BEETS_CONFIG" version | tee -a "$LOG_FILE"

  if beet -c "$BEETS_CONFIG" config | grep -q "duplicate_action: skip"; then
    log "Duplicate handling: duplicate_action=skip found."
  else
    log "WARNING: duplicate_action: skip not found in Beets config."
    log "Recommended config:"
    log "  import:"
    log "    duplicate_action: skip"
  fi
}

run_duplicates_check() {
  log "Running Beets duplicate report..."
  beet -c "$BEETS_CONFIG" duplicates 2>&1 | tee "$REPORT_DIR/beet-duplicates.txt" | tee -a "$LOG_FILE" || true
}

run_import_safe() {
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

  grep -Ei "duplicate|skip|already|reimport|exists" "$LOG_FILE" > "$DUPLICATES_REVIEW" || true
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

cleanup_staging() {
  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN: would clean staging: $STAGING"
    return
  fi

  log "Cleaning staging directory..."
  find "$STAGING" -mindepth 1 -delete || true
}

check_unreadable_files() {
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
  fi

  return 0
}

write_summary() {
  local imported_count duplicate_count archived_count staged_count

  imported_count=0
  duplicate_count=0
  archived_count=0
  staged_count="$(count_audio_files "$STAGING")"

  [[ -f "$LIBRARY_DIFF" ]] && imported_count="$(wc -l < "$LIBRARY_DIFF" | tr -d ' ')"
  [[ -f "$DUPLICATES_REVIEW" ]] && duplicate_count="$(wc -l < "$DUPLICATES_REVIEW" | tr -d ' ')"
  [[ -f "$ARCHIVED_CSV" ]] && archived_count="$(( $(wc -l < "$ARCHIVED_CSV" | tr -d ' ') - 1 ))"

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
Duplicate Log Lines: $duplicate_count
Archived Items:      $archived_count
Remaining Staged:    $staged_count

Artifacts
────────────────────────────────────
Import Log:          $LOG_FILE
Library Before:      $LIBRARY_BEFORE
Library After:       $LIBRARY_AFTER
Library Diff:        $LIBRARY_DIFF
Duplicates Review:   $DUPLICATES_REVIEW
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
      check_config
      run_import_safe
      archive_inbox
      cleanup_staging
      write_summary
      ;;

    tag)
      validate
      show_summary
      log "Running Beets MusicBrainz autotag import against staging..."
      beet -c "$BEETS_CONFIG" import "$STAGING" 2>&1 | tee -a "$LOG_FILE"
      UNREADABLE_REVIEW="$REPORT_DIR/unreadable-files.txt"
      check_unreadable_files \
  	"$IMPORT_LOG" \
  	"$UNREADABLE_REVIEW" || die \
  	"Beets reported unreadable files. Review: $UNREADABLE_REVIEW"
      write_summary
      ;;

    duplicates)
      require_cmd beet
      [[ -f "$BEETS_CONFIG" ]] || die "Beets config not found: $BEETS_CONFIG"
      show_summary
      run_duplicates_check
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
