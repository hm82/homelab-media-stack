#!/usr/bin/env python3

import asyncio
import json
import sys
from shazamio import Shazam

async def main():
    shazam = Shazam()
    result = await shazam.recognize(sys.argv[1])

    print(json.dumps(result, indent=2))

asyncio.run(main())
