#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 fp2-manabi-sprint/ios/prepare-ios.py
