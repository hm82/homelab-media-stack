#!/usr/bin/env bash
#
# Retag a compilation folder where filenames look like:
#   17. Michael Jackson - Billie Jean.mp3
#
# Sets:
#   Track Number  = 17
#   Artist        = Michael Jackson
#   Title         = Billie Jean
#   Album Artist  = Various Artists
#   Album         = Music 70s 80s 90s
#   Compilation   = 1
#
# Default is dry-run. Use --apply to write changes.

set -euo pipefail

DIR="."
ALBUM="Music 70s 80s 90s"
ALBUM_ARTIST="Various Artists"
DRY_RUN=true
BACKUP=false

usage() {
  cat <<EOF
Usage:
  $0 --dir PATH [options]

Options:
  --dir PATH              Folder containing music files
  --album VALUE           Album name to set
                           Default: "Music 70s 80s 90s"
  --albumartist VALUE     Album Artist to set
                           Default: "Various Artists"
  --apply                 Actually write tags
  --backup                Create .bak files before writing
  -h, --help              Show help

Examples:
  Dry run:
    $0 --dir "/mnt/media/Music/Compilations/Music 7Os8Os9Os"

  Apply:
    $0 --dir "/mnt/media/Music/Compilations/Music 7Os8Os9Os" --apply
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      DIR="${2:-}"
      shift 2
      ;;
    --album)
      ALBUM="${2:-}"
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
  echo "ERROR: kid3-cli not found." >&2
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "ERROR: Directory not found: $DIR" >&2
  exit 1
fi

echo "Directory:     $DIR"
echo "Album:         $ALBUM"
echo "Album Artist:  $ALBUM_ARTIST"
echo "Mode:          $([[ "$DRY_RUN" == true ]] && echo "DRY RUN" || echo "APPLY")"
echo "Backup:        $([[ "$BACKUP" == true ]] && echo "YES" || echo "NO")"
echo

{
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "STATUS" "TRACK" "ARTIST" "TITLE" "FILE"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "------" "-----" "------" "-----" "----"

  find "$DIR" -maxdepth 1 -type f \( \
    -iname "*.mp3" -o \
    -iname "*.flac" -o \
    -iname "*.m4a" -o \
    -iname "*.ogg" -o \
    -iname "*.opus" \
  \) -print0 |
  sort -z |
  while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    name="${base%.*}"

    # Expected:
    #   17. Michael Jackson - Billie Jean
    if [[ "$name" =~ ^([0-9]+)\.\ (.+)\ -\ (.+)$ ]]; then
      track="${BASH_REMATCH[1]}"
      artist="${BASH_REMATCH[2]}"
      title="${BASH_REMATCH[3]}"

      status="WOULD_UPDATE"

      if [[ "$DRY_RUN" == false ]]; then
        if [[ "$BACKUP" == true ]]; then
          cp -p "$file" "$file.bak"
        fi

	if kid3-cli \
	  -c "set tracknumber \"$track\"" \
	  -c "set artist \"$artist\"" \
	  -c "set title \"$title\"" \
	  -c "set album \"$ALBUM\"" \
	  -c "set albumartist \"$ALBUM_ARTIST\"" \
	  -c "set compilation 1" \
	  "$file" >/dev/null 2>&1
	then
	   status="UPDATED"
    	else   
	   status="FAILED"
      	fi
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$status" "$track" "$artist" "$title" "$base"

    else
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "SKIPPED_PARSE_FAIL" "-" "-" "-" "$base"
    fi
  done
} | column -t -s $'\t'

echo
echo "Done."

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run only. Re-run with --apply to write tags."
else
  echo "Tags updated. Now rescan Navidrome."
fi
