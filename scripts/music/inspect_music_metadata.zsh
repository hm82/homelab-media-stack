#!/usr/bin/env zsh
set -uo pipefail

INPUT="${1:-}"

if [[ -z "$INPUT" ]]; then
  echo "Usage: $0 <audio-file|file-list|directory|->" >&2
  exit 1
fi

clean_path_line() {
  local s="$1"
  s="${s%$'\r'}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  s="${s#\"}"
  s="${s%\"}"
  s="${s%>}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

is_probably_audio_ext() {
  local f="$1"
  local ext="${f##*.}"
  ext="${ext:l}"

  case "$ext" in
    flac|mp3|m4a|aac|ogg|opus|wav|alac|aiff|ape|wv) return 0 ;;
    *) return 1 ;;
  esac
}

is_audio_by_ffprobe() {
  local f="$1"
  ffprobe -v error \
    -select_streams a:0 \
    -show_entries stream=codec_type \
    -of default=nw=1:nk=1 \
    "$f" 2>/dev/null | grep -q '^audio$'
}

get_tag() {
  local file="$1"
  local tag="$2"
  local value=""

  value="$(ffprobe -v error \
    -show_entries "format_tags=${tag}" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" 2>/dev/null \
    | head -n1 \
    | tr -d '\r')"

  [[ -n "$value" ]] && {
    print -r -- "$value"
    return
  }

  value="$(ffprobe -v error \
    -select_streams a:0 \
    -show_entries "stream_tags=${tag}" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" 2>/dev/null \
    | head -n1 \
    | tr -d '\r')"

  print -r -- "$value"
}

get_tag_broken() {
  local file="$1"
  local tag="$2"
  local value

  value="$(ffprobe -v error \
    -show_entries "format_tags=$tag" \
    -of default=nw=1:nk=1 \
    "$file" 2>/dev/null | head -n1)"

  if [[ -z "$value" ]]; then
    value="$(ffprobe -v error \
      -select_streams a:0 \
      -show_entries "stream_tags=$tag" \
      -of default=nw=1:nk=1 \
      "$file" 2>/dev/null | head -n1)"
  fi

  print -r -- "$value"
}

codec_name() {
  ffprobe -v error \
    -select_streams a:0 \
    -show_entries stream=codec_name \
    -of default=nw=1:nk=1 \
    "$1" 2>/dev/null | head -n1
}

duration_sec() {
  ffprobe -v error \
    -show_entries format=duration \
    -of default=nw=1:nk=1 \
    "$1" 2>/dev/null | awk '{printf "%.1f", $1}' 2>/dev/null
}

print_header() {
  printf "file\tstatus\tartist\talbum_artist\talbumartist\ttitle\talbum\ttrack\tdate\tgenre\tcodec\tduration\n"
}

inspect_file() {
  local file raw_status artist album_artist albumartist title album track date genre codec duration

  file="$(clean_path_line "$1")"

  [[ -z "$file" ]] && return 0

  if [[ ! -e "$file" ]]; then
    printf "%s\tmissing\t\t\t\t\t\t\t\t\t\t\n" "$file"
    return 0
  fi

  if [[ -d "$file" ]]; then
    find "$file" -type f -print0 |
      while IFS= read -r -d '' child; do
        inspect_file "$child"
      done
    return 0
  fi

  if ! is_probably_audio_ext "$file" && ! is_audio_by_ffprobe "$file"; then
    printf "%s\tnot-audio\t\t\t\t\t\t\t\t\t\t\n" "$file"
    return 0
  fi

  if ! is_audio_by_ffprobe "$file"; then
    printf "%s\tffprobe-failed\t\t\t\t\t\t\t\t\t\t\n" "$file"
    return 0
  fi

  artist="$(get_tag "$file" "artist")"
  album_artist="$(get_tag "$file" "album_artist")"
  albumartist="$(get_tag "$file" "albumartist")"
  title="$(get_tag "$file" "title")"
  album="$(get_tag "$file" "album")"
  track="$(get_tag "$file" "track")"
  date="$(get_tag "$file" "date")"
  genre="$(get_tag "$file" "genre")"
  codec="$(codec_name "$file")"
  duration="$(duration_sec "$file")"

  printf "%s\tok\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$file" "$artist" "$album_artist" "$albumartist" "$title" "$album" "$track" "$date" "$genre" "$codec" "$duration"
}

print_header

if [[ "$INPUT" == "-" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    inspect_file "$line"
  done

elif [[ -d "$INPUT" ]]; then
  inspect_file "$INPUT"

elif [[ -f "$INPUT" ]]; then
  if is_probably_audio_ext "$INPUT" || is_audio_by_ffprobe "$INPUT"; then
    inspect_file "$INPUT"
  else
    while IFS= read -r line || [[ -n "$line" ]]; do
      inspect_file "$line"
    done < "$INPUT"
  fi

else
  inspect_file "$INPUT"
fi
