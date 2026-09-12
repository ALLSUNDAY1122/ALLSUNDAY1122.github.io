#!/usr/bin/env python3
from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: normalize_msplat_s10_input.py <M1+M2-composed-msplat-root>")
    root = Path(sys.argv[1]).resolve()
    path = root / "Sources/MsplatCore/metal/msplat_metal.mm"
    text = path.read_text(encoding="utf-8")

    # The pinned July source has this exact brace-form guard in both the render
    # and training paths. Normalize syntax only so the fail-closed S10 patcher can
    # remove the guard and allow ensure_chunks(K<=1) to release stale buffers.
    old = '''    if (K_max > 1) {
        g_tcache.ensure_chunks(K_max, img_height, img_width, ctx->device);
    }
'''
    expected = 2
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"S10 chunk guard normalization: expected {expected} pinned matches, found {count}")
    new = "        if (K_max > 1) g_tcache.ensure_chunks(K_max, img_height, img_width, ctx->device);\n"
    path.write_text(text.replace(old, new), encoding="utf-8")
    print(f"PASS: normalized {expected} pinned ensure_chunks guards")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
