# Homelab Media Stack

A collection of scripts, configuration examples, and automation workflows for managing a self-hosted media environment.

The project focuses on:

- Music ingestion and library management
- Metadata repair and enrichment
- Beets-based cataloging workflows
- Navidrome-compatible music organization
- Calibre and eBook management
- Media storage auditing and health checks
- Docker Compose examples for self-hosted media services

---

## Features

### 🎵 Music Library Automation

- Automated music ingestion pipeline
- Metadata inspection and repair
- Album and compilation normalization
- Beets integration
- Kid3 CLI integration
- Library quality auditing
- Legacy collection import workflows
- Shazam-assisted track identification
- Spotify playlist analysis and reporting
- Deezer album organization helpers

### 📚 Books and eBooks

- Calibre import automation
- Book library management helpers
- Bulk import workflows

### 🖥️ System Operations

- Media storage auditing
- Service health checks
- Operational reporting utilities
- Capacity and growth analysis

---

## Example Services

The included examples are designed to work alongside common homelab media applications.

| Service | Purpose |
|----------|----------|
| Navidrome | Music streaming |
| Jellyfin | Media streaming |
| slskd | Soulseek client |
| qBittorrent | Torrent downloads |
| Calibre-Web | eBook management |
| Audiobookshelf | Audiobooks and podcasts |
| Prowlarr | Indexer management |
| Sonarr | TV automation |
| Radarr | Movie automation |

### External Services

Some services may run outside Docker depending on the deployment model.

For example, Jellyfin may be installed directly on the host operating system rather than managed through Docker Compose.

---

## Example Media Directory Layout

The example Docker Compose configuration assumes a single media volume mounted at:

```text
/mnt/media
```

Example layout:

```text
/mnt/media
├── Music
│   ├── Artists
│   ├── Compilations
│   ├── Soundtracks
│   └── _Inbox
│
├── Books
│   ├── CalibreLibrary
│   ├── Audiobooks
│   └── _incoming
│
├── Podcasts
│
├── Movies
│
├── TV
│
├── _downloads
│   ├── music
│   ├── music-inbox
│   ├── music-staging
│   ├── music-imported
│   └── torrents
│
├── _incomplete
│
└── config
    ├── navidrome
    ├── calibre-web
    ├── audiobookshelf
    ├── slskd
    ├── qbittorrent
    ├── homepage
    └── uptime-kuma
```

### Music Workflow

```text
slskd
   ↓
_downloads/music
   ↓
music-inbox
   ↓
metadata repair
   ↓
beets import
   ↓
Music/Artists
   ↓
Navidrome
```

### Books Workflow

```text
_downloads
   ↓
Books/_incoming
   ↓
Calibre Import
   ↓
Books/CalibreLibrary
   ↓
Calibre-Web
```

The exact paths can be adjusted to match your environment.

---

## Local and Remote Access

Most services can be accessed using either a local hostname or a remote/private-network hostname.

Examples:

```text
Local LAN:
http://media-server:3000

Tailscale:
http://media-server.tailnet.example.ts.net:3000

```

---

## Architecture Overview

```text
                    ┌─────────────┐
                    │  Prowlarr   │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
      ┌─────▼─────┐                 ┌─────▼─────┐
      │  Sonarr   │                 │  Radarr   │
      └─────┬─────┘                 └─────┬─────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                    ┌──────▼──────┐
                    │ qBittorrent │
                    └──────┬──────┘
                           │
                           ▼
                      /Movies
                      /TV


                    ┌─────────────┐
                    │    slskd    │
                    └──────┬──────┘
                           │
                           ▼
                /_downloads/music
                           │
                           ▼
                 Music Automation
                           │
                           ▼
                      Beets
                           │
                           ▼
                     /Music
                           │
                           ▼
                    Navidrome


                 ┌────────────────┐
                 │ Calibre Import │
                 └───────┬────────┘
                         │
                         ▼
                 Calibre Library
                         │
                         ▼
                   Calibre-Web


                           ▼
                        Jellyfin
                           │
                           ▼
                    End User Apps
```

---

## Repository Structure

```text
.
├── README.md
├── examples/
│   ├── docker-compose.example.yml
│   └── *.example.*
├── config/
│   ├── music-ingest-excludes.example.txt
│   └── music-metadata-rules.example.yaml
├── docs/
├── scripts/
│   ├── books/
│   ├── music/
│   │   ├── deezer/
│   │   ├── lib/
│   │   ├── quality/
│   │   ├── spotify/
│   │   └── utilities/
│   └── system/
└── tests/
```

---

## Music Workflow

```text
Downloads
    ↓
Music Inbox
    ↓
Metadata Inspection
    ↓
Repair & Enrichment
    ↓
Beets Import
    ↓
Library Organization
    ↓
Navidrome
```

Supported repair workflows include:

- Filename-based tagging
- Compilation normalization
- Album artist correction
- Metadata audits
- Shazam-assisted track recovery
- Legacy collection imports

---

## Requirements

Many utilities assume the following tools are available:

### Core

- zsh
- bash
- Python 3

### Music

- ffmpeg
- ffprobe
- beets
- kid3-cli

### Optional

- Docker
- Docker Compose
- Navidrome
- Jellyfin
- Calibre

---

### VPN Configuration (Optional)

The Gluetun service requires WireGuard credentials.
Populate the WireGuard variables in `.env` if you intend to use Gluetun.
If you do not use Gluetun, the remaining services will still function normally.

If using Gluetun with WireGuard:
1. Copy `.env.example` to `.env`
2. Populate the WireGuard settings from your VPN provider
3. Never commit the real `.env` file

```bash
cp .env.example .env
```

---

## Getting Started

Clone the repository:

```bash
git clone https://github.com/<your-username>/homelab-media-stack.git
cd homelab-media-stack
```

Review the example configuration files:

```bash
ls examples/
```

Review the music automation scripts:

```bash
ls scripts/music
```

Run a metadata audit:

```bash
scripts/music/utilities/music-tags-audit.sh /path/to/music
```

---

## Security & Privacy

Before publishing or sharing:

- Do not commit `.env` files
- Do not commit credentials, API keys, or tokens
- Do not commit personal media collections
- Use example configuration files instead of production configurations

Sensitive files are excluded through `.gitignore`.

---

## Disclaimer

This repository contains automation, organization, and management tooling only.

No copyrighted media, download sources, credentials, or private user data are included.

Users are responsible for complying with all applicable laws, service terms, and copyright requirements in their jurisdiction.

---

## Roadmap

- [ ] Additional Navidrome utilities
- [ ] Media quality scoring
- [ ] Duplicate detection enhancements
- [ ] Music collection dashboards
- [ ] Dockerized utility container
- [ ] Automated metadata repair workflows
- [ ] CI/CD validation for scripts

---

## License

MIT License
