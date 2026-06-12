#!/usr/bin/env zsh
set -euo pipefail

MEDIA_ROOT="${1:-/mnt/media}"
REPORT_ROOT="${REPORT_ROOT:-$MEDIA_ROOT/_downloads/reports/storage-management}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="$REPORT_ROOT/$RUN_ID"

LARGE_MB="${LARGE_MB:-1500}"
OLD_DAYS="${OLD_DAYS:-45}"

mkdir -p "$REPORT_DIR"

SUMMARY="$REPORT_DIR/summary.txt"
LARGE_FILES="$REPORT_DIR/large-files.tsv"
DIR_SIZES="$REPORT_DIR/directory-sizes.txt"
CLEANUP_CANDIDATES="$REPORT_DIR/cleanup-candidates.tsv"
INCOMPLETE_FILES="$REPORT_DIR/incomplete-files.tsv"
TRASH_FILES="$REPORT_DIR/trash-recycle-files.tsv"
VIDEO_FILES="$REPORT_DIR/video-files.tsv"
RECOMMENDATIONS="$REPORT_DIR/recommendations.txt"
DELETE_SCRIPT="$REPORT_DIR/review-delete-candidates.sh"

section() {
  print "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print "$1"
  print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || print "WARN: Missing command: $1"
}

human() {
  numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"
}

is_video_ext() {
  case "${1:l}" in
    mp4|mkv|avi|mov|m4v|wmv|webm|ts) return 0 ;;
    *) return 1 ;;
  esac
}

need_cmd find
need_cmd du
need_cmd awk
need_cmd numfmt

section "Media Storage Audit"
print "Media root:       $MEDIA_ROOT"
print "Report dir:       $REPORT_DIR"
print "Large file min:   ${LARGE_MB}MB"
print "Old file age:     ${OLD_DAYS} days"

section "Filesystem Summary"
df -h "$MEDIA_ROOT" | tee "$REPORT_DIR/filesystem.txt"

section "Top Directory Sizes"
du -h --max-depth=1 "$MEDIA_ROOT" 2>/dev/null | sort -hr | tee "$DIR_SIZES"

section "Large Files"
{
  print "size_bytes\tsize_human\tmodified\tpath"
  find "$MEDIA_ROOT" -type f -size +"${LARGE_MB}"M \
    ! -path "*/config/*" \
    -printf '%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' 2>/dev/null |
    sort -nr |
    while IFS=$'\t' read -r size modified path; do
      print "${size}\t$(human "$size")\t${modified}\t${path}"
    done
} | tee "$LARGE_FILES" >/dev/null

section "Video Inventory"
{
  print "size_bytes\tsize_human\tmodified\text\tpath"
  find "$MEDIA_ROOT/Movies" "$MEDIA_ROOT/TV" -type f 2>/dev/null |
    while IFS= read -r f; do
      ext="${f##*.}"
      if is_video_ext "$ext"; then
        size="$(stat -c '%s' "$f" 2>/dev/null || echo 0)"
        modified="$(stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1 || echo '')"
        print "${size}\t$(human "$size")\t${modified}\t${ext:l}\t${f}"
      fi
    done | sort -nr
} | tee "$VIDEO_FILES" >/dev/null

section "Incomplete / Download Debris"
{
  print "size_bytes\tsize_human\tmodified\tpath"
  find "$MEDIA_ROOT/_incomplete" "$MEDIA_ROOT/_downloads" "$MEDIA_ROOT/_imports" -type f 2>/dev/null \
    -printf '%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' |
    sort -nr |
    while IFS=$'\t' read -r size modified path; do
      print "${size}\t$(human "$size")\t${modified}\t${path}"
    done
} | tee "$INCOMPLETE_FILES" >/dev/null

section "Trash / Recycle Bin"
{
  print "size_bytes\tsize_human\tmodified\tpath"
  find "$MEDIA_ROOT/.Trash-1000" "$MEDIA_ROOT/\$RECYCLE.BIN" "$MEDIA_ROOT/System Volume Information" -type f 2>/dev/null \
    -printf '%s\t%TY-%Tm-%Td %TH:%TM\t%p\n' |
    sort -nr |
    while IFS=$'\t' read -r size modified path; do
      print "${size}\t$(human "$size")\t${modified}\t${path}"
    done
} | tee "$TRASH_FILES" >/dev/null

section "Cleanup Candidates"
{
  print "reason\tsize_bytes\tsize_human\tmodified\tpath"

  find "$MEDIA_ROOT/_incomplete" -type f -mtime +"$OLD_DAYS" 2>/dev/null \
    -printf 'old_incomplete\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n'

  find "$MEDIA_ROOT/_downloads" -type f -mtime +"$OLD_DAYS" 2>/dev/null \
    ! -path "*/music-imported/*" \
    -printf 'old_download\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n'

  find "$MEDIA_ROOT/.Trash-1000" "$MEDIA_ROOT/\$RECYCLE.BIN" -type f 2>/dev/null \
    -printf 'trash_or_recycle\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n'

  find "$MEDIA_ROOT/Movies" "$MEDIA_ROOT/TV" -type f -size +"${LARGE_MB}"M -mtime +"$OLD_DAYS" 2>/dev/null \
    -printf 'large_old_video_review\t%s\t%TY-%Tm-%Td %TH:%TM\t%p\n'
} |
sort -k2,2nr |
while IFS=$'\t' read -r reason size modified path; do
  [[ "$reason" == "reason" ]] && continue
  print "${reason}\t${size}\t$(human "$size")\t${modified}\t${path}"
done | {
  print "reason\tsize_bytes\tsize_human\tmodified\tpath"
  cat
} | tee "$CLEANUP_CANDIDATES" >/dev/null

section "Generate Review Delete Script"
{
  print "#!/usr/bin/env bash"
  print "set -euo pipefail"
  print ""
  print "# REVIEW CAREFULLY BEFORE RUNNING."
  print "# This file is generated from cleanup candidates."
  print "# Nothing is deleted unless you manually run this script."
  print ""
  tail -n +2 "$CLEANUP_CANDIDATES" |
    awk -F'\t' '{gsub(/\047/, "'\''\\'\'''\''", $5); print "# " $1 " | " $3 " | " $4 "\nrm -iv -- '\''" $5 "'\''"}'
} > "$DELETE_SCRIPT"

chmod +x "$DELETE_SCRIPT"

section "Recommendations"
{
  print "Recommended cleanup order:"
  print "1. Empty recycle/trash folders first."
  print "2. Review old files in _incomplete and _downloads."
  print "3. Review large old videos in Movies/TV."
  print "4. Keep Music/Books/Comics unless intentionally pruning."
  print "5. Do not delete config unless you have backups."
  print ""
  print "Jellyfin optimization guidance:"
  print "- Prefer removing watched high-size TV episodes first."
  print "- Keep active/current shows."
  print "- Remove duplicate 4K/1080p versions if only one is needed."
  print "- Avoid storing downloads and final library copies long-term."
  print ""
  print "Report files:"
  print "- Summary:              $SUMMARY"
  print "- Directory sizes:      $DIR_SIZES"
  print "- Large files:          $LARGE_FILES"
  print "- Video inventory:      $VIDEO_FILES"
  print "- Incomplete files:     $INCOMPLETE_FILES"
  print "- Trash/recycle files:  $TRASH_FILES"
  print "- Cleanup candidates:   $CLEANUP_CANDIDATES"
  print "- Review delete script: $DELETE_SCRIPT"
} | tee "$RECOMMENDATIONS"

section "Summary"
{
  print "Media Storage Audit Summary"
  print "Run ID:              $RUN_ID"
  print "Media Root:          $MEDIA_ROOT"
  print "Report Dir:          $REPORT_DIR"
  print ""
  print "Filesystem:"
  df -h "$MEDIA_ROOT"
  print ""
  print "Top Directories:"
  head -20 "$DIR_SIZES"
  print ""
  print "Large Files Count:        $(( $(wc -l < "$LARGE_FILES") - 1 ))"
  print "Video Files Count:        $(( $(wc -l < "$VIDEO_FILES") - 1 ))"
  print "Cleanup Candidates Count: $(( $(wc -l < "$CLEANUP_CANDIDATES") - 1 ))"
  print ""
  print "Next step:"
  print "Review: $CLEANUP_CANDIDATES"
} | tee "$SUMMARY"

print ""
print "Done. Reports written to:"
print "$REPORT_DIR"
