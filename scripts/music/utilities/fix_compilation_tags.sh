#!/usr/bin/env bash
#
# fix_compilation_tags.sh
#
# Fixes compilation album metadata by setting Album Artist across all audio files
# in a folder, usually to:
#
#   Various Artists
#
# This helps Navidrome, Amperfy, Symfonium, Plexamp, etc. group compilation
# tracks into one album instead of splitting them by track artist.
#
# Default behavior:
#   - Dry run only
#   - No files modified unless --apply is passed
#
# Usage:
#   ./fix_compilation_tags.sh --dir "/path/to/album"
#   ./fix_compilation_tags.sh --dir "/path/to/album" --apply
#
# Example:
#   ./fix_compilation_tags.sh \
#     --dir "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)" \
#     --apply
#

set -euo pipefail

DIR=""
ALBUM_ARTIST="Various Artists"
DRY_RUN=true
BACKUP=false
RECURSIVE=true

usage() {
  cat <<EOF
Usage:
  $0 --dir PATH [options]

Description:
  Sets Album Artist tags for audio files in a folder.

  This is useful for compilation albums where each track has a different Artist,
  but the album should have one shared Album Artist, usually "Various Artists".

Options:
  --dir PATH
      Folder containing music files.

  --albumartist VALUE
      Album Artist value to set.
      Default: "Various Artists"

  --apply
      Actually write changes.
      Without this flag, the script only previews changes.

  --backup
      Create .bak copies before modifying files.
      Only applies when --apply is used.

  --no-recursive
      Only scan files directly inside the target folder.

  -h, --help
      Show this help message.

Examples:
  Dry run:
    $0 --dir "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)"

  Apply changes:
    $0 --dir "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)" --apply

  Apply with backups:
    $0 --dir "/mnt/media/Music/Compilations/VA - 100 Greatest Guitar Solos (2020)" --apply --backup

  Use custom Album Artist:
    $0 --dir "/path/to/album" --albumartist "VA" --apply
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      DIR="${2:-}"
      shift 2
      ;;
    --albumartist)
      ALBUM_ARTIST="${2:-}"
      shift 2
      ;;
    --apply)
      DRY_RUN=false
      shift
      ;;
    --backup)
      BACKUP=true
      shift
      ;;
    --no-recursive)
      RECURSIVE=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v kid3-cli >/dev/null 2>&1; then
  echo "ERROR: kid3-cli not found. Install Kid3 CLI first." >&2
  exit 1
fi

if ! command -v column >/dev/null 2>&1; then
  echo "ERROR: column command not found. Install util-linux." >&2
  exit 1
fi

if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "ERROR: Valid --dir PATH is required." >&2
  usage
  exit 1
fi

if [[ -z "$ALBUM_ARTIST" ]]; then
  echo "ERROR: --albumartist cannot be empty." >&2
  exit 1
fi

echo "Directory:     $DIR"
echo "Album Artist:  $ALBUM_ARTIST"
echo "Mode:          $([[ "$DRY_RUN" == true ]] && echo "DRY RUN" || echo "APPLY")"
echo "Backup:        $([[ "$BACKUP" == true ]] && echo "YES" || echo "NO")"
echo "Recursive:     $([[ "$RECURSIVE" == true ]] && echo "YES" || echo "NO")"
echo

if [[ "$RECURSIVE" == true ]]; then
  FIND_DEPTH_ARGS=()
else
  FIND_DEPTH_ARGS=(-maxdepth 1)
fi

TMP_REPORT="$(mktemp)"
trap 'rm -f "$TMP_REPORT"' EXIT

total=0
changed=0
unchanged=0
failed=0

while IFS= read -r -d '' file; do
  total=$((total + 1))

  current="$(kid3-cli -c 'get albumartist' "$file" 2>/dev/null || true)"
  artist="$(kid3-cli -c 'get artist' "$file" 2>/dev/null || true)"
  album="$(kid3-cli -c 'get album' "$file" 2>/dev/null || true)"

  if [[ "$current" == "$ALBUM_ARTIST" ]]; then
    unchanged=$((unchanged + 1))
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "UNCHANGED" "$file" "$artist" "$current" "$album" >> "$TMP_REPORT"
    continue
  fi

  if [[ "$DRY_RUN" == true ]]; then
    changed=$((changed + 1))
    printf '%s\t%s\t%s\t%s -> %s\t%s\n' \
      "WOULD_UPDATE" "$file" "$artist" "${current:-<blank>}" "$ALBUM_ARTIST" "$album" >> "$TMP_REPORT"
    continue
  fi

  if [[ "$BACKUP" == true ]]; then
    cp -p "$file" "$file.bak"
  fi

  if kid3-cli \
      -c "set albumartist '$ALBUM_ARTIST'" \
      -c "set compilation 1" \
      "$file" >/dev/null 2>&1; then
    changed=$((changed + 1))
    printf '%s\t%s\t%s\t%s -> %s\t%s\n' \
      "UPDATED" "$file" "$artist" "${current:-<blank>}" "$ALBUM_ARTIST" "$album" >> "$TMP_REPORT"
  else
    failed=$((failed + 1))
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "FAILED" "$file" "$artist" "${current:-<blank>}" "$album" >> "$TMP_REPORT"
  fi

done < <(
  find "$DIR" "${FIND_DEPTH_ARGS[@]}" -type f \( \
    -iname "*.mp3" -o \
    -iname "*.flac" -o \
    -iname "*.m4a" -o \
    -iname "*.ogg" -o \
    -iname "*.opus" \
  \) -print0
)

{
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "STATUS" "FILE" "ARTIST" "ALBUM_ARTIST_CHANGE" "ALBUM"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "------" "----" "------" "-------------------" "-----"
  cat "$TMP_REPORT"
} | column -t -s $'\t'

echo
echo "Summary:"
echo "  Total audio files: $total"
echo "  Changed/planned:   $changed"
echo "  Unchanged:         $unchanged"
echo "  Failed:            $failed"

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run complete. Re-run with --apply to write changes."
else
  echo "Apply complete. Recommended next step:"
  echo "  Run your album artist summary script, then rescan Navidrome."
fi
