#!/usr/bin/env zsh
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

set -euo pipefail

MUSIC="/mnt/media/Music"
DEEZER="/mnt/media/_downloads/music/Deezer"
BEETS_CONFIG="/mnt/media/config/beets/config.yaml"

count_audio() {
  local path="$1"

  if [[ ! -d "$path" ]]; then
    print "0"
    return
  fi

  find "$path" -type f \( \
    -iname "*.flac" -o \
    -iname "*.mp3" -o \
    -iname "*.m4a" -o \
    -iname "*.aac" -o \
    -iname "*.ogg" \
  \) | wc -l | tr -d ' '
}

section() {
  print "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print "📌 $1"
  print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

music_count="$(count_audio "$MUSIC")"
deezer_count="$(count_audio "$DEEZER")"

section "Music library counts"
print "🎵 Files in /mnt/media/Music:        $music_count"
print "📥 Files in original Deezer folder:  $deezer_count"

section "Beets database count"

if command -v beet >/dev/null 2>&1 && [[ -f "$BEETS_CONFIG" ]]; then
  beets_count="$(beet -c "$BEETS_CONFIG" ls -p | wc -l | tr -d ' ')"
  print "🧠 Tracks in Beets DB:              $beets_count"
else
  print "⚠️  Beets or config not found."
fi

section "Largest artist folders"
du -h --max-depth=1 "$MUSIC/Artists" 2>/dev/null | sort -hr | head -20

print "\n✅ Music count check complete."
