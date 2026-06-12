#!/usr/bin/env zsh
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

CSV="${1:?Usage: csv_quality_check.zsh <csv_file> [report_dir]}"
REPORT_DIR="${2:-/mnt/media/_downloads/spotify/reports/csv_quality}"

BASENAME="$(basename "$CSV" .csv)"
OUT="$REPORT_DIR/${BASENAME}_quality_report.txt"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$CSV" ]]; then
  echo "ERROR: File not found: $CSV"
  exit 1
fi

awk_safe_count() {
  awk -F',' "$1" "$CSV"
}

{
  echo "CSV Quality Report"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "File: $CSV"
  echo "Generated: $(date)"
  echo ""

  echo "Basic Stats"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Total lines including header: $(wc -l < "$CSV" | tr -d ' ')"
  echo "Data rows excluding header:   $(awk 'END {print NR > 0 ? NR-1 : 0}' "$CSV")"
  echo ""

  echo "Header Columns"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' 'NR==1 {for (i=1; i<=NF; i++) printf "%2d  %s\n", i, $i}' "$CSV"
  echo ""

  echo "Column Completeness"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {
      for (i=1; i<=NF; i++) header[i]=$i
      cols=NF
      next
    }
    {
      total++
      for (i=1; i<=cols; i++) {
        if ($i != "") filled[i]++
      }
    }
    END {
      for (i=1; i<=cols; i++) {
        pct = total ? 100*(filled[i]+0)/total : 0
        printf "%-35s %7d/%-7d %6.1f%% populated\n", header[i], filled[i]+0, total, pct
      }
    }
  ' "$CSV"
  echo ""

  echo "Potential CSV Structure Issues"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {expected=NF; next}
    NF != expected {
      print "Line " NR ": expected " expected " fields, found " NF
      count++
    }
    END {
      if (!count) print "No inconsistent field-count rows detected by simple comma parser."
      else print "Total inconsistent rows:", count
    }
  ' "$CSV"
  echo ""

  echo "Empty Critical Field Counts"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {
      for (i=1; i<=NF; i++) {
        col[$i]=i
      }
      next
    }
    {
      total++
      if (col["Track name"] && $(col["Track name"])=="") missing_track++
      if (col["Artist name"] && $(col["Artist name"])=="") missing_artist++
      if (col["Album"] && $(col["Album"])=="") missing_album++
      if (col["Spotify - id"] && $(col["Spotify - id"])=="") missing_spotify++
      if (col["ISRC"] && $(col["ISRC"])=="") missing_isrc++
      if (col["Primary Playlist Bucket"] && $(col["Primary Playlist Bucket"])=="") missing_bucket++
      if (col["Already In Library"] && $(col["Already In Library"])=="") missing_library_flag++
    }
    END {
      printf "%-30s %d\n", "Missing Track name:", missing_track+0
      printf "%-30s %d\n", "Missing Artist name:", missing_artist+0
      printf "%-30s %d\n", "Missing Album:", missing_album+0
      printf "%-30s %d\n", "Missing Spotify ID:", missing_spotify+0
      printf "%-30s %d\n", "Missing ISRC:", missing_isrc+0
      printf "%-30s %d\n", "Missing Bucket:", missing_bucket+0
      printf "%-30s %d\n", "Missing Library Flag:", missing_library_flag+0
    }
  ' "$CSV"
  echo ""

  echo "Duplicate Checks"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {
      for (i=1; i<=NF; i++) col[$i]=i
      next
    }
    {
      if (col["Spotify - id"] && $(col["Spotify - id"])!="") spotify[$(col["Spotify - id"])]++
      if (col["Track name"] && col["Artist name"]) {
        key=tolower($(col["Artist name"]) "|" $(col["Track name"]))
        track_artist[key]++
      }
    }
    END {
      for (k in spotify) if (spotify[k]>1) spotify_dupes++
      for (k in track_artist) if (track_artist[k]>1) track_artist_dupes++

      printf "%-35s %d\n", "Duplicate Spotify IDs:", spotify_dupes+0
      printf "%-35s %d\n", "Duplicate Artist+Track pairs:", track_artist_dupes+0
    }
  ' "$CSV"
  echo ""

  echo "Already In Library Distribution"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {for (i=1; i<=NF; i++) col[$i]=i; next}
    col["Already In Library"] {
      v=$(col["Already In Library"])
      if (v=="") v="BLANK"
      count[v]++
    }
    END {
      if (!col["Already In Library"]) {
        print "Column not found: Already In Library"
      } else {
        for (k in count) print count[k], k
      }
    }
  ' "$CSV" | sort -nr
  echo ""

  echo "Library Match Confidence Distribution"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {for (i=1; i<=NF; i++) col[$i]=i; next}
    col["Library Match Confidence"] {
      v=$(col["Library Match Confidence"])
      if (v=="") v="BLANK"
      count[v]++
    }
    END {
      if (!col["Library Match Confidence"]) {
        print "Column not found: Library Match Confidence"
      } else {
        for (k in count) print count[k], k
      }
    }
  ' "$CSV" | sort -nr
  echo ""

  echo "Top Buckets"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {for (i=1; i<=NF; i++) col[$i]=i; next}
    col["Primary Playlist Bucket"] {
      v=$(col["Primary Playlist Bucket"])
      if (v=="") v="BLANK"
      count[v]++
    }
    END {
      for (k in count) print count[k], k
    }
  ' "$CSV" | sort -nr | head -20
  echo ""

  echo "Top Artists"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {for (i=1; i<=NF; i++) col[$i]=i; next}
    col["Artist name"] {
      v=$(col["Artist name"])
      if (v=="") v="BLANK"
      count[v]++
    }
    END {
      for (k in count) print count[k], k
    }
  ' "$CSV" | sort -nr | head -30
  echo ""

  echo "Suspicious Values"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk -F',' '
    NR==1 {
      for (i=1; i<=NF; i++) col[$i]=i
      next
    }
    {
      if (col["Album"]) {
        album=$(col["Album"])
        if (album=="True" || album=="False" || album=="Unknown" || album=="undefined") suspicious_album++
      }
      if (col["Artist name"]) {
        artist=$(col["Artist name"])
        if (artist=="Unknown" || artist=="undefined") suspicious_artist++
      }
      if (col["Track name"]) {
        title=$(col["Track name"])
        if (title=="Unknown" || title=="undefined") suspicious_title++
      }
    }
    END {
      printf "%-35s %d\n", "Suspicious albums:", suspicious_album+0
      printf "%-35s %d\n", "Suspicious artists:", suspicious_artist+0
      printf "%-35s %d\n", "Suspicious titles:", suspicious_title+0
    }
  ' "$CSV"
  echo ""

  echo "Non-ASCII Rows"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk 'NR>1 && $0 ~ /[^[:ascii:]]/ {count++} END {print count+0}' "$CSV"
  echo ""

  echo "Quality Check Complete"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

} | tee "$OUT"

echo ""
echo "Saved report:"
echo "$OUT"
