#!/usr/bin/env zsh
#
# 02_ingest_music.zsh
#
# Purpose:
#   Move completed music downloads from a raw source folder into music-inbox,
#   while excluding incomplete/temp/system folders and writing audit reports.
#
# Default:
#   Source: /mnt/media/_downloads/music
#   Target: $INBOX_DIR from lib/common.zsh
#
# Usage:
#   02_ingest_music.zsh
#   02_ingest_music.zsh /path/to/source
#
# Optional:
#   DRY_RUN=true 02_ingest_music.zsh
#

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.zsh"

SOURCE_DIR="${1:-/mnt/media/_downloads/music}"
DRY_RUN="${DRY_RUN:-false}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
REPORT_DIR="${RUN_REPORT_DIR:-/mnt/media/_downloads/reports/music-pipeline/$RUN_ID}"
LOG_DIR="${RUN_LOG_DIR:-/mnt/media/_downloads/logs/music-pipeline/$RUN_ID}"

mkdir -p "$REPORT_DIR" "$LOG_DIR" "$INBOX_DIR"

INGESTED_CSV="$REPORT_DIR/ingested_files.csv"
SKIPPED_CSV="$REPORT_DIR/skipped_files.csv"
FAILED_CSV="$REPORT_DIR/ingest_failed_files.csv"
SUMMARY_FILE="$REPORT_DIR/ingest-summary.txt"
LOG_FILE="$LOG_DIR/ingest.log"

EXCLUDE_FILE="${EXCLUDE_FILE:-$HOME/media-stack/config/music-ingest-excludes.txt}"

typeset -a AUDIO_EXTS=(
  flac mp3 m4a aac ogg opus wav alac aiff ape wv wav
)

typeset -a SIDECAR_EXTS=(
  jpg jpeg png webp gif
  cue log lrc txt pdf
)

typeset -a DEFAULT_EXCLUDED_DIRS=(
  incomplete
  .incomplete
  tmp
  temp
  partial
  .partial
  "@eaDir"
  ".Trash-1000"
  '$RECYCLE.BIN'
  "System Volume Information"
)

typeset -a EXCLUDED_DIRS=()
typeset -a EXCLUDED_FILES=(
  "*.part"
  "*.partial"
  "*.tmp"
  "*.temp"
  "*.crdownload"
  "*.download"
  "*.!qB"
  "*.filepart"
  "*.aria2"
)

log() {
  print "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

csv_escape() {
  local value="${1:-}"
  value="${value//\"/\"\"}"
  print -r -- "\"$value\""
}

csv_row() {
  local first=true
  local out=""
  local field

  for field in "$@"; do
    if [[ "$first" == true ]]; then
      out="$(csv_escape "$field")"
      first=false
    else
      out="$out,$(csv_escape "$field")"
    fi
  done

  print -r -- "$out"
}

load_exclusions() {
  EXCLUDED_DIRS=("${DEFAULT_EXCLUDED_DIRS[@]}")

  if [[ -f "$EXCLUDE_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      EXCLUDED_DIRS+=("$line")
    done < "$EXCLUDE_FILE"
  fi
}

is_audio_file() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext:l}"

  for valid_ext in "${AUDIO_EXTS[@]}"; do
    [[ "$ext" == "$valid_ext" ]] && return 0
  done

  return 1
}

is_sidecar_file() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext:l}"

  for valid_ext in "${SIDECAR_EXTS[@]}"; do
    [[ "$ext" == "$valid_ext" ]] && return 0
  done

  return 1
}

dir_has_audio() {
    local dir="$1"
    local f

    for f in "$dir"/*(.N); do
        is_audio_file "$f" && return 0
    done

    return 1
}

folder_has_audio_before_move() {
    local dir="$1"

    find "$dir" -maxdepth 1 -type f | while read -r f; do
        is_audio_file "$f" && return 0
    done

    return 1
}

path_has_excluded_dir() {
  local path="$1"
  local d

  for d in "${EXCLUDED_DIRS[@]}"; do
    [[ "$path" == *"/$d/"* ]] && return 0
  done

  return 1
}

file_matches_excluded_pattern() {
  local file="$1"
  local base
  local p

  base="$(basename -- "$file")"

  for p in "${EXCLUDED_FILES[@]}"; do
    [[ "$base" == ${~p} ]] && return 0
  done

  return 1
}

is_excluded_path() {
  local path="$1"

  if path_has_excluded_dir "$path"; then
    return 0
  fi

  if file_matches_excluded_pattern "$path"; then
    return 0
  fi

  return 1
}

exclusion_reason() {
  local path="$1"
  local d p base

  for d in "${EXCLUDED_DIRS[@]}"; do
    if [[ "$path" == *"/$d/"* ]]; then
      print -r -- "excluded-directory:$d"
      return
    fi
  done

  base="$(basename -- "$path")"

  for p in "${EXCLUDED_FILES[@]}"; do
    if [[ "$base" == ${~p} ]]; then
      print -r -- "excluded-file-pattern:$p"
      return
    fi
  done

  print -r -- "unknown"
}

count_source_audio() {
  local count=0
  local file

  while IFS= read -r file; do
    if is_audio_file "$file"; then
      (( count += 1 ))
    fi
  done < <(find "$SOURCE_DIR" -type f 2>/dev/null)

  print -r -- "$count"
}

count_source_audio_eligible() {
  local count=0
  local file

  while IFS= read -r file; do
    is_audio_file "$file" || continue
    is_excluded_path "$file" && continue
    (( count += 1 ))
  done < <(find "$SOURCE_DIR" -type f 2>/dev/null)

  print -r -- "$count"
}

write_headers() {
  echo "source_path,target_path,size_bytes,status" > "$INGESTED_CSV"
  echo "source_path,reason,size_bytes" > "$SKIPPED_CSV"
  echo "source_path,target_path,reason" > "$FAILED_CSV"
}

move_file() {
  local file="$1"
  local rel target target_dir size

  rel="${file#$SOURCE_DIR/}"
  target="$INBOX_DIR/$rel"
  target_dir="$(dirname -- "$target")"
  size="$(stat -c '%s' "$file" 2>/dev/null || echo 0)"

  mkdir -p "$target_dir"

  if [[ "$DRY_RUN" == "true" ]]; then
    csv_row "$file" "$target" "$size" "dry-run" >> "$INGESTED_CSV"
    log "DRY-RUN: would move: $rel"
    return 0
  fi

  if [[ -e "$target" ]]; then
    local base ext stem candidate n
    base="$(basename -- "$target")"
    ext="${base##*.}"
    stem="${base%.*}"
    n=1

    if [[ "$base" == "$ext" ]]; then
      candidate="$target_dir/${base}__dup${n}"
    else
      candidate="$target_dir/${stem}__dup${n}.${ext}"
    fi

    while [[ -e "$candidate" ]]; do
      (( n += 1 ))
      if [[ "$base" == "$ext" ]]; then
        candidate="$target_dir/${base}__dup${n}"
      else
        candidate="$target_dir/${stem}__dup${n}.${ext}"
      fi
    done

    target="$candidate"
  fi

  if mv -- "$file" "$target"; then
    csv_row "$file" "$target" "$size" "moved" >> "$INGESTED_CSV"
    log "Moved: $rel"
  else
    csv_row "$file" "$target" "mv failed" >> "$FAILED_CSV"
    log "ERROR: Failed moving: $file -> $target"
    return 1
  fi
}

cleanup_empty_dirs() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN: would remove empty directories under $SOURCE_DIR"
    return
  fi

  find "$SOURCE_DIR" -depth -type d -empty \
    -not -path "$SOURCE_DIR" \
    -delete 2>/dev/null || true
}

main() {
  [[ -d "$SOURCE_DIR" ]] || die "Source directory not found: $SOURCE_DIR"

  load_exclusions
  write_headers

  log "Ingesting music from: $SOURCE_DIR"
  log "Inbox directory:       $INBOX_DIR"
  log "Run ID:                $RUN_ID"
  log "Dry run:               $DRY_RUN"
  log "Exclude file:          $EXCLUDE_FILE"

  local source_audio eligible_audio moved_count skipped_count failed_count

  source_audio="$(count_source_audio)"
  eligible_audio="$(count_source_audio_eligible)"

  log "Source audio files:    $source_audio"
  log "Eligible audio files:  $eligible_audio"

  while IFS= read -r file; do

    # Skip anything that is neither audio nor approved sidecar	  
    is_audio_file "$file" || is_sidecar_file "$file" || continue 

    size="$(stat -c '%s' "$file" 2>/dev/null || echo 0)"

    if is_excluded_path "$file"; then
      reason="$(exclusion_reason "$file")"
      csv_row "$file" "$reason" "$size" >> "$SKIPPED_CSV"
      log "Skipped: $file ($reason)"
      continue
    fi

    # Sidecars should only move if their folder contains at least one audio file
    if is_sidecar_file "$file"; then
      if ! dir_has_audio "$(dirname "$file")"; then
        size="$(stat -c '%s' "$file" 2>/dev/null || echo 0)"
	csv_row "$file" "sidecar-without-audio-folder" "$size" >> "$SKIPPED_CSV"
        log "Skipped sidecar without audio folder: $file"
        continue
      fi
    fi

    move_file "$file" || true
  done < <(find "$SOURCE_DIR" -type f 2>/dev/null)

  cleanup_empty_dirs

  moved_count=$(( $(wc -l < "$INGESTED_CSV" | tr -d ' ') - 1 ))
  skipped_count=$(( $(wc -l < "$SKIPPED_CSV" | tr -d ' ') - 1 ))
  failed_count=$(( $(wc -l < "$FAILED_CSV" | tr -d ' ') - 1 ))

  cat > "$SUMMARY_FILE" <<EOF
Music Ingest Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run ID:              $RUN_ID
Source Dir:          $SOURCE_DIR
Inbox Dir:           $INBOX_DIR
Dry Run:             $DRY_RUN

Counts
────────────────────────────────────
Source Audio Files:   $source_audio
Eligible Audio Files: $eligible_audio
Moved Files:          $moved_count
Skipped Files:        $skipped_count
Failed Files:         $failed_count
Inbox Audio Count:    $(count_audio_files "$INBOX_DIR")

Artifacts
────────────────────────────────────
Ingested CSV:         $INGESTED_CSV
Skipped CSV:          $SKIPPED_CSV
Failed CSV:           $FAILED_CSV
Log File:             $LOG_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

  cat "$SUMMARY_FILE"

  if [[ "$failed_count" -gt 0 ]]; then
    die "Ingest completed with failed files. Review: $FAILED_CSV"
  fi
}

main
