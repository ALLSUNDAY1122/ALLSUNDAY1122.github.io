import Foundation

enum DeterministicCardGenerator {
  static func generate(
    text: String,
    maximumCount: Int,
    subjectHint: String?,
    prohibitedQuestions: [String]
  ) -> [StudyCard] {
    let sentences = splitSentences(text)
    var cards: [StudyCard] = []
    let prohibited = Set(prohibitedQuestions.map(normalize))
    var seenAnswers = Set<String>()

    for sentence in sentences {
      guard let pair = extractDefinition(from: sentence) else { continue }
      let question = "\(pair.term)とは何ですか？"
      let questionKey = normalize(question)
      let answerKey = normalize(pair.definition)
      guard !prohibited.contains(questionKey) else { continue }
      guard !seenAnswers.contains(answerKey) else { continue }

      seenAnswers.insert(answerKey)
      cards.append(
        StudyCard(
          question: question,
          answer: pair.definition,
          explanation: "\(pair.term)の定義として、原文では「\(pair.definition)」と説明されています。",
          sourceText: sentence,
          confidence: 0.72,
          tags: [subjectHint].compactMap { $0 }
        )
      )
      if cards.count >= maximumCount { break }
    }

    return cards
  }

  private static func splitSentences(_ text: String) -> [String] {
    text
      .replacingOccurrences(of: "\n", with: "。")
      .components(separatedBy: CharacterSet(charactersIn: "。！？!?"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.count >= 8 && $0.count <= 240 }
  }

  private static func extractDefinition(from sentence: String) -> (term: String, definition: String)? {
    let patterns = [
      #"^(.{2,35}?)(?:とは|は)、?(.{4,140})$"#,
      #"^(.{2,35}?)を(.{4,140}?という)$"#,
      #"^(.{2,35}?)：(.{4,140})$"#,
      #"^(.{2,35}?):(.{4,140})$"#
    ]

    for pattern in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
      let range = NSRange(sentence.startIndex..., in: sentence)
      guard let match = regex.firstMatch(in: sentence, range: range),
        match.numberOfRanges >= 3,
        let termRange = Range(match.range(at: 1), in: sentence),
        let definitionRange = Range(match.range(at: 2), in: sentence) else {
        continue
      }
      let term = String(sentence[termRange]).trimmingCharacters(in: .whitespacesAndNewlines)
      let definition = String(sentence[definitionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard term.count >= 2, definition.count >= 4 else { continue }
      return (term, definition)
    }
    return nil
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
