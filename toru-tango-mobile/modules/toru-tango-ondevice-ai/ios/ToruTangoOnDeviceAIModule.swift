import ExpoModulesCore
import Foundation

public final class ToruTangoOnDeviceAIModule: Module {
  private let generator = OnDeviceCardGenerator()

  public func definition() -> ModuleDefinition {
    Name("ToruTangoOnDeviceAI")

    Function("availabilityStatus") {
      Self.statusValue(OnDeviceAIAvailability.currentStatus())
    }

    AsyncFunction("generateCards") {
      (
        recognizedText: String,
        maximumCardCount: Int,
        difficultyValue: String,
        subjectHint: String?,
        prohibitedQuestions: [String]
      ) async throws -> [String: Any] in
      let difficulty = CardDifficulty(rawValue: difficultyValue) ?? .normal
      let request = CardGenerationRequest(
        recognizedText: recognizedText,
        maximumCardCount: maximumCardCount,
        difficulty: difficulty,
        subjectHint: subjectHint,
        prohibitedQuestions: prohibitedQuestions
      )
      let result = try await self.generator.generate(from: request)

      return [
        "cards": result.cards.map(Self.cardValue),
        "engine": result.engine.rawValue,
        "notices": result.notices
      ]
    }
  }

  private static func cardValue(_ card: StudyCard) -> [String: Any] {
    [
      "id": card.id.uuidString,
      "question": card.question,
      "answer": card.answer,
      "explanation": card.explanation,
      "sourceText": card.sourceText,
      "confidence": card.confidence,
      "tags": card.tags
    ]
  }

  private static func statusValue(_ status: OnDeviceAIStatus) -> String {
    switch status {
    case .available:
      return "available"
    case .unsupportedOS:
      return "unsupportedOS"
    case .deviceNotEligible:
      return "deviceNotEligible"
    case .appleIntelligenceDisabled:
      return "appleIntelligenceDisabled"
    case .modelNotReady:
      return "modelNotReady"
    case .unavailable:
      return "unavailable"
    }
  }
}
