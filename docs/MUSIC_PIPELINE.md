#  Music Library Pipeline

## Overview

The Odie Music Pipeline transforms newly acquired music into a curated, searchable, auditable media library.

The pipeline is designed around four principles:

1. Preserve over Delete
2. Report over Enforce
3. Audit over Assume
4. Recoverability First

The pipeline intentionally favors metadata preservation and review rather than destructive automation.

---

# Pipeline Flow

```text
Downloads
    ↓
Analyze Downloads
    ↓
Ingest to Inbox
    ↓
Analyze Inbox
    ↓
Organize Library Structure
    ↓
Import into Beets Library
    ↓
Audit Results
    ↓
Navidrome
    ↓
Symfonium
```

---

# Stage 1 – Analyze Downloads

## Purpose

Analyze newly acquired media before ingestion.

## Goals

- Count audio files
- Identify formats
- Detect missing metadata
- Detect suspicious files

## Outputs

- File inventory
- Format distribution
- Metadata quality report

---

# Stage 2 – Ingestion

## Purpose

Move newly acquired media into the managed inbox.

## Goals

- Normalize download locations
- Prepare files for organization
- Generate ingestion reports

## Outputs

- Inbox inventory
- Ingestion summary

---
## Stage 3 – Metadata Enrichment

### Purpose

Improve metadata quality before organization and library import.

### Planned Enrichment Sources

- Shazam
- MusicBrainz
- Existing file tags
- Filename parsing

### Planned Repairs

- Album year normalization
- Track number repair
- Album artist repair
- Compilation detection
- Missing artist repair
- Missing title repair

### Planned Outputs

- enrichment-report.txt
- metadata-repairs.csv
- low-confidence-matches.txt

### Safety Rules

Automatic updates should only occur when confidence exceeds configured thresholds.

Low-confidence matches should be reported for manual review rather than applied automatically.
---
# Stage 4 – Inbox Analysis

## Purpose

Perform metadata analysis before organization.

## Goals

- Detect missing tags
- Detect suspicious filenames
- Detect incomplete albums

## Outputs

- Metadata health reports
- Candidate repair reports

---

# Stage 5 – Organization

## Purpose

Prepare media for Beets import.

## Goals

- Normalize folder structure
- Normalize album folders
- Normalize artist folders
- Ensure predictable import behavior

## Target Structure

```text
Artist/
Album (Year)/
01 - Title - Artist.mp3
```

### Compilations

```text
Various Artists/
Album (Year)/
01 - Title - Artist.mp3
```

---

# Stage 6 – Library Import

## Purpose

Import organized media into the Beets-managed library.

## Responsibilities

- Validate environment
- Report import policy
- Generate duplicate reports
- Import media
- Generate library diff reports
- Archive source material
- Cleanup staging

---

## Import Policy

Current Beets configuration:

```yaml
import:
  copy: yes
  move: no
  write: yes
  incremental: yes
  duplicate_action: keep
```

---

## Duplicate Handling Strategy

### Philosophy

The pipeline intentionally uses:

```yaml
duplicate_action: keep
```

instead of:

```yaml
duplicate_action: skip
```

### Rationale

A duplicate import may actually be:

- Higher bitrate
- Better artwork
- Better metadata
- Alternate release
- Remaster
- Regional release
- Soundtrack reissue

Automatically skipping duplicates risks losing the preferred copy.

### Current Strategy

```text
Import Everything
    ↓
Generate Duplicate Reports
    ↓
Review During Maintenance
```

### Future Strategy

```text
Import Everything
    ↓
Quality Scoring
    ↓
Recommend Preferred Version
    ↓
Manual Approval
```

Beets supports multiple duplicate actions (`keep`, `skip`, `merge`, `remove`, `ask`). The library intentionally uses `keep` to preserve potentially superior releases for later review.  [oai_citation:0‡Beets](https://beets.readthedocs.io/en/v1.6.0/reference/config.html?utm_source=chatgpt.com)

---

## Import Artifacts

### Import Logs

- `beets-import.log`

### Library Snapshots

- `library_before.txt`
- `library_after.txt`
- `library_diff.txt`

### Duplicate Reports

- `duplicate-tracks.txt`
- `duplicate-albums.txt`

### Archive Records

- `archived_files.csv`

### Summary Reports

- `import-summary.txt`

---

# Stage 6 – Audit

## Purpose

Validate metadata quality after import.

Current audits focus on reporting issues rather than blocking imports.

---

## Current Audits

### Duplicate Reporting

Track-level duplicate reporting.

Album-level duplicate reporting.

Beets provides duplicate analysis at both the track and album level through the duplicates plugin.  [oai_citation:1‡Beets](https://beets.readthedocs.io/en/stable/plugins/duplicates.html?utm_source=chatgpt.com)

---

## Planned Audits

### Album-Year Consistency Audit

Detect:

```text
Album Year = 0000
Track Years = 2001
```

Examples:

- Asoka
- Ajnabee
- Kabhi Khushi Kabhie Gham

---

### Track Number Audit

Detect:

```text
Track = 00
```

Examples:

- Ajnabee
- Kaante
- Armaan

---

### Missing Metadata Audit

Detect:

- Missing artist
- Missing title
- Missing album
- Missing year

---

### Navidrome Validation

Detect:

- Missing files
- Stale database entries
- Playlist inconsistencies

---

### Shazam Validation

Detect:

- Low confidence matches
- False positives
- Metadata conflicts

---

# Navidrome Integration

## Purpose

Expose imported music through Navidrome.

## Validation Goals

- Detect stale entries
- Detect missing files
- Detect playlist inconsistencies

---

# Symfonium Integration

## Purpose

Consume Navidrome collections and playlists.

## Validation Goals

- Playlist synchronization
- Metadata consistency
- Artwork consistency

---

# Archive Strategy

## Purpose

Preserve original source material.

Archive location:

```text
music-imported/YYYY-MM-DD/RUN_ID/
```

Example:

```text
music-imported/
└── 2026-06-12/
    └── 20260612-094500/
```

## Benefits

- Rollback capability
- Reprocessing capability
- Audit trail
- Historical preservation

---

# Operational Modes

## dry-run

Validate configuration.

Preview actions.

No files modified.

---

## run

Execute full import workflow.

---

## tag

Run MusicBrainz-assisted import.

---

## duplicates

Generate duplicate reports without importing.

---

# Recovery Model

All imported source material is archived.

Archive location:

```text
music-imported/YYYY-MM-DD/RUN_ID/
```

Benefits:

- Rollback capability
- Reprocessing capability
- Audit trail
- Historical preservation

---
## Utility: manual_metadata_repair.zsh

Purpose:

Repair missing or low-quality metadata using filename and folder inference.

Classification:

Manual utility.

Not part of the production ingestion pipeline.

Typical Usage:

```bash
manual_metadata_repair.zsh report
```

Generate candidate repairs without modifying files.

```bash
MIN_CONFIDENCE=90 manual_metadata_repair.zsh apply
```

Apply high-confidence repairs.

Typical Use Cases:

- Legacy MP3 collections
- Unknown Artist tags
- Track 01 / Track 02 placeholders
- Missing album metadata
- Pre-import cleanup

Safety Notes:

- Prefer report mode first.
- Apply mode should be used only after reviewing candidates.
- Pipeline stages should not depend on this utility.
```
---
# Future Roadmap

## Metadata Quality

- Album-Year Audit
- Track-00 Audit
- Missing Artist Audit
- Missing Year Audit

## Duplicate Intelligence

- Bitrate Scoring
- Codec Scoring
- Artwork Scoring
- Metadata Completeness Scoring

## Enrichment

- Shazam Integration
- MusicBrainz Integration
- Cover Art Retrieval

## Library Health

- Navidrome Validation
- Playlist Validation
- Collection Audits
- Metadata Drift Detection