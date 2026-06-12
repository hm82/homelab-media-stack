#!/usr/bin/env bash
set -euo pipefail

SOURCE="/mnt/media/Books/Ebooks"
LIB="/mnt/media/Books/CalibreLibrary"
LOG="/mnt/media/Books/import-to-calibre.log"

# Formats to import. Keep PDF out unless you really want PDFs in Calibre.
FORMATS=("*.epub" "*.azw3" "*.mobi")

echo "==== $(date '+%F %T') Starting Calibre import ====" >> "$LOG"

find_args=()
for fmt in "${FORMATS[@]}"; do
  find_args+=( -iname "$fmt" -o )
done
unset 'find_args[${#find_args[@]}-1]'

find "$SOURCE" -type f \( "${find_args[@]}" \) -print0 |
while IFS= read -r -d '' file; do
  echo "$(date '+%F %T') Checking: $file" >> "$LOG"

  # Try import without allowing duplicates.
  # Calibre will reject likely duplicates.
  if calibredb add "$file" --library-path "$LIB" >> "$LOG" 2>&1; then
    echo "$(date '+%F %T') Imported OK: $file" >> "$LOG"
    rm -f "$file"
  else
    echo "$(date '+%F %T') Skipped or failed, leaving file in place: $file" >> "$LOG"
  fi
done

# Clean empty folders after successful imports
find "$SOURCE" -type d -empty -delete

echo "==== $(date '+%F %T') Import complete ====" >> "$LOG"
