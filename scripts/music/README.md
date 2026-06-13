# Music Automation Pipeline

Automation for ingesting, enriching, organizing, importing, and auditing downloaded music into a Beets-managed library and streaming platforms such as Navidrome.

---

## Disclaimer

These scripts were developed for a personal homelab environment and are provided as-is. Review and test all scripts before running them in your own environment.

---

## Overview

The music pipeline follows a staged workflow designed to safely ingest, organize, import, and audit music before it reaches the production library.

```text
Downloads
    ↓
01_analyze_music.zsh (optional)
    ↓
02_ingest_music.zsh
    ↓
music-inbox
    ↓
03_enrich_music_metadata.zsh (future)
    ↓
04_organize_music.zsh
    ↓
music-staging
    ↓
05_import_music_library.zsh
    ↓
Beets Library
    ↓
06_audit_music_library.zsh
    ↓
Navidrome
```

---

## Quick Start

The pipeline is orchestrated by:

```text
00_run_music_pipeline.zsh /path/to/downloads/music
```
which executes each stage in sequence and generates run reports, logs, and audit artifacts.

Example:

```bash
./00_run_music_pipeline.zsh /mnt/media/_downloads/music
```

---

## Core Pipeline

| Script | Purpose |
|----------|----------|
| `00_run_music_pipeline.zsh` | Orchestrates the complete music ingestion pipeline |
| `01_analyze_music.zsh` | Generates analysis reports for source, inbox, or staging directories |
| `02_ingest_music.zsh` | Moves completed downloads into the pipeline inbox while excluding incomplete downloads |
| `03_enrich_music_metadata.zsh` | Placeholder for future metadata enrichment and external metadata providers |
| `04_organize_music.zsh` | Organizes audio into Beets-friendly album structures in staging |
| `05_import_music_library.zsh` | Imports organized music into the Beets-managed library and generates import artifacts |
| `06_audit_music_library.zsh` | Performs post-import auditing and validation |

## Utilities
| Script | Purpose |
|----------|----------|
| `inspect_music_metadata.zsh` | Interactive metadata inspection utility |
| `manual_metadata_repair.zsh` | Manual metadata repair and reporting utility |
| `audit_music_tags.sh` | Audits music library metadata and identifies missing, inconsistent, or suspicious tags requiring review. |
| `summarize_album_artists.sh` | Generates reports on Album Artist usage to help identify compilation albums, inconsistent artist assignments, and library organization issues. |
| `fix_compilation_tags.sh` | Normalizes compilation album metadata by setting consistent Album Artist and compilation-related tags across tracks. |
| `retag_compilation_filenames.sh` | Updates compilation track metadata using filename patterns and folder structure when embedded tags are missing or incorrect. |
---

## Repository Structure

| Folder | Purpose |
|----------|----------|
| `lib/` | Shared configuration and helper functions |
| `tests/` | Smoke tests and integration tests |
| `utilities/` | Manual repair, inspection, and maintenance utilities |
| `quality/` | Audio and CSV quality analysis utilities |

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
| `_downloads/music` | Completed downloads awaiting ingestion |
| `_downloads/music-inbox` | Raw pipeline inbox |
| `_downloads/music-staging` | Organized and normalized staging area |
| `_downloads/music-imported` | Archived import batches |
| `_downloads/reports/music-pipeline` | Pipeline reports and audit artifacts |
| `_downloads/logs/music-pipeline` | Pipeline execution logs |
| `Music` | Production Beets-managed music library |

---

## Recommended Production Workflow

The following scripts form the primary production pipeline:

```text
00_run_music_pipeline.zsh
├── 01_analyze_music.zsh
├── 02_ingest_music.zsh
├── 03_enrich_music_metadata.zsh
├── 04_organize_music.zsh
├── 05_import_music_library.zsh
└── 06_audit_music_library.zsh
```

Individual stages may also be executed independently for troubleshooting or maintenance purposes.

---
### Beets Dry Run

```bash
./05_import_music_library.zsh dry-run
```

### Import into Library

```bash
./05_import_music_library.zsh run
```

---

## Testing

Validate all pipeline scripts:

```bash
./tests/smoke_test.zsh
```

Run Stage 05 import validation:

```bash
./tests/test_import_dry_run.zsh
```

Run the complete test suite:

```bash
./test.zsh
```

Tests currently cover:

- Script syntax validation
- Pipeline startup validation
- Stage 05 dry-run execution
- Report generation
- Log generation
- Import workflow validation

Additional end-to-end and fixture-based regression tests will be added as the pipeline evolves.

---
## Manual Workflow

### Run Full Pipeline

```bash
./00_run_music_pipeline.zsh /mnt/media/_downloads/music
```

### Analyze Downloads

```bash
./01_analyze_music.zsh /mnt/media/_downloads/music
```

### Ingest Downloads Only

```bash
./02_ingest_music.zsh /mnt/media/_downloads/music
```

### Organize Inbox into Staging

```bash
./04_organize_music.zsh
```

### Rebuild Staging

```bash
rm -rf /mnt/media/_downloads/music-staging
mkdir -p /mnt/media/_downloads/music-staging

./04_organize_music.zsh
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

### Generate Metadata Repair Report

```bash
./utilities/manual_metadata_repair.zsh report
```

### Apply Metadata Repairs

```bash
MIN_CONFIDENCE=90 \
./utilities/manual_metadata_repair.zsh apply
```

### Beets Import Dry Run

```bash
./05_import_music_library.zsh dry-run
```

### Import into Library

```bash
./05_import_music_library.zsh run
```

### Generate Duplicate Reports

```bash
./05_import_music_library.zsh duplicates
```

### Audit Music Library

```bash
./06_audit_music_library.zsh
```

---

## Metadata Handling

`04_organize_music.zsh` uses embedded metadata in the following order:

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
- AIFF
- ALAC
- APE
- WV

Metadata extraction is performed using `ffprobe`.

### OPUS Notes

Some OPUS files store metadata under stream tags rather than format tags. The scripts check both locations when extracting metadata.

### Future Metadata Enrichment

Stage 03 (`03_enrich_music_metadata.zsh`) is reserved for future enrichment workflows such as:

- MusicBrainz lookups
- Discogs lookups
- Deezer metadata enrichment
- Spotify metadata enrichment
- Album year normalization
- Genre normalization
- Cover art enhancement

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

Optional custom exclusions may be defined in:

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
RUN=YYYYMMDD-HHMMSS

grep "unreadable file:" \
  /mnt/media/_downloads/logs/music-pipeline/$RUN/beets-import.log \
| sed 's/^unreadable file: //' \
> /tmp/beets-unreadable.txt
```

### Review Duplicate Reports

```bash
RUN=YYYYMMDD-HHMMSS

cat /mnt/media/_downloads/reports/music-pipeline/$RUN/duplicate-tracks.txt

cat /mnt/media/_downloads/reports/music-pipeline/$RUN/duplicate-albums.txt
```

### Rebuild Staging Safely

```bash
rm -rf /mnt/media/_downloads/music-staging
mkdir -p /mnt/media/_downloads/music-staging

./04_organize_music.zsh
```

### Run Test Suite

```bash
./test.zsh
```
---
