#!/usr/bin/env python3
"""Run APP2-003 EAS signing bridge with the HTTP identity used by node-fetch.

No credential values are logged or persisted. This wrapper only changes the
User-Agent used by urllib's opener; all safety gates remain in the bridge.
"""
from __future__ import annotations

import runpy
import urllib.request

opener = urllib.request.build_opener()
opener.addheaders = [
    ("User-Agent", "node-fetch/1.0 (+https://github.com/bitinn/node-fetch)"),
]
urllib.request.install_opener(opener)
runpy.run_path("scripts/app2_003_eas_signing_bridge.py", run_name="__main__")
