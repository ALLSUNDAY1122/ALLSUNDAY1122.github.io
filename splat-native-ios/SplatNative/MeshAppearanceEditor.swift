import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import SceneKit
import SwiftUI

private struct MeshAppearanceEditResult: Sendable {
    let objURL: URL
    let textureURL: URL
}

private enum MeshAppearanceProcessor {
    static func apply(objURL: URL, exposure: Double, contrast: Double, saturation: Double, sharpness: Double) throws -> MeshAppearanceEditResult {
        guard exposure.isFinite, contrast.isFinite, saturation.isFinite, sharpness.isFinite,
              (-1.5...1.5).contains(exposure), (0.7...1.5).contains(contrast),
              (0...1.6).contains(saturation), (0...1.5).contains(sharpness) else {
            throw error("編集値が不正です")
        }
        let directory = objURL.deletingLastPathComponent()
        _ = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: objURL)
        guard let mtlName = try MeshTextReferenceRewriter.firstReference(in: objURL, directive: "mtllib") else { throw error("MTL参照がありません") }
        let mtlURL = directory.appendingPathComponent(mtlName)
        guard let textureName = try MeshTextReferenceRewriter.firstReference(in: mtlURL, directive: "map_Kd") else { throw error("テクスチャ参照がありません") }
        let textureURL = directory.appendingPathComponent(textureName)
        guard let input = CIImage(contentsOf: textureURL) else { throw error("テクスチャ画像を開けません") }

        let exposureFilter = CIFilter.exposureAdjust(); exposureFilter.inputImage = input; exposureFilter.ev = Float(exposure)
        let color = CIFilter.colorControls(); color.inputImage = exposureFilter.outputImage; color.contrast = Float(contrast); color.saturation = Float(saturation)
        let sharpen = CIFilter.sharpenLuminance(); sharpen.inputImage = color.outputImage; sharpen.sharpness = Float(sharpness)
        guard let output = sharpen.outputImage, let cs = CGColorSpace(name: CGColorSpace.sRGB) else { throw error("画像フィルタを適用できません") }

        let visual = objURL.lastPathComponent.lowercased().contains("visual")
        let basePrefix = visual ? "visual-mesh-textured-edited" : "mesh-textured-edited"
        let prefix = "\(basePrefix)-\(UUID().uuidString.lowercased())"
        let editedTexture = directory.appendingPathComponent(prefix + ".jpg")
        let editedMTL = directory.appendingPathComponent(prefix + ".mtl")
        let editedOBJ = directory.appendingPathComponent(prefix + ".obj")
        var committed = false
        defer {
            if !committed {
                try? FileManager.default.removeItem(at: editedTexture)
                try? FileManager.default.removeItem(at: editedMTL)
                try? FileManager.default.removeItem(at: editedOBJ)
            }
        }

        let context = CIContext(options: [.cacheIntermediates:false])
        try context.writeJPEGRepresentation(of: output, to: editedTexture, colorSpace: cs, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.94])
        try MeshTextReferenceRewriter.rewrite(sourceURL: mtlURL, destinationURL: editedMTL, directive: "map_Kd", replacement: editedTexture.lastPathComponent)
        try MeshTextReferenceRewriter.rewrite(sourceURL: objURL, destinationURL: editedOBJ, directive: "mtllib", replacement: editedMTL.lastPathComponent)
        try synchronize(editedTexture)
        try synchronize(editedMTL)
        try synchronize(editedOBJ)
        committed = true
        return MeshAppearanceEditResult(objURL: editedOBJ, textureURL: editedTexture)
    }

    static func discard(_ result: MeshAppearanceEditResult) {
        let mtlURL = result.objURL.deletingPathExtension().appendingPathExtension("mtl")
        try? FileManager.default.removeItem(at: result.textureURL)
        try? FileManager.default.removeItem(at: mtlURL)
        try? FileManager.default.removeItem(at: result.objURL)
    }

    static func discardSupersededGeneration(at objURL: URL?) {
        guard let objURL else { return }
        let stem = objURL.deletingPathExtension().lastPathComponent
        guard stem.hasPrefix("mesh-textured-edited-") || stem.hasPrefix("visual-mesh-textured-edited-") else { return }
        let base = objURL.deletingPathExtension()
        try? FileManager.default.removeItem(at: base.appendingPathExtension("jpg"))
        try? FileManager.default.removeItem(at: base.appendingPathExtension("mtl"))
        try? FileManager.default.removeItem(at: objURL)
    }

    private static func synchronize(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func error(_ text:String)->NSError{NSError(domain:"ScanLab.MeshAppearance",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
}

@MainActor
struct MeshAppearanceEditorSheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var exposure = 0.0
    @State private var contrast = 1.0
    @State private var saturation = 1.0
    @State private var sharpness = 0.35
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                control("露出", value:$exposure, range:-1.5...1.5, format:String(format:"%+.1f EV",exposure))
                control("コントラスト", value:$contrast, range:0.7...1.5, format:String(format:"%.2f×",contrast))
                control("彩度", value:$saturation, range:0...1.6, format:String(format:"%.2f×",saturation))
                control("シャープ", value:$sharpness, range:0...1.5, format:String(format:"%.2f",sharpness))
                if let errorText { Section { Text(errorText).foregroundStyle(.red) } }
                Section { Button(working ? "適用中…" : "実テクスチャへ適用") { apply() }.disabled(working) }
            }
            .navigationTitle("見た目を編集")
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("閉じる") { dismiss() }.disabled(working) } }
        }
        .interactiveDismissDisabled(working)
    }

    private func control(_ title:String, value:Binding<Double>, range:ClosedRange<Double>, format:String)->some View {
        Section(title) { HStack { Text(title); Spacer(); Text(format).monospacedDigit().foregroundStyle(.secondary) }; Slider(value:value,in:range) }
    }

    private func apply() {
        working=true; errorText=nil; let url=sourceURL, e=exposure,c=contrast,s=saturation,sh=sharpness
        Task {
            do {
                let result = try await Task.detached(priority:.userInitiated){ try MeshAppearanceProcessor.apply(objURL:url, exposure:e, contrast:c, saturation:s, sharpness:sh) }.value
                guard let candidateScene = try? SCNScene(url: result.objURL, options: nil) else {
                    MeshAppearanceProcessor.discard(result)
                    throw NSError(domain: "ScanLab.MeshAppearance", code: 2, userInfo: [NSLocalizedDescriptionKey: "編集後のMeshを検証できませんでした。直前の結果を保持します。"])
                }
                let previousURL = model.resultURL
                let previousScene = model.previewScene
                let previousStatus = model.statusMessage
                model.resultURL = result.objURL
                model.previewScene = candidateScene
                do { try model.persistExporterMeshAssetContract() }
                catch {
                    model.resultURL = previousURL
                    model.previewScene = previousScene
                    model.statusMessage = previousStatus
                    MeshAppearanceProcessor.discard(result)
                    throw error
                }
                if previousURL != result.objURL { MeshAppearanceProcessor.discardSupersededGeneration(at: previousURL) }
                model.statusMessage="露出・コントラスト・彩度・シャープを実テクスチャへ反映しました"
                working=false
                dismiss()
            } catch { working=false; errorText=error.localizedDescription }
        }
    }
}