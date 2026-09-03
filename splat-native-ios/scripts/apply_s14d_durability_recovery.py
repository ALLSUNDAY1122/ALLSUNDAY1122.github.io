#!/usr/bin/env python3
"""Materialize the S14D same-raw durability/recovery guard.

Physical Build 13 evidence showed the Library hub at Splat 0 after a failed same-raw
experiment. The durable store moves the active project to .Trash when discardAndReset()
is invoked, while the Library hub count excludes Trash. That is a recoverable state, but
the old failed screen exposed "撮影からやり直す" as a one-tap action and could therefore
make retained RAW look deleted.

S14D is intentionally UI/durability-only:
- never discard a failed project with one tap;
- offer a non-destructive "ライブラリに残して終了" path;
- require an explicit destructive confirmation before moving RAW to Trash;
- surface Trash count in the production Library hub and empty Splat library.

No reconstruction, seed, trainer, resource, quality, or export behavior is changed.
The patch runs after S13 materialization and fails closed on source drift.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ROOT_VIEW_PATH = ROOT / "SplatNative" / "RootScanView.swift"
LIBRARY_PATH = ROOT / "SplatNative" / "ScanLibraryView.swift"
MESH_LIBRARY_PATH = ROOT / "SplatNative" / "MeshLibraryView.swift"

root_view = ROOT_VIEW_PATH.read_text()
library = LIBRARY_PATH.read_text()
mesh_library = MESH_LIBRARY_PATH.read_text()

state_marker = "S14D durability: failed project discard requires explicit confirmation"
if state_marker not in root_view:
    old_state = """    @State private var showingShare = false
    @State private var showingMesh = false
"""
    new_state = f"""    @State private var showingShare = false
    @State private var showingMesh = false
    // {state_marker}
    @State private var confirmDiscardFailedProject = false
"""
    if old_state not in root_view:
        raise SystemExit("S14D: RootScanView state callsite drifted")
    root_view = root_view.replace(old_state, new_state, 1)

    old_sheet = """        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                SplatExportOptionsView(sourceURL: url)
            }
        }
"""
    new_sheet = """        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                SplatExportOptionsView(sourceURL: url)
            }
        }
        .confirmationDialog(
            "保存済みraw撮影を最近削除へ移しますか？",
            isPresented: $confirmDiscardFailedProject,
            titleVisibility: .visible
        ) {
            Button("最近削除へ移して撮り直す", role: .destructive) {
                model.discardAndReset()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("raw撮影と再生成可能な状態はLibraryの「最近削除」へ移ります。完全削除するまでは復元できます。")
        }
"""
    if old_sheet not in root_view:
        raise SystemExit("S14D: RootScanView modifier callsite drifted")
    root_view = root_view.replace(old_sheet, new_sheet, 1)

    old_failed = """            if model.canRetryGeneration {
                Button("生成だけもう一度試す") {
                    model.retryGeneration()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("撮影からやり直す") {
                    model.discardAndReset()
                }
                .foregroundStyle(.secondary)
            } else {
                Button("撮影からやり直す") {
                    model.discardAndReset()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
"""
    new_failed = """            if model.canRetryGeneration {
                Button("生成だけもう一度試す") {
                    model.retryGeneration()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button("ライブラリに残して終了") {
                model.returnHomePreservingProject()
            }
            .buttonStyle(model.canRetryGeneration ? SecondaryButtonStyle() : PrimaryButtonStyle())

            Button("撮影データを最近削除へ移して撮り直す", role: .destructive) {
                confirmDiscardFailedProject = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.red)
"""
    if old_failed not in root_view:
        raise SystemExit("S14D: failed-view action block drifted")
    root_view = root_view.replace(old_failed, new_failed, 1)

empty_marker = "S14D durability: empty active library still surfaces recoverable Trash"
if empty_marker not in library:
    old_empty = """                    ContentUnavailableView(
                        "保存済みスキャンはありません",
                        systemImage: "cube.transparent",
                        description: Text("完成したSplatはここから何度でも開けます。")
                    )
"""
    new_empty = f"""                    ContentUnavailableView(
                        "保存済みスキャンはありません",
                        systemImage: "cube.transparent",
                        description: Text(trash.isEmpty
                            ? "完成したSplatはここから何度でも開けます。"
                            : "最近削除に\\(trash.count)件あります。右上のゴミ箱から復元できます。")
                    )
                    // {empty_marker}
"""
    if old_empty not in library:
        raise SystemExit("S14D: ScanLibraryView empty-state callsite drifted")
    library = library.replace(old_empty, new_empty, 1)

hub_marker = "S14D durability: production hub exposes recoverable Splat Trash count"
if hub_marker not in mesh_library:
    old_state = """    @State private var showingSplatLibrary = false
    @State private var splatCount = 0
    @State private var meshCount = 0
"""
    new_state = f"""    @State private var showingSplatLibrary = false
    @State private var splatCount = 0
    // {hub_marker}
    @State private var splatTrashCount = 0
    @State private var meshCount = 0
"""
    if old_state not in mesh_library:
        raise SystemExit("S14D: Library hub state callsite drifted")
    mesh_library = mesh_library.replace(old_state, new_state, 1)

    old_subtitle = '                            subtitle: "保存済み・生成待ち・再処理",\n'
    new_subtitle = '                            subtitle: splatTrashCount > 0\n                                ? "保存済み・生成待ち・再処理 · 最近削除 \\(splatTrashCount)"\n                                : "保存済み・生成待ち・再処理",\n'
    if old_subtitle not in mesh_library:
        raise SystemExit("S14D: Library hub Splat subtitle callsite drifted")
    mesh_library = mesh_library.replace(old_subtitle, new_subtitle, 1)

    old_counts = """            return (splatStore.listProjects().count, meshStore.listProjects().count)
        }.value
        splatCount = counts.0
        meshCount = counts.1
"""
    new_counts = """            return (
                splatStore.listProjects().count,
                splatStore.listTrash().count,
                meshStore.listProjects().count
            )
        }.value
        splatCount = counts.0
        splatTrashCount = counts.1
        meshCount = counts.2
"""
    if old_counts not in mesh_library:
        raise SystemExit("S14D: Library hub count refresh callsite drifted")
    mesh_library = mesh_library.replace(old_counts, new_counts, 1)

required_root = [
    state_marker,
    "ライブラリに残して終了",
    "保存済みraw撮影を最近削除へ移しますか？",
    "model.returnHomePreservingProject()",
    "confirmDiscardFailedProject = true",
]
for token in required_root:
    if token not in root_view:
        raise SystemExit(f"S14D: missing RootScanView token {token!r}")

required_library = [empty_marker, "最近削除に\\(trash.count)件あります"]
for token in required_library:
    if token not in library:
        raise SystemExit(f"S14D: missing ScanLibraryView token {token!r}")

required_hub = [hub_marker, "splatTrashCount", "splatStore.listTrash().count"]
for token in required_hub:
    if token not in mesh_library:
        raise SystemExit(f"S14D: missing Library hub token {token!r}")

ROOT_VIEW_PATH.write_text(root_view)
LIBRARY_PATH.write_text(library)
MESH_LIBRARY_PATH.write_text(mesh_library)
print("S14D durability/recovery guard materialized")
