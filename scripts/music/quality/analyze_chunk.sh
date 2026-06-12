#!/usr/bin/env bash
set -euo pipefail

CHUNK_DIR="$1"
REPORT="$2"
CSV="$3"

echo "Chunk Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Chunk Dir: $CHUNK_DIR"
echo "Report:    $REPORT"
echo "CSV:       $CSV"
echo ""

echo "Downloaded audio files:"
find "$CHUNK_DIR" -type f \( -iname "*.m4a" -o -iname "*.mp3" \) | wc -l
echo ""

echo "Temporary files:"
find "$CHUNK_DIR" -type f -name "*.temp.*" -o -name "*.part" -o -name "*.temp.m4a" | wc -l
echo ""

echo "Disk usage:"
du -sh "$CHUNK_DIR"
echo ""

echo "Report summary:"
awk -F',' '
$1 ~ /^OK/ {ok++}
$1 ~ /^FAILED/ {failed++}
END {
  print "OK:     " ok+0
  print "FAILED: " failed+0
}
' "$REPORT"
echo ""

echo "Failed tracks:"
awk -F',' '$1 ~ /^FAILED/ {print "- " $2 " — " $3}' "$REPORT"
echo ""

echo "Top 20 artists downloaded:"
find "$CHUNK_DIR" -type f \( -iname "*.m4a" -o -iname "*.mp3" \) \
  -printf '%f\n' |
sed 's/ - .*//' |
sort |
uniq -c |
sort -nr |
head -20
echo ""

echo "Largest 10 files:"
find "$CHUNK_DIR" -type f \( -iname "*.m4a" -o -iname "*.mp3" \) \
  -printf '%s\t%f\n' |
sort -nr |
head -10 |
awk '{
  printf "%8.2f MB  %s\n", $1/1024/1024, substr($0, index($0,$2))
}'
