#!/usr/bin/env python3
"""
extract_track_metadata_shazam.py

Identify audio tracks using Shazam and extract useful metadata.

Requirements:
    pip install shazamio

Examples:

    ./extract_shazam_metadata.py song.mp3

    ./extract_shazam_metadata.py song.mp3 --json

    ./extract_shazam_metadata.py song.mp3 --save-raw raw.json

Output fields:
    title
    artist
    album
    genre
    year
    label
    isrc
    shazam_id
    cover_art_url
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

from shazamio import Shazam


def extract_metadata(result: dict) -> dict:
    """Normalize Shazam response."""

    track = result.get("track", {})

    album = ""
    label = ""
    year = ""

    for section in track.get("sections", []):
        if section.get("type") != "SONG":
            continue

        for item in section.get("metadata", []):
            title = item.get("title", "").lower()

            if title == "album":
                album = item.get("text", "")

            elif title == "label":
                label = item.get("text", "")

            elif title == "released":
                year = item.get("text", "")

    return {
        "title": track.get("title", ""),
        "artist": track.get("subtitle", ""),
        "album": album,
        "genre": track.get("genres", {}).get("primary", ""),
        "year": year,
        "label": label,
        "isrc": track.get("isrc", ""),
        "shazam_id": track.get("key", ""),
        "cover_art_url": track.get("images", {}).get("coverarthq", ""),
        "shazam_url": track.get("url", ""),
    }


async def identify(audio_file: str) -> dict:
    shazam = Shazam()
    return await shazam.recognize(audio_file)


def print_table(metadata: dict):
    width = max(len(k) for k in metadata.keys())

    for key, value in metadata.items():
        print(f"{key.upper():<{width}} : {value}")


def print_csv(metadata: dict):
    fields = [
        "title",
        "artist",
        "album",
        "genre",
        "year",
        "label",
        "isrc",
        "shazam_id",
    ]

    print("|".join(metadata.get(f, "") for f in fields))


async def main():

    parser = argparse.ArgumentParser(
        description="Extract metadata from audio files using Shazam"
    )

    parser.add_argument(
        "audio_file",
        help="Audio file to identify",
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Output normalized metadata as JSON",
    )

    parser.add_argument(
        "--csv",
        action="store_true",
        help="Output pipe-delimited metadata",
    )

    parser.add_argument(
        "--save-raw",
        metavar="FILE",
        help="Save raw Shazam response JSON",
    )

    args = parser.parse_args()

    audio_file = Path(args.audio_file)

    if not audio_file.exists():
        print(f"ERROR: File not found: {audio_file}", file=sys.stderr)
        sys.exit(1)

    try:
        result = await identify(str(audio_file))

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)

    if args.save_raw:
        with open(args.save_raw, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2, ensure_ascii=False)

    metadata = extract_metadata(result)

    if args.json:
        print(json.dumps(metadata, indent=2, ensure_ascii=False))

    elif args.csv:
        print_csv(metadata)

    else:
        print_table(metadata)


if __name__ == "__main__":
    asyncio.run(main())
