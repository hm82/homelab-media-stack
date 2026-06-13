#!/usr/bin/env zsh
#
# 01_analyze_music.zsh
#
# Analyze a music/source/inbox directory before or after pipeline runs.
#
# Usage:
#   01_analyze_music.zsh /path/to/music-dir
#
# Example:
#   01_analyze_music.zsh /mnt/media/_downloads/music-inbox
#

set -euo pipefail

###############################################################################
# Config
###############################################################################

INPUT_DIR="${1:-}"

if [[ -z "$INPUT_DIR" ]]; then
  echo "Usage: $0 /path/to/music-dir"
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "ERROR: Directory not found: $INPUT_DIR"
  exit 1
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
REPORT_ROOT="/mnt/media/_downloads/reports/music-analysis"
REPORT_DIR="$REPORT_ROOT/$RUN_ID"

mkdir -p "$REPORT_DIR"

SUMMARY="$REPORT_DIR/analysis-summary.txt"
FILE_TYPES="$REPORT_DIR/file-types.csv"
LARGEST_FILES="$REPORT_DIR/largest-files.csv"
AUDIO_FILES="$REPORT_DIR/audio-files.txt"
SIDECAR_FILES="$REPORT_DIR/sidecar-files.txt"
VIDEO_FILES="$REPORT_DIR/video-files.txt"
EMPTY_DIRS="$REPORT_DIR/empty-dirs.txt"

###############################################################################
# Helpers
###############################################################################

count_files_by_ext() {
  find "$INPUT_DIR" -type f \
    | awk '
      function lower(s){ return tolower(s) }
      {
        n=split($0,a,".")
        if (n > 1) ext=lower(a[n]); else ext="no_extension"
        count[ext]++
      }
      END {
        for (ext in count) print ext "," count[ext]
      }
    ' \
    | sort
}

count_audio_ext() {
  local ext="$1"

  awk -v ext="$ext" '
    BEGIN { count=0 }
    {
      file=tolower($0)
      if (file ~ "\\." ext "$") count++
    }
    END { print count }
  ' "$AUDIO_FILES"
}

count_matching_files() {
  find "$INPUT_DIR" -type f "$@" | wc -l | tr -d ' '
}

human_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

###############################################################################
# File Lists
###############################################################################

find "$INPUT_DIR" -type f \
  \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.opus" -o -iname "*.ogg" -o -iname "*.wav" -o -iname "*.aac" -o -iname "*.alac" \) \
  | sort > "$AUDIO_FILES"

find "$INPUT_DIR" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.lrc" -o -iname "*.cue" -o -iname "*.log" -o -iname "*.nfo" -o -iname "*.txt" -o -iname "*.pdf" -o -iname "*.md5" -o -iname "*.sfv" \) \
  | sort > "$SIDECAR_FILES"

find "$INPUT_DIR" -type f \
  \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.avi" \) \
  | sort > "$VIDEO_FILES"

find "$INPUT_DIR" -type d -empty \
  | sort > "$EMPTY_DIRS"

###############################################################################
# CSV Reports
###############################################################################

{
  echo "extension,count"
  count_files_by_ext
} > "$FILE_TYPES"

{
  echo "size_bytes,path"
  find "$INPUT_DIR" -type f -printf "%s,%p\n" \
    | sort -nr \
    | head -50
} > "$LARGEST_FILES"

###############################################################################
# Metrics
###############################################################################

TOTAL_FILES=$(find "$INPUT_DIR" -type f | wc -l | tr -d ' ')
TOTAL_DIRS=$(find "$INPUT_DIR" -type d | wc -l | tr -d ' ')
EMPTY_DIR_COUNT=$(wc -l < "$EMPTY_DIRS" | tr -d ' ')
AUDIO_COUNT=$(wc -l < "$AUDIO_FILES" | tr -d ' ')
SIDECAR_COUNT=$(wc -l < "$SIDECAR_FILES" | tr -d ' ')
VIDEO_COUNT=$(wc -l < "$VIDEO_FILES" | tr -d ' ')
DIR_SIZE=$(human_size "$INPUT_DIR")

FLAC_COUNT="$(count_audio_ext flac)"
MP3_COUNT="$(count_audio_ext mp3)"
M4A_COUNT="$(count_audio_ext m4a)"
OPUS_COUNT="$(count_audio_ext opus)"
OGG_COUNT="$(count_audio_ext ogg)"
WAV_COUNT="$(count_audio_ext wav)"
AAC_COUNT="$(count_audio_ext aac)"
ALAC_COUNT="$(count_audio_ext alac)"

###############################################################################
# Summary Report
###############################################################################

cat > "$SUMMARY" <<EOF
Music Directory Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run ID:          $RUN_ID
Input Dir:       $INPUT_DIR
Report Dir:      $REPORT_DIR

Directory Metrics
────────────────────────────────────
Total Size:      $DIR_SIZE
Total Files:     $TOTAL_FILES
Total Dirs:      $TOTAL_DIRS
Empty Dirs:      $EMPTY_DIR_COUNT

Music Files
────────────────────────────────────
Audio Files:     $AUDIO_COUNT
FLAC:            $FLAC_COUNT
MP3:             $MP3_COUNT
M4A:             $M4A_COUNT
OPUS:            $OPUS_COUNT
OGG:             $OGG_COUNT
WAV:             $WAV_COUNT
AAC:             $AAC_COUNT
ALAC:            $ALAC_COUNT

Support Files
────────────────────────────────────
Sidecar Files:   $SIDECAR_COUNT
Video Files:     $VIDEO_COUNT

Reports
────────────────────────────────────
File Types:      $FILE_TYPES
Largest Files:   $LARGEST_FILES
Audio List:      $AUDIO_FILES
Sidecar List:    $SIDECAR_FILES
Video List:      $VIDEO_FILES
Empty Dirs:      $EMPTY_DIRS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

cat "$SUMMARY"

echo
echo "Top file types:"
if command -v column >/dev/null 2>&1; then
  column -s, -t "$FILE_TYPES" | head -30
else
  head -30 "$FILE_TYPES"
fi

echo
echo "Largest files:"
tail -n +2 "$LARGEST_FILES" \
  | head -10 \
  | awk -F, '{ printf "%10.2f MB  %s\n", $1/1024/1024, $2 }'

echo
echo "Saved report:"
echo "  $SUMMARY"
