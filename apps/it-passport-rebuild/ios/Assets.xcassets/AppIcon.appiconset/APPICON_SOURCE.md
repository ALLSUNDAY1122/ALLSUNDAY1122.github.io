# AppIcon canonical source

- Product: 新ITパスポート｜学びスプリント
- Canonical source: Google Drive `ITパスポート.png`
- Google Drive file ID: `1Cej-mIkRG1NVjajSK8PI1xCE4vI17cXl`
- Source dimensions: 1254×1254
- Source mode: RGB / no alpha
- Source SHA-256: `a1c5fc063d443de17c8a498c132ccaad961dfa353a372756cd4e79ce4023f288`
- Submission materialization: preserve full square artwork, resize only to Apple-required 1024×1024, RGB, no alpha. No crop, no redraw, no substitution.

`tools/materialize_appicon.sh` is the only permitted materialization path for submission builds. It verifies the downloaded canonical source before producing `AppIcon-1024.png`. A failed integrity or format check must stop the build rather than fall back to a placeholder/black icon.
