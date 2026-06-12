#!/usr/bin/env bash
set -euo pipefail

INCOMING="/mnt/media/Books/_incoming/ebooks"
LIBRARY="/mnt/media/Books/CalibreLibrary"
LOG="/mnt/media/Books/_incoming/import-to-calibre.log"

find "$INCOMING" -type f \( \
  -iname "*.epub" -o \
  -iname "*.pdf" -o \
  -iname "*.mobi" -o \
  -iname "*.azw3" \
\) -print0 | while IFS= read -r -d '' file; do
  echo "$(date '+%F %T') Importing: $file" >> "$LOG"

  if calibredb add "$file" --library-path "$LIBRARY" --duplicates --automerge=overwrite >> "$LOG" 2>&1; then
    echo "$(date '+%F %T') Imported OK: $file" >> "$LOG"
    rm -f "$file"
  else
    echo "$(date '+%F %T') FAILED: $file" >> "$LOG"
  fi
done
