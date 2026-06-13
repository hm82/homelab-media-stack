# Music Metadata Standards

## Purpose

Define the metadata quality standards used throughout the Odie music ecosystem.

These standards drive:

- Import validation
- Metadata audits
- Shazam enrichment
- Duplicate scoring
- Library maintenance

---

# Required Fields

Every track should contain:

```text
Title
Artist
Album
Album Artist
Year
Track Number
```

---

# Album Artist Rules

## Standard Albums

Album Artist should match the primary artist.

Example:

```text
Album Artist = Backstreet Boys
```

---

## Compilations

Use:

```text
Album Artist = Various Artists
```

Examples:

- Ajnabee
- Asoka
- Raaz
- Kaante
- Rehnaa Hai Terre Dil Mein

---

# Year Rules

## Allowed

```text
1985
1998
2001
2026
```

## Invalid

```text
0000
```

---

## Album-Year Rule

Album year should match the dominant track year.

Example:

```text
Album Year = 2001
Tracks = 2001
```

---

# Track Number Rules

## Allowed

```text
01
02
03
...
```

## Invalid

```text
00
```

Track `00` indicates incomplete metadata and should be corrected during enrichment.

---

# Artist Rules

## Allowed

```text
KK
Shaan
Bombay Jayashri
```

## Invalid

```text
Unknown Artist
New Artist
Artist
```

---

# Title Rules

## Allowed

```text
Zara Zara
Such Keh Raha Hai
Pehla Nasha
```

## Invalid

```text
Track 01
Track 02
Unknown Title
```

---

# Compilation Rules

For soundtrack albums:

```text
Album Artist = Various Artists
Artist = Actual Performer
```

Example:

```text
Album Artist = Various Artists
Artist = KK
Title = Such Keh Raha Hai
Album = Rehnaa Hai Terre Dil Mein
```

---

# Shazam Enrichment Rules

## Auto Accept

- Strong title match
- Strong artist match
- Similar duration
- Matching language/domain

---

## Manual Review

- Artist mismatch
- Album mismatch
- Genre mismatch
- Low confidence result

---

## Reject

Example:

```text
Dil To Pagal Hai
→ Michael Jackson
```

---

# Duplicate Strategy

Current policy:

```yaml
duplicate_action: keep
```

The library intentionally preserves potential duplicates for later review rather than discarding them during ingestion. Beets supports this workflow and also provides duplicate reporting tools for later maintenance.  [oai_citation:2‡Beets](https://beets.readthedocs.io/en/stable/plugins/duplicates.html?utm_source=chatgpt.com)

Future duplicate scoring will consider:

- Codec
- Bitrate
- Sample Rate
- Embedded Artwork
- Metadata Completeness
- Shazam Confidence

---

# Collection Tags

## Comment Field Usage

The comment field may be used to define collections.

Example:

```text
Archive Collection (2005)
```

Collections may be surfaced through:

- Dynamic Playlists
- Navidrome
- Symfonium

---

# Audit Severity Levels

## INFO

Metadata can be improved.

No action required.

---

## WARNING

Metadata should be corrected.

Library quality impacted.

---

## ERROR

Metadata invalid.

Examples:

```text
Year = 0000
Track = 00
Artist = Unknown Artist
Title = Track 01
```