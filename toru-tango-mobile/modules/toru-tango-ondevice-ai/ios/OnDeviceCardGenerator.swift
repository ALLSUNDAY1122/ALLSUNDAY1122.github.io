import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum CardGenerationEngine: String, Sendable {
  case appleOnDeviceModel
  case deterministicFallback
}

public struct CardGenerationResult: Sendable {
  public let cards: [StudyCard]
  public let engine: CardGenerationEngine
  public let notices: [String]

  public init(cards: [StudyCard], engine: CardGenerationEngine, notices: [String] = []) {
    self.cards = cards
    self.engine = engine
    self.notices = notices
  }
}

public enum OnDeviceCardGeneratorError: LocalizedError {
  case emptyText
  case generationInProgress
  case noUsableCard

  public var errorDescription: String? {
    switch self {
    case .emptyText:
      return "認識した文章が空です。撮影範囲またはOCR結果を確認してください。"
    case .generationInProgress:
      return "現在、別の作問処理を実行中です。"
    case .noUsableCard:
      return "単語帳にできる内容を抽出できませんでした。"
    }
  }
}

public actor OnDeviceCardGenerator {
  public init() {}

  public func generate(from request: CardGenerationRequest) async throws -> CardGenerationResult {
    let cleaned = TextPreprocessor.clean(request.recognizedText)
    guard !cleaned.isEmpty else { throw OnDeviceCardGeneratorError.emptyText }

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
      do {
        let cards = try await generateWithAppleModel(cleanedText: cleaned, request: request)
        let filtered = CardQualityFilter.filter(
          cards,
          sourceText: cleaned,
          maximumCount: request.maximumCardCount,
          prohibitedQuestions: request.prohibitedQuestions
        )
        if !filtered.isEmpty {
          return CardGenerationResult(cards: filtered, engine: .appleOnDeviceModel)
        }

        let fallback = generateFallback(cleanedText: cleaned, request: request)
        guard !fallback.isEmpty else { throw OnDeviceCardGeneratorError.noUsableCard }
        return CardGenerationResult(
          cards: fallback,
          engine: .deterministicFallback,
          notices: ["端末内AIの結果が品質基準を満たさなかったため、ルールベース作問へ切り替えました。"]
        )
      } catch {
        let fallback = generateFallback(cleanedText: cleaned, request: request)
        guard !fallback.isEmpty else { throw error }
        return CardGenerationResult(
          cards: fallback,
          engine: .deterministicFallback,
          notices: [
            "端末内AIの作問に失敗したため、ルールベース作問へ切り替えました。",
            error.localizedDescription
          ]
        )
      }
    }
    #endif

    let fallback = generateFallback(cleanedText: cleaned, request: request)
    guard !fallback.isEmpty else { throw OnDeviceCardGeneratorError.noUsableCard }
    return CardGenerationResult(
      cards: fallback,
      engine: .deterministicFallback,
      notices: ["Apple Intelligenceの端末内モデルを利用できないため、ルールベース作問を使用しました。"]
    )
  }

  private func generateFallback(
    cleanedText: String,
    request: CardGenerationRequest
  ) -> [StudyCard] {
    DeterministicCardGenerator.generate(
      text: cleanedText,
      maximumCount: request.maximumCardCount,
      subjectHint: request.subjectHint,
      prohibitedQuestions: request.prohibitedQuestions
    )
  }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private extension OnDeviceCardGenerator {
  @Generable
  struct GeneratedDeck {
    @Guide(description: "重複しない学習カード。原文に根拠があるものだけ。", .maximumCount(20))
    var cards: [GeneratedCard]
  }

  @Generable
  struct GeneratedCard {
    @Guide(description: "15秒程度で答えられる、意味が一つに定まる短い問題文")
    var question: String
    @Guide(description: "原文から導ける簡潔な正答")
    var answer: String
    @Guide(description: "正答の理由を初心者向けに1〜3文で説明")
    var explanation: String
    @Guide(description: "問題と答えの根拠になった原文の短い抜粋")
    var evidence: String
    @Guide(description: "0.0から1.0の確信度", .range(0.0...1.0))
    var confidence: Double
    @Guide(description: "分類用の短いタグ", .maximumCount(4))
    var tags: [String]
  }

  func generateWithAppleModel(
    cleanedText: String,
    request: CardGenerationRequest
  ) async throws -> [StudyCard] {
    let session = LanguageModelSession(
      model: SystemLanguageModel.default,
      instructions: """
      あなたは日本語教材から短時間学習用の単語帳を作る編集者です。
      原文にない知識を補わず、問題・答え・解説のすべてを原文に根拠づけてください。
      OCR誤認識らしい断片、ページ番号、飾り文字、意味のない記号は無視してください。
      問題は一問一答形式にし、一つの問題に複数の論点を入れないでください。
      同じ答えや同義の問題を重複させないでください。
      曖昧な代名詞を避け、単独で意味が通じる問題文にしてください。
      """
    )
    let subject = request.subjectHint ?? "指定なし"
    let excluded = request.prohibitedQuestions.isEmpty
      ? "なし"
      : request.prohibitedQuestions.joined(separator: "\n- ")
    let prompt = """
    次のOCR文章から、最大\(request.maximumCardCount)問の学習カードを作成してください。

    科目のヒント: \(subject)
    難易度: \(request.difficulty.rawValue)

    作成対象外の既存問題:
    - \(excluded)

    品質条件:
    - 根拠が不明なカードは作らない
    - 問題は原則45文字以内
    - 答えは原則60文字以内
    - 解説は結論を先に書く
    - confidenceが0.65未満になりそうなカードは除外
    - OCRの誤字を推測で直した場合は、根拠が明確な場合だけ採用

    OCR文章:
    \(String(cleanedText.prefix(12_000)))
    """
    let response = try await session.respond(to: prompt, generating: GeneratedDeck.self)
    return response.content.cards.map {
      StudyCard(
        question: $0.question.trimmingCharacters(in: .whitespacesAndNewlines),
        answer: $0.answer.trimmingCharacters(in: .whitespacesAndNewlines),
        explanation: $0.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
        sourceText: $0.evidence.trimmingCharacters(in: .whitespacesAndNewlines),
        confidence: $0.confidence,
        tags: $0.tags
      )
    }
  }
}
#endif
