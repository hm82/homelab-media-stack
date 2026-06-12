# Music Automation Pipeline

Automation for ingesting, inspecting, repairing, organizing, and importing downloaded music into a Beets-managed library and streaming platform such as Navidrome.

---

## Disclaimer

These scripts were developed for a personal homelab environment and are provided as-is. Review and test all scripts before running them in your own environment.

---

## Overview

The recommended workflow is:

```text
Downloads
    ↓
ingest_music_downloads.zsh
    ↓
music-inbox
    ↓
organize_music_library.zsh
    ↓
music-staging
    ↓
import_beets_library.zsh
    ↓
Beets Library
    ↓
Navidrome
```

---

## Quick Start

Run the complete music pipeline:

```bash
./run_music_pipeline.zsh /path/to/downloads/music
```

Example:

```bash
./run_music_pipeline.zsh /mnt/media/_downloads/music
```

---

## Core Scripts

| Script | Purpose |
|----------|----------|
| `run_music_pipeline.zsh` | End-to-end music ingestion pipeline |
| `ingest_music_downloads.zsh` | Moves completed audio files into the inbox while skipping incomplete downloads |
| `organize_music_library.zsh` | Organizes music into album structures suitable for Beets import |
| `import_beets_library.zsh` | Imports organized music into the Beets library |
| `audit_music_pipeline.zsh` | Generates post-run audit and reporting information |
| `analyze_music_directory.zsh` | Analyzes directory contents and media distribution |
| `inspect_music_metadata.zsh` | Inspects metadata for files and directories |
| `repair_music_metadata.zsh` | Experimental metadata repair and reporting utility |

---

## Directory Layout

The examples below assume a media root of:

```text
/mnt/media
```

```text
_downloads/
├── music
├── music-inbox
├── music-staging
├── music-imported
├── reports/
└── logs/

Music/
└── Beets-managed library
```

| Directory | Purpose |
|------------|------------|
| `_downloads/music` | Completed downloads |
| `_downloads/music-inbox` | Pipeline inbox |
| `_downloads/music-staging` | Organized staging area |
| `_downloads/music-imported` | Archived imported batches |
| `_downloads/reports/music-pipeline` | Pipeline reports |
| `_downloads/logs/music-pipeline` | Pipeline logs |
| `Music` | Final Beets-managed library |

---

## Manual Workflow

### Analyze Downloads

```bash
./analyze_music_directory.zsh /mnt/media/_downloads/music
```

### Ingest Only

```bash
./ingest_music_downloads.zsh /mnt/media/_downloads/music
```

### Rebuild Staging

```bash
rm -rf /mnt/media/_downloads/music-staging
mkdir -p /mnt/media/_downloads/music-staging

./organize_music_library.zsh
```

### Inspect Unknown Metadata

```bash
RUN=YYYYMMDD-HHMMSS

tail -n +2 \
  /mnt/media/_downloads/reports/music-pipeline/$RUN/unknown_metadata.csv \
| sed 's/^"//;s/".*$//' \
> /tmp/unknown-files.txt

./inspect_music_metadata.zsh /tmp/unknown-files.txt \
| column -t -s $'\t' \
| less -S
```

### Beets Dry Run

```bash
./import_beets_library.zsh dry-run
```

### Import into Library

```bash
./import_beets_library.zsh run
```

---

## Metadata Handling

`organize_music_library.zsh` uses embedded metadata in the following order:

1. Album Artist
2. Artist (fallback)
3. Album
4. Title

Supported formats:

- MP3
- FLAC
- M4A
- AAC
- OPUS
- OGG
- WAV

Metadata extraction is performed using `ffprobe`.

### OPUS Notes

Some OPUS files store metadata under stream tags rather than format tags. The scripts check both locations when extracting metadata.

---

## Download Exclusions

The ingestion process skips incomplete downloads and temporary files:

```text
incomplete/
.incomplete/
tmp/
temp/
partial/

*.part
*.tmp
*.crdownload
*.download
*.filepart
```

Optional custom exclusions can be defined in:

```text
config/music-ingest-excludes.txt
```

---

## Troubleshooting

### Staging Contains Fewer Files Than Inbox

Compare audio file counts:

```bash
find /mnt/media/_downloads/music-inbox -type f \
\( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o \
   -iname "*.aac" -o -iname "*.ogg" -o -iname "*.opus" -o \
   -iname "*.wav" \) | wc -l

find /mnt/media/_downloads/music-staging -type f \
\( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o \
   -iname "*.aac" -o -iname "*.ogg" -o -iname "*.opus" -o \
   -iname "*.wav" \) | wc -l
```

### Beets Reports Unreadable Files

```bash
grep "unreadable file:" \
  /mnt/media/_downloads/logs/music-pipeline/$RUN/beets-import.log \
| sed 's/^unreadable file: //' \
> /tmp/beets-unreadable.txt
```

### Rebuild Staging Safely

```bash
rm -rf /mnt/media/_downloads/music-staging
mkdir -p /mnt/media/_downloads/music-staging

./organize_music_library.zsh
```

---

## Repository Structure

| Folder | Purpose |
|----------|----------|
| `lib/` | Shared functions and configuration |
| `quality/` | Audio and CSV quality analysis utilities |
| `deezer/` | Deezer-specific grouping tools |
| `spotify/` | Spotify and yt-dlp processing utilities |
| `utilities/` | Metadata auditing and repair helpers |
| `archive/` | Historical script versions |

---

## Recommended Production Workflow

The following scripts are considered the primary pipeline:

```text
ingest_music_downloads.zsh
organize_music_library.zsh
import_beets_library.zsh
audit_music_pipeline.zsh
```

Useful supporting utilities:

```text
analyze_music_directory.zsh
inspect_music_metadata.zsh
audit_music_tags.sh
summarize_album_artists.sh
fix_compilation_tags.sh
retag_compilation_filenames.sh
```

Historical scripts are retained in the `archive/` directory for reference and migration purposes.
