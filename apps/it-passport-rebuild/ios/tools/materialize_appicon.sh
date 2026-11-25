#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/Assets.xcassets/AppIcon.appiconset"
OUT="$ICON_DIR/AppIcon-1024.png"
SRC="$ROOT/tools/ITPassport-canonical.png"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

EXPECTED_SOURCE_SHA="a1c5fc063d443de17c8a498c132ccaad961dfa353a372756cd4e79ce4023f288"
EXPECTED_PIXEL_SHA="7ecad6e7e195da9be52b2b75f2afd3dbfd199c1134fb737207abdd808ebc0403"
EXPECTED_OUTPUT_SHA="be4b5e7a38909ce702065c660cc18f6401b9ae2a560e71b342d8204f5067e677"

PILLOW_VERSION="12.3.0"
PYTHON=python3

if [ ! -f "$SRC" ]; then
  echo "FAIL: canonical PNG not found: $SRC" >&2
  exit 1
fi

if ! "$PYTHON" -c 'import PIL,sys; sys.exit(PIL.__version__ != sys.argv[1])' "$PILLOW_VERSION"; then
  python3 -m venv "$TMP/venv"
  PYTHON="$TMP/venv/bin/python"
  "$PYTHON" -m pip install --quiet --disable-pip-version-check "Pillow==$PILLOW_VERSION"
fi

mkdir -p "$ICON_DIR"

"$PYTHON" - "$SRC" "$TMP/AppIcon-1024.png" "$EXPECTED_SOURCE_SHA" "$EXPECTED_PIXEL_SHA" "$EXPECTED_OUTPUT_SHA" "$PILLOW_VERSION" <<'PY'
import hashlib, io, sys
from pathlib import Path
from PIL import Image, __version__

source, output, source_sha, pixel_sha, output_sha, pillow_version = sys.argv[1:]

def require(condition, message):
    if not condition:
        raise SystemExit('FAIL: ' + message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

require(__version__ == pillow_version, 'Pillow version mismatch')

raw = Path(source).read_bytes()

require(sha(raw) == source_sha, 'canonical file SHA mismatch')

with Image.open(io.BytesIO(raw)) as im:
    require(
        im.format == 'PNG'
        and im.size == (1254, 1254)
        and im.mode == 'RGB'
        and 'transparency' not in im.info,
        'source format mismatch'
    )

    rgb = im.convert('RGB')

    require(
        sha(rgb.tobytes()) == pixel_sha,
        'canonical pixel SHA mismatch'
    )

    rgb.resize(
        (1024, 1024),
        Image.Resampling.LANCZOS
    ).save(
        output,
        format='PNG',
        optimize=True,
        compress_level=9
    )

require(
    sha(Path(output).read_bytes()) == output_sha,
    'output SHA mismatch'
)

with Image.open(output) as im:
    require(
        im.format == 'PNG'
        and im.size == (1024, 1024)
        and im.mode == 'RGB'
        and 'transparency' not in im.info,
        'output format mismatch'
    )

print(
    f'PASS source_sha={source_sha} '
    f'pixel_sha={pixel_sha} '
    f'output_sha={output_sha} '
    'size=1024x1024 alpha=no'
)
PY

mv -f "$TMP/AppIcon-1024.png" "$OUT"
