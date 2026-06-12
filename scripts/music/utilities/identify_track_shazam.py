#!/usr/bin/env python3

import asyncio
import sys
from pathlib import Path

from shazamio import Shazam


async def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <audio-file>")
        sys.exit(1)

    audio_file = Path(sys.argv[1])

    if not audio_file.is_file():
        print(f"Error: file not found: {audio_file}")
        sys.exit(1)

    shazam = Shazam()
    result = await shazam.recognize(str(audio_file))

    track = result.get("track", {})

    print("TITLE :", track.get("title", "Unknown"))
    print("ARTIST:", track.get("subtitle", "Unknown"))


if __name__ == "__main__":
    asyncio.run(main())
