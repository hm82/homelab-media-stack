#!/usr/bin/env zsh
#
# organize_music_library.zsh
#
# Purpose:
#   Organize audio files from music-inbox into a Beets-friendly staging
#   directory using embedded metadata (via ffprobe).
#
# Flow:
#   music-inbox -> music-staging -> beet import -> /mnt/media/Music
#
# Key Design Decisions:
#   - Uses ffprobe (not beet) to read tags directly from files.
#   - Groups by Album Artist / Album.
#   - Falls back:
#       album_artist -> albumartist -> artist -> "Unknown Artist"
#       album        -> "Singles"
#   - Copies sidecar files (cover art, lyrics, PDFs, cue sheets, etc.)
#   - Preserves original files in music-inbox.
#   - Generates detailed audit CSVs.
#
# Usage:
#   organize_music_library.zsh
#   organize_music_library.zsh <source_dir> <dest_dir>
#
# Example:
#   organize_music_library.zsh \
#     /mnt/media/_downloads/music-inbox \
#     /mnt/media/_downloads/music-staging
#

set -uo pipefail

###############################################################################
# Configuration
###############################################################################

SRC="${1:-/mnt/media/_downloads/music-inbox}"
DEST="${2:-/mnt/media/_downloads/music-staging}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"

REPORT_DIR="${RUN_REPORT_DIR:-/mnt/media/_downloads/reports/music-pipeline/$RUN_ID}"
LOG_DIR="${RUN_LOG_DIR:-/mnt/media/_downloads/logs/music-pipeline/$RUN_ID}"

mkdir -p "$DEST" "$REPORT_DIR" "$LOG_DIR"

ORGANIZED_CSV="$REPORT_DIR/organized_files.csv"
SIDECAR_CSV="$REPORT_DIR/sidecar_files.csv"
UNKNOWN_CSV="$REPORT_DIR/unknown_metadata.csv"
LOG_FILE="$LOG_DIR/organize.log"
FAILED_CSV="$REPORT_DIR/failed_files.csv"

###############################################################################
# Supported Extensions
###############################################################################

typeset -a AUDIO_EXTS=(
  flac mp3 m4a aac ogg opus wav alac aiff ape wv
)

typeset -a SIDECAR_EXTS=(
  jpg jpeg png webp gif
  lrc txt cue log nfo pdf
  md5 sfv
)

typeset -a SIDECAR_DIRS=(
  booklet Booklet
  artwork Artwork
  scans Scans
  covers Covers
)

###############################################################################
# Helper Functions
###############################################################################

log() {
  local msg="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

sanitize() {
  echo "$1" \
    | sed 's#[/\\:*?"<>|]#_#g' \
    | sed 's/[[:cntrl:]]//g' \
    | sed 's/[[:space:]]\+/ /g' \
    | sed 's/^ *//;s/ *$//' \
    | sed 's/[. ]*$//' \
    | sed 's/^$/Unknown/'
}

get_tag() {
  local file="$1"
  local tag="$2"
  local value=""

  value="$(ffprobe -v error \
    -show_entries "format_tags=${tag}" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" 2>/dev/null \
    | head -n1 \
    | tr -d '\r')"

  [[ -n "$value" ]] && {
    print -r -- "$value"
    return
  }

  value="$(ffprobe -v error \
    -select_streams a:0 \
    -show_entries "stream_tags=${tag}" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" 2>/dev/null \
    | head -n1 \
    | tr -d '\r')"

  print -r -- "$value"
}

get_album_artist() {
  local file="$1"

  local value=""

  value="$(get_tag "$file" "album_artist")"
  [[ -n "$value" ]] && { echo "$value"; return; }

  value="$(get_tag "$file" "albumartist")"
  [[ -n "$value" ]] && { echo "$value"; return; }

  value="$(get_tag "$file" "ALBUMARTIST")"
  [[ -n "$value" ]] && { echo "$value"; return; }

  value="$(get_tag "$file" "artist")"
  [[ -n "$value" ]] && { echo "$value"; return; }

  echo ""
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

copy_sidecars_from_dir() {
  local src_dir="$1"
  local dest_dir="$2"

  # Copy sidecar files
  for ext in "${SIDECAR_EXTS[@]}"; do
    find "$src_dir" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null |
      while IFS= read -r -d '' file; do
        mkdir -p "$dest_dir"
        cp --update=none "$file" "$dest_dir/" || true

        printf '"%s","%s","%s"\n' \
          "$file" \
          "$dest_dir/$(basename "$file")" \
          "$ext" >> "$SIDECAR_CSV"
      done
  done

  # Copy known sidecar directories
  for d in "${SIDECAR_DIRS[@]}"; do
    if [[ -d "$src_dir/$d" ]]; then
      cp -r --update=none "$src_dir/$d" "$dest_dir/" || true

      printf '"%s","%s","directory"\n' \
        "$src_dir/$d" \
        "$dest_dir/$d" \
        "directory" >> "$SIDECAR_CSV"
    fi
  done
}

###############################################################################
# Validation
###############################################################################

[[ -d "$SRC" ]] || {
  echo "ERROR: Source directory does not exist: $SRC"
  exit 1
}

command -v ffprobe >/dev/null 2>&1 || {
  echo "ERROR: ffprobe not found. Install ffmpeg package."
  exit 1
}

###############################################################################
# Initialize Reports
###############################################################################

echo "source_path,staging_path,artist,albumartist,album" > "$ORGANIZED_CSV"
echo "source_path,staging_path,type" > "$SIDECAR_CSV"
echo "source_path,artist,albumartist,album,reason" > "$UNKNOWN_CSV"
echo "source_path,stage,reason" > "$FAILED_CSV"

###############################################################################
# Prepare Staging Directory
###############################################################################

log "Source: $SRC"
log "Destination: $DEST"
log "Run ID: $RUN_ID"

# Clean staging only (never touch inbox)
rm -rf "$DEST"
mkdir -p "$DEST"

###############################################################################
# Process Audio Files
###############################################################################

AUDIO_COUNT=0
UNKNOWN_COUNT=0

find "$SRC" -type f -print0 |
while IFS= read -r -d '' file; do
  is_audio_file "$file" || continue

  (( AUDIO_COUNT += 1 ))

  # Read tags
  local_artist="$(get_tag "$file" "artist")"
  local_albumartist="$(get_album_artist "$file")"
  local_album="$(get_tag "$file" "album")"
  local_title="$(get_tag "$file" "title")"

 # Read tags
 # local_artist="$(get_tag "$file" "artist")"
 # local_albumartist="$(get_tag "$file" "album_artist")"

 # if [[ -z "$local_albumartist" ]]; then
 #   local_albumartist="$(get_tag "$file" "albumartist")"
 # fi

 # local_album="$(get_tag "$file" "album")"

  # Fallbacks
  [[ -z "$local_albumartist" ]] && local_albumartist="$local_artist"
  [[ -z "$local_albumartist" ]] && local_albumartist="Unknown Artist"
  [[ -z "$local_album" ]] && local_album="Singles"

  # Track missing metadata
  if [[ "$local_albumartist" == "Unknown Artist" ]]; then
    (( UNKNOWN_COUNT += 1 ))

    printf '"%s","%s","%s","%s","missing albumartist/artist"\n' \
      "$file" \
      "$local_artist" \
      "$local_albumartist" \
      "$local_album" >> "$UNKNOWN_CSV"
  fi

  # Sanitize paths
  safe_albumartist="$(sanitize "$local_albumartist")"
  safe_album="$(sanitize "$local_album")"

  dest_dir="$DEST/$safe_albumartist/$safe_album"
  mkdir -p "$dest_dir"

  # Copy audio file
  if ! cp --update=none -- "$file" "$dest_dir/"; then
    log "ERROR: Failed to copy audio file: $file"
    printf '"%s","copy","cp failed"\n' "$file" >> "$FAILED_CSV"
    continue
  fi
  ## cp --update=none "$file" "$dest_dir/"

  # Record mapping
  printf '"%s","%s","%s","%s","%s"\n' \
    "$file" \
    "$dest_dir/$(basename "$file")" \
    "$local_artist" \
    "$local_albumartist" \
    "$local_album" >> "$ORGANIZED_CSV"

  # Copy related artwork/lyrics/booklets
  copy_sidecars_from_dir "$(dirname "$file")" "$dest_dir"

  # log "Grouped: $(basename "$file") -> $safe_albumartist/$safe_album/"
  log "Grouped: $(basename -- "$file" 2>/dev/null || echo '[basename failed]') -> $safe_albumartist/$safe_album/"
done

###############################################################################
# Summary
###############################################################################

log "Organization complete."

TOTAL_ORGANIZED=$(( $(wc -l < "$ORGANIZED_CSV") - 1 ))
TOTAL_SIDECARS=$(( $(wc -l < "$SIDECAR_CSV") - 1 ))
TOTAL_UNKNOWN=$(( $(wc -l < "$UNKNOWN_CSV") - 1 ))

log "Audio files organized: $TOTAL_ORGANIZED"
log "Sidecar files copied:  $TOTAL_SIDECARS"
log "Unknown metadata:      $TOTAL_UNKNOWN"

log "Reports:"
log "  Organized: $ORGANIZED_CSV"
log "  Sidecars:  $SIDECAR_CSV"
log "  Unknowns:  $UNKNOWN_CSV"
log "  Log:       $LOG_FILE"

echo
echo "Organization Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Audio Files Organized: $TOTAL_ORGANIZED"
echo "Sidecar Files Copied:  $TOTAL_SIDECARS"
echo "Unknown Metadata:      $TOTAL_UNKNOWN"
echo "Staging Directory:     $DEST"
echo "Report Directory:      $REPORT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
