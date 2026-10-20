#!/usr/bin/env python3
"""Materialize the physical-iPhone fixes for S13 same-raw reprocess.

Build 10 proved that styling a NavigationLink was insufficient: the saved-result link and
same-raw Button must be separate SwiftUI List rows. Build 11 proved that the action then fires,
but a reprocess started from the production Library tab merely dismisses back to that Library
tab. This materializer therefore also gives the production TabView an explicit selection and
routes a successful reprocess action to the Scan tab, where the restored ScanModel phase is
rendered.

Runs after apply_s13_depth_seed.py. Every transformation is idempotent and fails closed if the
expected generated source shape drifts.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY_PATH = ROOT / "SplatNative" / "ScanLibraryView.swift"
SHELL_PATH = ROOT / "SplatNative" / "IntegratedScanLabShellView.swift"

library = LIBRARY_PATH.read_text()
shell = SHELL_PATH.read_text()

list_marker = "S13 iOS 26 tap routing: reprocess is a separate List row"
route_call = "NotificationCenter.default.post(name: .scanLabRouteToScanForReprocess, object: nil)"

# The main S13 materializer originally emits the trusted NavigationLink and reprocess Button in
# one List row. Move the reprocess action to its own row exactly once.
if list_marker not in library:
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
                                    NotificationCenter.default.post(name: .scanLabRouteToScanForReprocess, object: nil)
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
else:
    # Upgrade an already materialized Build-11 source during the second idempotence pass.
    if route_call not in library:
        old_action = """                                    model.restoreFinishedProjectForS13Reprocess(id: project.id)
                                    dismiss()
"""
        new_action = f"""                                    model.restoreFinishedProjectForS13Reprocess(id: project.id)
                                    {route_call}
                                    dismiss()
"""
        if old_action not in library:
            raise SystemExit("S13 route: separate-row reprocess action drifted")
        library = library.replace(old_action, new_action, 1)

# A Build-11 same-raw tap has already transitioned the target project to the resumable
# captured/failed path, which is exposed as "生成へ戻る" / "保存状態から復旧". Route that generic
# continuation to Scan as well, otherwise the current physical evidence would remain trapped in
# the Library hub even after the same-raw button itself is fixed.
continue_marker = "S13 same-raw routing: continued project returns to Scan tab"
if continue_marker not in library:
    old_continue = """            model.restoreSavedProject(id: project.id)
            dismiss()
"""
    new_continue = f"""            model.restoreSavedProject(id: project.id)
            // {continue_marker}
            {route_call}
            dismiss()
"""
    if old_continue not in library:
        raise SystemExit("S13 route: continueProject callsite drifted")
    library = library.replace(old_continue, new_continue, 1)

# Production Library and Scan are sibling TabView tabs. Give the shell explicit selection and
# listen for the same-raw route signal. This works both from the Library hub and from ScanHomeView:
# selecting Scan is a no-op when already selected, and dismiss() still closes the local library.
route_marker = "S13 same-raw routing: switch the production shell to Scan"
if route_marker not in shell:
    old_prefix = """import SwiftUI

/// HQ composition that makes the locally durable Splat/Mesh libraries part of the production shell.
"""
    new_prefix = """import SwiftUI

extension Notification.Name {
    static let scanLabRouteToScanForReprocess = Notification.Name("jp.allsunday1122.splatlab.route.scan.reprocess")
}

private enum IntegratedScanLabTab: Hashable {
    case scan
    case library
    case map
    case discover
    case account
}

/// HQ composition that makes the locally durable Splat/Mesh libraries part of the production shell.
"""
    if old_prefix not in shell:
        raise SystemExit("S13 route: integrated shell prefix drifted")
    shell = shell.replace(old_prefix, new_prefix, 1)

    old_state = """    @EnvironmentObject private var meshModel: MeshScanModel
    @StateObject private var meshDurability = MeshDurabilityCoordinator()

    var body: some View {
        TabView {
"""
    new_state = """    @EnvironmentObject private var meshModel: MeshScanModel
    @StateObject private var meshDurability = MeshDurabilityCoordinator()
    @State private var selectedTab: IntegratedScanLabTab = .scan

    var body: some View {
        TabView(selection: $selectedTab) {
"""
    if old_state not in shell:
        raise SystemExit("S13 route: integrated shell state/TabView callsite drifted")
    shell = shell.replace(old_state, new_state, 1)

    replacements = [
        (
            """            IntegratedScanTab()
                .tabItem { Label("Scan", systemImage: "viewfinder") }
""",
            """            IntegratedScanTab()
                .tabItem { Label("Scan", systemImage: "viewfinder") }
                .tag(IntegratedScanLabTab.scan)
""",
        ),
        (
            """            ScanLabLibraryHubView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
""",
            """            ScanLabLibraryHubView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(IntegratedScanLabTab.library)
""",
        ),
        (
            """            ScanLabMapView()
                .tabItem { Label("Map", systemImage: "map") }
""",
            """            ScanLabMapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(IntegratedScanLabTab.map)
""",
        ),
        (
            """            ScanLabDiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles.rectangle.stack") }
""",
            """            ScanLabDiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles.rectangle.stack") }
                .tag(IntegratedScanLabTab.discover)
""",
        ),
        (
            """            ScanLabAccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
""",
            """            ScanLabAccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(IntegratedScanLabTab.account)
""",
        ),
    ]
    for old, new in replacements:
        if old not in shell:
            raise SystemExit("S13 route: integrated shell tab callsite drifted")
        shell = shell.replace(old, new, 1)

    old_tint = """        .tint(.mint)
        .preferredColorScheme(.dark)
"""
    new_tint = """        // S13 same-raw routing: switch the production shell to Scan after restore.
        .onReceive(NotificationCenter.default.publisher(for: .scanLabRouteToScanForReprocess)) { _ in
            selectedTab = .scan
        }
        .tint(.mint)
        .preferredColorScheme(.dark)
"""
    if old_tint not in shell:
        raise SystemExit("S13 route: integrated shell modifier callsite drifted")
    shell = shell.replace(old_tint, new_tint, 1)

# Final fail-closed assertions cover both physical fixes.
required_library = [
    list_marker,
    route_call,
    continue_marker,
    'Label("同じ撮影から再生成", systemImage: "arrow.triangle.2.circlepath")',
]
for token in required_library:
    if token not in library:
        raise SystemExit(f"S13 route: missing library marker {token!r}")

required_shell = [
    route_marker,
    "TabView(selection: $selectedTab)",
    ".tag(IntegratedScanLabTab.scan)",
    ".tag(IntegratedScanLabTab.library)",
    ".onReceive(NotificationCenter.default.publisher(for: .scanLabRouteToScanForReprocess))",
]
for token in required_shell:
    if token not in shell:
        raise SystemExit(f"S13 route: missing shell marker {token!r}")

LIBRARY_PATH.write_text(library)
SHELL_PATH.write_text(shell)
print("S13 same-raw reprocess: independent List row + Scan-tab routing materialized")
