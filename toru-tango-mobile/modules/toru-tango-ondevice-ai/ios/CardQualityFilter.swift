import Foundation

enum CardQualityFilter {
  static func filter(
    _ cards: [StudyCard],
    sourceText: String,
    maximumCount: Int,
    prohibitedQuestions: [String]
  ) -> [StudyCard] {
    var result: [StudyCard] = []
    var normalizedQuestions = Set(prohibitedQuestions.map(normalize))
    var normalizedAnswers = Set<String>()

    for var card in cards {
      card.question = card.question.trimmingCharacters(in: .whitespacesAndNewlines)
      card.answer = card.answer.trimmingCharacters(in: .whitespacesAndNewlines)
      card.explanation = card.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
      card.sourceText = card.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

      guard card.confidence >= 0.65 else { continue }
      guard card.question.count >= 4, card.question.count <= 80 else { continue }
      guard card.answer.count >= 1, card.answer.count <= 140 else { continue }
      guard card.explanation.count >= 4 else { continue }
      guard !card.sourceText.isEmpty else { continue }

      let questionKey = normalize(card.question)
      let answerKey = normalize(card.answer)
      guard !normalizedQuestions.contains(questionKey) else { continue }
      guard !normalizedAnswers.contains(answerKey) else { continue }
      guard evidenceLooksRelated(card.sourceText, to: sourceText) else { continue }

      normalizedQuestions.insert(questionKey)
      normalizedAnswers.insert(answerKey)
      result.append(card)
      if result.count >= maximumCount { break }
    }

    return result
  }

  private static func evidenceLooksRelated(_ evidence: String, to source: String) -> Bool {
    let evidenceTokens = tokens(evidence)
    let sourceNormalized = normalize(source)
    guard !evidenceTokens.isEmpty else { return false }
    let matched = evidenceTokens.filter {
      $0.count >= 2 && sourceNormalized.contains($0)
    }
    return Double(matched.count) / Double(evidenceTokens.count) >= 0.35
  }

  private static func tokens(_ value: String) -> [String] {
    value
      .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
      .map(normalize)
      .filter { !$0.isEmpty }
  }

  private static func normalize(_ value: String) -> String {
    value
      .precomposedStringWithCompatibilityMapping
      .lowercased()
      .replacingOccurrences(
        of: #"[\s。、，,.・:：;；!?！？「」『』（）()\[\]【】\-ー_]"#,
        with: "",
        options: .regularExpression
      )
  }
}
