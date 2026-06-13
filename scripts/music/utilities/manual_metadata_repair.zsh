#!/usr/bin/env zsh
#
# manual_metadata_repair.zsh
#
# Purpose:
#   Infer missing music metadata from filename/folder structure and optionally
#   write tags before organize/import.
#
# Modes:
#   report   Generate candidate repair report only. Default.
#   apply    Apply only candidates >= MIN_CONFIDENCE.
#
# Usage:
#   manual_metadata_repair.zsh report
#   manual_metadata_repair.zsh apply
#
# Env:
#   SOURCE_DIR=/mnt/media/_downloads/music-inbox
#   MIN_CONFIDENCE=90
#   OVERWRITE_TAGS=false
#

set -uo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/common.zsh"

MODE="${1:-report}"
SOURCE_DIR="${SOURCE_DIR:-$INBOX_DIR}"
MIN_CONFIDENCE="${MIN_CONFIDENCE:-90}"
OVERWRITE_TAGS="${OVERWRITE_TAGS:-false}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
REPORT_DIR="${RUN_REPORT_DIR:-/mnt/media/_downloads/reports/music-pipeline/$RUN_ID}"
LOG_DIR="${RUN_LOG_DIR:-/mnt/media/_downloads/logs/music-pipeline/$RUN_ID}"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/metadata-repair.log"
CANDIDATES_CSV="$REPORT_DIR/metadata_repair_candidates.csv"
APPLIED_CSV="$REPORT_DIR/metadata_repair_applied.csv"
FAILED_CSV="$REPORT_DIR/metadata_repair_failed.csv"
SUMMARY_FILE="$REPORT_DIR/metadata-repair-summary.txt"

AUDIO_EXPR=(-iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav")

log() {
  print "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

csv_escape() {
  local v="${1:-}"
  v="${v//\"/\"\"}"
  print -r -- "\"$v\""
}

csv_row() {
  local out="" first=true field
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

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

clean_text() {
  local s="${1:-}"

  s="${s:r}"                                      # strip extension-like suffix if present
  s="${s//｜/|}"                                  # normalize fullwidth separator
  s="$(print -r -- "$s" | sed -E 's/_[0-9]{12,}$//')"
  s="$(print -r -- "$s" | sed -E 's/^[0-9]{1,4}[.) -]+//')"
  s="$(print -r -- "$s" | sed -E 's/\[[^]]+\]//g')"
  s="$(print -r -- "$s" | sed -E 's/\([0-9]+\)$//g')"
  s="$(print -r -- "$s" | sed -E 's/[[:space:]]+/ /g')"
  s="$(trim "$s")"

  print -r -- "$s"
}

get_tag() {
  local file="$1"
  local tag="$2"

  ffprobe -v error \
    -show_entries "format_tags=$tag" \
    -of default=nw=1:nk=1 \
    "$file" 2>/dev/null | head -n1
}

is_missing_or_unknown() {
  local v="${1:-}"
  [[ -z "$v" ]] && return 0
  [[ "${v:l}" == "unknown" ]] && return 0
  [[ "${v:l}" == "unknown artist" ]] && return 0
  [[ "${v:l}" == "unknown album" ]] && return 0
  [[ "${v:l}" == "none" ]] && return 0
  return 1
}

needs_repair() {
  local artist="$1"
  local album="$2"
  local title="$3"
  local file="${4:-}"

  [[ "$OVERWRITE_TAGS" == "true" ]] && return 0

  is_missing_or_unknown "$artist" && return 0
  is_missing_or_unknown "$album" && return 0
  # Title-only files still need repair because artist/album are missing.
  is_missing_or_unknown "$title" && return 0

  return 1
}

infer_metadata() {
  local file="$1"
  local base parent clean
  local artist="" albumartist="" album="" title="" rule="" confidence=0

  base="$(basename -- "$file")"
  parent="$(basename -- "$(dirname -- "$file")")"
  clean="$(clean_text "$base")"

  # Rule: Coke Studio with pipe separators
  if [[ "$file" == *"/Coke_Studio/"* || "$clean" == *"Coke Studio"* ]]; then
    local norm parts season part_title part_artist
    norm="${clean//｜/|}"
    norm="${norm// - /|}"

    if [[ "$norm" == *"Season "* ]]; then
      season="$(print -r -- "$norm" | grep -oE 'Season [0-9]+' | head -n1)"
      album="Coke Studio ${season}"
    else
      album="Coke Studio"
    fi

    albumartist="Coke Studio Pakistan"

    IFS='|' read -r -A parts <<< "$norm"
    if (( ${#parts[@]} >= 3 )); then
      part_title="$(trim "${parts[2]}")"
      part_artist="$(trim "${parts[3]:-${parts[1]}}")"
      title="$(clean_text "$part_title")"
      artist="$(clean_text "$part_artist")"
      rule="coke-studio"
      confidence=96
    else
      artist="Coke Studio Pakistan"
      title="$clean"
      rule="coke-studio-fallback"
      confidence=75
    fi
  fi

  # Rule: legacy numbered "001) Artist - Title"
  if [[ -z "$rule" && "$clean" == *" - "* ]]; then
    local left right
    left="${clean%% - *}"
    right="${clean#* - }"

    # Strip leading track numbers again from left if present
    left="$(print -r -- "$left" | sed -E 's/^[0-9]{1,4}[.) -]+//')"
    left="$(clean_text "$left")"
    right="$(clean_text "$right")"

    if [[ -n "$left" && -n "$right" ]]; then
      artist="$left"
      albumartist="$left"
      album="Singles"
      title="$right"
      rule="artist-title"
      confidence=92
    fi
  fi

  # Rule: triple dash "Artist - Artist2 - Title"
  if [[ "$rule" == "artist-title" && "$clean" == *" - "*" - "* ]]; then
    local p1 p2 p3
    p1="${clean%% - *}"
    local rest="${clean#* - }"
    p2="${rest%% - *}"
    p3="${rest#* - }"

    if [[ -n "$p1" && -n "$p2" && -n "$p3" && "$p2" != "$p3" ]]; then
      artist="$(clean_text "$p1 & $p2")"
      albumartist="$artist"
      title="$(clean_text "$p3")"
      album="Singles"
      rule="artist-artist-title"
      confidence=88
    fi
  fi

  # Rule: folder-derived album/title
  if [[ -z "$rule" ]]; then
    title="$(clean_text "$clean")"
    album="$(clean_text "$parent")"

    if [[ "$album" == "music-inbox" || "$album" == "Unknown Artist" || "$album" == "Singles" ]]; then
      album="Singles"
      confidence=55
    else
      confidence=65
    fi

    artist="Unknown Artist"
    albumartist="Unknown Artist"
    rule="folder-title"
  fi

  csv_row "$file" "$artist" "$albumartist" "$album" "$title" "$rule" "$confidence"
}

write_headers() {
  echo "source_path,inferred_artist,inferred_albumartist,inferred_album,inferred_title,rule,confidence,current_artist,current_albumartist,current_album,current_title,action" > "$CANDIDATES_CSV"
  echo "source_path,artist,albumartist,album,title,rule,confidence,status" > "$APPLIED_CSV"
  echo "source_path,reason" > "$FAILED_CSV"
}

apply_tags() {
  local file="$1"
  local artist="$2"
  local albumartist="$3"
  local album="$4"
  local title="$5"

  if command -v kid3-cli >/dev/null 2>&1; then
    kid3-cli \
      -c "set artist \"$artist\"" \
      -c "set albumartist \"$albumartist\"" \
      -c "set album \"$album\"" \
      -c "set title \"$title\"" \
      "$file" >/dev/null 2>&1
    return $?
  fi

  # No safe fallback enabled for now because ffmpeg rewrites files.
  return 99
}

main() {
  [[ "$MODE" == "report" || "$MODE" == "apply" ]] || {
    echo "Usage: $0 [report|apply]"
    exit 1
  }

  [[ -d "$SOURCE_DIR" ]] || {
    log "ERROR: Source directory not found: $SOURCE_DIR"
    exit 1
  }

  write_headers

  log "Metadata repair mode: $MODE"
  log "Source: $SOURCE_DIR"
  log "Run ID: $RUN_ID"
  log "Min confidence: $MIN_CONFIDENCE"
  log "Overwrite tags: $OVERWRITE_TAGS"

  local scanned=0 candidates=0 applied=0 failed=0 skipped=0

  while IFS= read -r file; do
    (( scanned++ ))

    local cur_artist cur_albumartist cur_album cur_title
    cur_artist="$(get_tag "$file" "artist" || true)"
    cur_albumartist="$(get_tag "$file" "album_artist" || true)"
    [[ -z "$cur_albumartist" ]] && cur_albumartist="$(get_tag "$file" "albumartist" || true)"
    cur_album="$(get_tag "$file" "album" || true)"
    cur_title="$(get_tag "$file" "title" || true)"

    if ! needs_repair "$cur_artist" "$cur_album" "$cur_title" "$file"; then
      (( skipped++ ))
      continue
    fi

    local inferred line inf_artist inf_albumartist inf_album inf_title rule confidence
    inferred="$(infer_metadata "$file")"

    # Parse CSV-ish safely enough because our csv fields are quoted; use python would be cleaner,
    # but keeping this shell-native for your current pipeline.
    inf_artist="$(print -r -- "$inferred" | awk -F'","' '{gsub(/^"/,"",$2); print $2}')"
    inf_albumartist="$(print -r -- "$inferred" | awk -F'","' '{print $3}')"
    inf_album="$(print -r -- "$inferred" | awk -F'","' '{print $4}')"
    inf_title="$(print -r -- "$inferred" | awk -F'","' '{print $5}')"
    rule="$(print -r -- "$inferred" | awk -F'","' '{print $6}')"
    confidence="$(print -r -- "$inferred" | awk -F'","' '{gsub(/"$/,"",$7); print $7}')"

    (( candidates++ ))

    local action="report-only"
    if [[ "$MODE" == "apply" && "$confidence" -ge "$MIN_CONFIDENCE" ]]; then
      if apply_tags "$file" "$inf_artist" "$inf_albumartist" "$inf_album" "$inf_title"; then
        action="applied"
        (( applied++ ))
        csv_row "$file" "$inf_artist" "$inf_albumartist" "$inf_album" "$inf_title" "$rule" "$confidence" "applied" >> "$APPLIED_CSV"
      else
        action="failed"
        (( failed++ ))
        csv_row "$file" "tag write failed; install kid3-cli or run report mode" >> "$FAILED_CSV"
      fi
    fi

    csv_row "$file" "$inf_artist" "$inf_albumartist" "$inf_album" "$inf_title" "$rule" "$confidence" "$cur_artist" "$cur_albumartist" "$cur_album" "$cur_title" "$action" >> "$CANDIDATES_CSV"

  done < <(find "$SOURCE_DIR" -type f \( "${AUDIO_EXPR[@]}" \) 2>/dev/null)

  cat > "$SUMMARY_FILE" <<EOF
Metadata Repair Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run ID:              $RUN_ID
Mode:                $MODE
Source Dir:          $SOURCE_DIR
Min Confidence:      $MIN_CONFIDENCE
Overwrite Tags:      $OVERWRITE_TAGS

Counts
────────────────────────────────────
Scanned Files:        $scanned
Skipped Good Tags:    $skipped
Candidates:           $candidates
Applied:              $applied
Failed:               $failed

Artifacts
────────────────────────────────────
Candidates CSV:       $CANDIDATES_CSV
Applied CSV:          $APPLIED_CSV
Failed CSV:           $FAILED_CSV
Log File:             $LOG_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

  cat "$SUMMARY_FILE"

  [[ "$failed" -gt 0 ]] && exit 2
}

main
