#!/usr/bin/env python3
"""Keep the S13 same-raw reprocess action independently tappable inside a SwiftUI List row.

On iOS 26, a default-styled NavigationLink inside List can own the row's button semantics and
swallow sibling button taps. S13 intentionally keeps the saved-result navigation and the explicit
same-raw action in one visual row, so materialize a non-default NavigationLink style and an explicit
content shape for the reprocess control after the main S13 patch has been applied.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY_PATH = ROOT / "SplatNative" / "ScanLibraryView.swift"
library = LIBRARY_PATH.read_text()

old_navigation = """                } label: {
                    rowLabel(project, canOpen: true)
                }
                if canReprocessTrusted(project) {
"""
new_navigation = """                } label: {
                    rowLabel(project, canOpen: true)
                }
                // S13 iOS 26 tap routing: prevent NavigationLink from owning the whole List row.
                .buttonStyle(.plain)
                if canReprocessTrusted(project) {
"""
if old_navigation in library:
    library = library.replace(old_navigation, new_navigation, 1)
elif new_navigation not in library:
    raise SystemExit("S13 iOS26: trusted NavigationLink callsite drifted")

old_button = """                    } label: {
                        Label("同じ撮影から再生成", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
"""
new_button = """                    } label: {
                        Label("同じ撮影から再生成", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
"""
if old_button in library:
    library = library.replace(old_button, new_button, 1)
elif new_button not in library:
    raise SystemExit("S13 iOS26: reprocess Button callsite drifted")

LIBRARY_PATH.write_text(library)
print("S13 iOS26 same-raw reprocess tap routing materialization complete")
