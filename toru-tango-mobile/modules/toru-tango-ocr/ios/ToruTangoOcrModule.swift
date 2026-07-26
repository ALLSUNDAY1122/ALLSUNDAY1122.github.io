import ExpoModulesCore
import Foundation
import ImageIO
import Vision

public final class ToruTangoOcrModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ToruTangoOcr")

    AsyncFunction("recognizeText") { (uri: String, requestedRotation: Int) throws -> [String: Any] in
      guard let url = Self.fileURL(from: uri) else {
        throw NSError(
          domain: "ToruTangoOcr",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "画像ファイルを開けませんでした。"]
        )
      }

      let candidates = requestedRotation >= 0
        ? [Self.normalizedRotation(requestedRotation)]
        : [0, 90, 180, 270]

      var bestText = ""
      var bestLines: [String] = []
      var bestRotation = candidates[0]
      var bestScore = -Double.infinity

      for rotation in candidates {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.minimumTextHeight = 0.006

        let handler = VNImageRequestHandler(
          url: url,
          orientation: Self.imageOrientation(for: rotation),
          options: [:]
        )
        try handler.perform([request])

        let observations = (request.results ?? []).sorted { left, right in
          let verticalDifference = abs(left.boundingBox.midY - right.boundingBox.midY)
          if verticalDifference > 0.018 {
            return left.boundingBox.midY > right.boundingBox.midY
          }
          return left.boundingBox.minX < right.boundingBox.minX
        }

        let lines = observations.compactMap { observation in
          observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        let text = lines.joined(separator: "\n")
        let score = Self.recognitionScore(text: text, lines: lines)
        if score > bestScore {
          bestScore = score
          bestText = text
          bestLines = lines
          bestRotation = rotation
        }
      }

      guard !bestText.isEmpty, bestScore > 20 else {
        throw NSError(
          domain: "ToruTangoOcr",
          code: 2,
          userInfo: [
            NSLocalizedDescriptionKey: "文字を十分に認識できませんでした。紙面を正面から明るく撮影してください。"
          ]
        )
      }

      return [
        "text": bestText,
        "lines": bestLines,
        "rotation": bestRotation,
        "score": bestScore
      ]
    }
  }

  private static func fileURL(from value: String) -> URL? {
    if let url = URL(string: value), url.isFileURL {
      return url
    }
    if value.hasPrefix("/") {
      return URL(fileURLWithPath: value)
    }
    return nil
  }

  private static func normalizedRotation(_ value: Int) -> Int {
    let normalized = ((value % 360) + 360) % 360
    switch normalized {
    case 90, 180, 270:
      return normalized
    default:
      return 0
    }
  }

  private static func imageOrientation(for rotation: Int) -> CGImagePropertyOrientation {
    switch normalizedRotation(rotation) {
    case 90:
      return .right
    case 180:
      return .down
    case 270:
      return .left
    default:
      return .up
    }
  }

  private static func recognitionScore(text: String, lines: [String]) -> Double {
    var japanese = 0
    var digits = 0
    var latin = 0
    var noise = 0

    for scalar in text.unicodeScalars {
      switch scalar.value {
      case 0x3040...0x30ff, 0x3400...0x9fff:
        japanese += 1
      case 0x30...0x39:
        digits += 1
      case 0x41...0x5a, 0x61...0x7a:
        latin += 1
      case 0x7c, 0x5f, 0x3c, 0x3e, 0x5c:
        noise += 1
      default:
        break
      }
    }

    let meaningfulLines = lines.filter { line in
      line.unicodeScalars.filter { scalar in
        switch scalar.value {
        case 0x3040...0x30ff, 0x3400...0x9fff, 0x30...0x39:
          return true
        default:
          return false
        }
      }.count >= 3
    }.count

    return Double(japanese * 5 + digits + meaningfulLines * 18)
      - Double(latin) * 0.2
      - Double(noise) * 1.5
  }
}
