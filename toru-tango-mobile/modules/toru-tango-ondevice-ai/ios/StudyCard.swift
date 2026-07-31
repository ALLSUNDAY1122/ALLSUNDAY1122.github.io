import Foundation

public struct StudyCard: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var question: String
  public var answer: String
  public var explanation: String
  public var sourceText: String
  public var confidence: Double
  public var tags: [String]

  public init(
    id: UUID = UUID(),
    question: String,
    answer: String,
    explanation: String,
    sourceText: String,
    confidence: Double,
    tags: [String] = []
  ) {
    self.id = id
    self.question = question
    self.answer = answer
    self.explanation = explanation
    self.sourceText = sourceText
    self.confidence = min(max(confidence, 0), 1)
    self.tags = tags
  }
}

public enum CardDifficulty: String, Codable, Sendable, CaseIterable {
  case easy
  case normal
  case hard
}

public struct CardGenerationRequest: Sendable {
  public var recognizedText: String
  public var maximumCardCount: Int
  public var difficulty: CardDifficulty
  public var subjectHint: String?
  public var prohibitedQuestions: [String]

  public init(
    recognizedText: String,
    maximumCardCount: Int = 8,
    difficulty: CardDifficulty = .normal,
    subjectHint: String? = nil,
    prohibitedQuestions: [String] = []
  ) {
    self.recognizedText = recognizedText
    self.maximumCardCount = min(max(maximumCardCount, 1), 20)
    self.difficulty = difficulty
    self.subjectHint = subjectHint
    self.prohibitedQuestions = prohibitedQuestions
  }
}
