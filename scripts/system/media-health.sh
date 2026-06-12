#!/usr/bin/env zsh
set -euo pipefail

MEDIA="/mnt/media"
TAILSCALE_HOST="${TAILSCALE_HOST:-media-server.tailnet.example.ts.net}"

bytes_human() {
  numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"
}

mount_total_bytes() {
  df -B1 "$MEDIA" | awk 'NR==2 {print $2}'
}

service_status() {
  local name="$1"
  local url="$2"
  local container="$3"

  local http_status="DOWN"
  local pid="-"
  local proc="-"
  local container_status="-"

  if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
    http_status="UP"
  fi

  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    container_status="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "-")"
    pid="$(docker inspect -f '{{.State.Pid}}' "$container" 2>/dev/null || echo "-")"
    proc="$(ps -p "$pid" -o comm= 2>/dev/null || echo "docker")"
  else
    pid="$(pgrep -f "$container" | head -1 || true)"
    if [[ -n "$pid" ]]; then
      proc="$(ps -p "$pid" -o comm= 2>/dev/null || echo "-")"
      container_status="local-process"
    fi
  fi

  printf "%-18s %-6s %-14s %-8s %-18s %s\n" "$name" "$http_status" "$container_status" "$pid" "$proc" "$url"
}

section() {
  print "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print "📌 $1"
  print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

section "Disk usage"
df -h "$MEDIA" | awk 'NR==1 || NR==2 {print}'

section "Largest media folders"
TOTAL_BYTES="$(mount_total_bytes)"

printf "%-10s %-8s %-12s %s\n" "Used" "%Disk" "Category" "Path"

find "$MEDIA" -mindepth 1 -maxdepth 1 -type d -print0 \
  | xargs -0 du -sb 2>/dev/null \
  | sort -nr \
  | while read -r bytes folder_path; do
      pct=$(echo "scale=1; ($bytes * 100) / $TOTAL_BYTES" | bc)
      human="$(numfmt --to=iec --suffix=B "$bytes")"
      category="$(basename "$folder_path")"
      printf "%-10s %-8s %-12s %s\n" \
        "$human" \
        "${pct}%" \
        "$category" \
        "$folder_path"
    done
## du -h --max-depth=1 "$MEDIA" 2>/dev/null | sort -hr | head -20

section "Docker containers"

if command -v docker >/dev/null 2>&1; then
  docker ps \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
else
  print "Docker CLI not found in PATH"
fi

section "Memory"
free -h

section "Top memory processes"
ps aux --sort=-%mem | awk 'NR==1 || NR<=15 {print}'


section "Quick service URLs + Runtime Status"
print "🌐 Tailscale Host:  http://${TAILSCALE_HOST}"
print ""
printf "%-18s %-6s %-14s %-8s %-18s %s\n" "Service" "HTTP" "Runtime" "PID" "Process" "URL"
printf "%-18s %-6s %-14s %-8s %-18s %s\n" "-------" "----" "-------" "---" "-------" "---"

print ""
print "🎵 Media Services"
service_status " 🎵 Navidrome"      "http://localhost:4533"  "navidrome"
service_status " 🎬 Jellyfin"       "http://localhost:8096"  "jellyfin"
service_status " 🎧 Audiobookshelf" "http://localhost:13378" "audiobookshelf"
service_status " 📚 Calibre-Web"    "http://localhost:8083"  "calibre-web"
service_status " 🤖 LazyLibrarian"  "http://localhost:5299"  "lazylibrarian"

print ""
print "🎬 Media Automation"
service_status " 🎞️ Sonarr"         "http://localhost:8989"  "sonarr"
service_status " 🎥 Radarr"         "http://localhost:7878"  "radarr"
service_status " 🔎 Prowlarr"       "http://localhost:9696"  "prowlarr"
service_status " 🎫 Jellyseerr"     "http://localhost:5055"  "jellyseerr"

print ""
print "⬇️ Download Clients (via Gluetun + Mullvad)"
service_status " 🎼 slskd"          "http://localhost:5030"  "slskd"
service_status " 🌊 qBittorrent"    "http://localhost:8082"  "qbittorrent"
service_status " 🔒 Gluetun API"    "http://localhost:8000"  "gluetun"

print ""
print "🏠 Home Automation"
service_status " 🏡 Home Assistant" "http://localhost:8123"  "homeassistant"

## print "🌐 Tailscale Host:  http://${TAILSCALE_HOST}"

print ""
print "🌍 Remote Access: replace localhost with $TAILSCALE_HOST"

print "\n✅ Media health check complete."
