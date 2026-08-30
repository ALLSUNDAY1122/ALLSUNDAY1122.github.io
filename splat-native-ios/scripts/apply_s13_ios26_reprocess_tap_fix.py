#!/usr/bin/env python3
"""Keep the S13 same-raw reprocess action independently tappable inside a SwiftUI List.

Build 10 proved that styling the NavigationLink was not enough on the physical iOS 26 device.
The reliable boundary is structural: a List row must not contain both the saved-result
NavigationLink and the same-raw reprocess Button. This materializer therefore keeps the saved
result as its own NavigationLink row and emits the reprocess control as a second, independent
List row for the same project.

The transformation runs after apply_s13_depth_seed.py, is idempotent, and fails closed if the
expected generated source shape drifts.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY_PATH = ROOT / "SplatNative" / "ScanLibraryView.swift"
library = LIBRARY_PATH.read_text()

marker = "S13 iOS 26 tap routing: reprocess is a separate List row"
if marker in library:
    print("S13 iOS26 separate-row reprocess routing already materialized")
    raise SystemExit(0)

old_trusted_row = """        if let trustedURL = SplatProjectTrustRecovery.trustedResultURL(for: project) {
            VStack(alignment: .leading, spacing: 8) {
                NavigationLink {
                    SavedSplatView(
                        url: trustedURL,
                        title: project.manifest.title
                    )
                } label: {
                    rowLabel(project, canOpen: true)
                }
                if canReprocessTrusted(project) {
                    Button {
                        model.restoreFinishedProjectForS13Reprocess(id: project.id)
                        dismiss()
                    } label: {
                        Label("同じ撮影から再生成", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("現在の完成3Dを保護し、保存済みraw撮影だけを使って再生成します")
                }
            }
        } else if canContinue(project) {
"""
new_trusted_row = """        if let trustedURL = SplatProjectTrustRecovery.trustedResultURL(for: project) {
            NavigationLink {
                SavedSplatView(
                    url: trustedURL,
                    title: project.manifest.title
                )
            } label: {
                rowLabel(project, canOpen: true)
            }
        } else if canContinue(project) {
"""
if old_trusted_row not in library:
    raise SystemExit("S13 iOS26: generated trusted project row drifted")
library = library.replace(old_trusted_row, new_trusted_row, 1)

old_for_each = """                        ForEach(projects) { project in
                            projectRow(project)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("削除", role: .destructive) {
                                        moveToTrash(project)
                                    }
                                }
                        }
"""
new_for_each = """                        ForEach(projects) { project in
                            projectRow(project)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("削除", role: .destructive) {
                                        moveToTrash(project)
                                    }
                                }

                            if SplatProjectTrustRecovery.trustedResultURL(for: project) != nil,
                               canReprocessTrusted(project) {
                                // S13 iOS 26 tap routing: reprocess is a separate List row.
                                Button {
                                    model.restoreFinishedProjectForS13Reprocess(id: project.id)
                                    dismiss()
                                } label: {
                                    Label("同じ撮影から再生成", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mint)
                                .foregroundStyle(.black)
                                .accessibilityHint("現在の完成3Dを保護し、保存済みraw撮影だけを使って再生成します")
                            }
                        }
"""
if old_for_each not in library:
    raise SystemExit("S13 iOS26: library ForEach callsite drifted")
library = library.replace(old_for_each, new_for_each, 1)

LIBRARY_PATH.write_text(library)
print("S13 iOS26 same-raw reprocess moved to independent List row")
