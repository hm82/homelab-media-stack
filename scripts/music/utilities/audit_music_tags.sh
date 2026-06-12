#!/usr/bin/env bash
#
# audit_music_tags.sh
#
# Shows key music metadata for every audio file in a folder:
# file path, artist, album artist, and album.
#
# Usage:
#   ./audit_music_tags.sh "/path/to/music/folder"
#
# Example:
#   ./audit_music_tags.sh "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)"
#

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $0 [MUSIC_FOLDER]

Description:
  Audits music metadata using kid3-cli and displays:
    - File path
    - Artist
    - Album Artist
    - Album

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

{
  printf '%s\t%s\t%s\t%s\n' \
    "FILE" \
    "ARTIST" \
    "ALBUM_ARTIST" \
    "ALBUM"

  find "$DIR" -type f \( \
    -iname "*.mp3" -o \
    -iname "*.flac" -o \
    -iname "*.m4a" -o \
    -iname "*.ogg" -o \
    -iname "*.opus" \
  \) -print0 |
  while IFS= read -r -d '' file; do
    artist="$(kid3-cli -c 'get artist' "$file" 2>/dev/null || true)"
    albumartist="$(kid3-cli -c 'get albumartist' "$file" 2>/dev/null || true)"
    album="$(kid3-cli -c 'get album' "$file" 2>/dev/null || true)"

    printf '%s\t%s\t%s\t%s\n' \
      "$file" \
      "$artist" \
      "$albumartist" \
      "$album"
  done
} | column -t -s $'\t'
