#!/usr/bin/env bash
#
# summarize_album_artists.sh
#
# Summarizes Album Artist values across all audio files in a folder.
#
# Useful for checking compilation albums. A clean compilation should usually show:
#   COUNT  ALBUM_ARTIST
#   -----  ----------------
#   100    Various Artists
#
# Usage:
#   ./summarize_album_artists.sh "/path/to/music/folder"
#

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $0 [MUSIC_FOLDER]

Description:
  Counts unique Album Artist tag values in a music folder.

Arguments:
  MUSIC_FOLDER   Folder to scan. Defaults to current directory.

Examples:
  $0 .
  $0 "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)"
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

DIR="${1:-.}"

if ! command -v kid3-cli >/dev/null 2>&1; then
  echo "ERROR: kid3-cli not found. Install Kid3 CLI first." >&2
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "ERROR: Not a directory: $DIR" >&2
  exit 1
fi

echo "Directory: $DIR"
echo

{
  printf "%s\t%s\n" "COUNT" "ALBUM_ARTIST"
  printf "%s\t%s\n" "-----" "------------"

  find "$DIR" -type f \( \
    -iname "*.mp3" -o \
    -iname "*.flac" -o \
    -iname "*.m4a" -o \
    -iname "*.ogg" -o \
    -iname "*.opus" \
  \) -print0 |
  while IFS= read -r -d '' file; do
    kid3-cli -c 'get albumartist' "$file" 2>/dev/null || true
  done |
  sed '/^$/d' |
  sort |
  uniq -c |
  sort -nr |
  awk '{count=$1; $1=""; sub(/^ /,""); print count "\t" $0}'
} | column -t -s $'\t'
