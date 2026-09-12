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
        let directory = objURL.deletingLastPathComponent()
        let obj = try String(contentsOf: objURL, encoding: .utf8)
        guard let mtlName = obj.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("mtllib ") }).map({ String($0.dropFirst(7)) }) else { throw error("MTL参照がありません") }
        let mtlURL = directory.appendingPathComponent(mtlName.trimmingCharacters(in: .whitespaces))
        var mtl = try String(contentsOf: mtlURL, encoding: .utf8)
        guard let textureName = mtl.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("map_Kd ") }).map({ String($0.dropFirst(7)).trimmingCharacters(in: .whitespaces) }) else { throw error("テクスチャ参照がありません") }
        let textureURL = directory.appendingPathComponent(textureName)
        guard let input = CIImage(contentsOf: textureURL) else { throw error("テクスチャ画像を開けません") }

        let exposureFilter = CIFilter.exposureAdjust(); exposureFilter.inputImage = input; exposureFilter.ev = Float(exposure)
        let color = CIFilter.colorControls(); color.inputImage = exposureFilter.outputImage; color.contrast = Float(contrast); color.saturation = Float(saturation)
        let sharpen = CIFilter.sharpenLuminance(); sharpen.inputImage = color.outputImage; sharpen.sharpness = Float(sharpness)
        guard let output = sharpen.outputImage, let cs = CGColorSpace(name: CGColorSpace.sRGB) else { throw error("画像フィルタを適用できません") }

        let visual = objURL.lastPathComponent.lowercased().contains("visual")
        let prefix = visual ? "visual-mesh-textured-edited" : "mesh-textured-edited"
        let editedTexture = directory.appendingPathComponent(prefix + ".jpg")
        let context = CIContext(options: [.cacheIntermediates:false])
        try context.writeJPEGRepresentation(of: output, to: editedTexture, colorSpace: cs, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.94])

        let editedMTL = directory.appendingPathComponent(prefix + ".mtl")
        mtl = mtl.split(whereSeparator: \.isNewline).map { line in line.hasPrefix("map_Kd ") ? "map_Kd \(editedTexture.lastPathComponent)" : String(line) }.joined(separator:"\n") + "\n"
        try mtl.write(to: editedMTL, atomically: true, encoding: .utf8)

        let editedOBJ = directory.appendingPathComponent(prefix + ".obj")
        let newOBJ = obj.split(whereSeparator: \.isNewline).map { line in line.hasPrefix("mtllib ") ? "mtllib \(editedMTL.lastPathComponent)" : String(line) }.joined(separator:"\n") + "\n"
        try newOBJ.write(to: editedOBJ, atomically: true, encoding: .utf8)
        return MeshAppearanceEditResult(objURL: editedOBJ, textureURL: editedTexture)
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
            .toolbar { ToolbarItem(placement:.topBarTrailing){Button("閉じる"){dismiss()}} }
        }
    }

    private func control(_ title:String, value:Binding<Double>, range:ClosedRange<Double>, format:String)->some View {
        Section(title) { HStack { Text(title); Spacer(); Text(format).monospacedDigit().foregroundStyle(.secondary) }; Slider(value:value,in:range) }
    }

    private func apply() {
        working=true; errorText=nil; let url=sourceURL, e=exposure,c=contrast,s=saturation,sh=sharpness
        Task {
            do {
                let result = try await Task.detached(priority:.userInitiated){ try MeshAppearanceProcessor.apply(objURL:url, exposure:e, contrast:c, saturation:s, sharpness:sh) }.value
                model.resultURL=result.objURL; model.previewScene=try? SCNScene(url:result.objURL,options:nil); model.statusMessage="露出・コントラスト・彩度・シャープを実テクスチャへ反映しました"; try? model.persistExporterMeshAssetContract(); working=false; dismiss()
            } catch { working=false; errorText=error.localizedDescription }
        }
    }
}
