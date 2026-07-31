import Testing
@testable import ToruTangoOnDeviceAI

@Test
func deterministicFallbackGeneratesDefinitionCard() {
  let cards = DeterministicCardGenerator.generate(
    text: "就業不能保障とは、病気やけがで働けない状態に備える保障です。",
    maximumCount: 3,
    subjectHint: "資格学習",
    prohibitedQuestions: []
  )

  #expect(cards.count == 1)
  #expect(cards[0].question == "就業不能保障とは何ですか？")
  #expect(cards[0].answer.contains("働けない状態"))
  #expect(cards[0].confidence >= 0.65)
}

@Test
func duplicateQuestionIsExcludedFromFallback() {
  let cards = DeterministicCardGenerator.generate(
    text: "就業不能保障とは、病気やけがで働けない状態に備える保障です。",
    maximumCount: 3,
    subjectHint: nil,
    prohibitedQuestions: ["就業不能保障とは何ですか？"]
  )

  #expect(cards.isEmpty)
}

@Test
func preprocessorRemovesDuplicateAndNoiseLines() {
  let cleaned = TextPreprocessor.clean("""
  -------
  国内総生産とは国内で生産された付加価値の合計です。
  国内総生産とは国内で生産された付加価値の合計です。
  """)

  #expect(cleaned == "国内総生産とは国内で生産された付加価値の合計です。")
}

@Test
func qualityFilterRejectsLowConfidenceAndExistingQuestion() {
  let source = "国内総生産とは国内で生産された付加価値の合計です。"
  let candidates = [
    StudyCard(
      question: "国内総生産とは何ですか？",
      answer: "国内で生産された付加価値の合計",
      explanation: "国内で生み出された付加価値を合計した指標です。",
      sourceText: source,
      confidence: 0.9
    ),
    StudyCard(
      question: "GDPの意味は何ですか？",
      answer: "国内総生産",
      explanation: "国内総生産を示す略称です。",
      sourceText: source,
      confidence: 0.4
    )
  ]

  let filtered = CardQualityFilter.filter(
    candidates,
    sourceText: source,
    maximumCount: 10,
    prohibitedQuestions: ["国内総生産とは何ですか？"]
  )

  #expect(filtered.isEmpty)
}

@Test
func emptyTextThrows() async {
  let generator = OnDeviceCardGenerator()

  await #expect(throws: OnDeviceCardGeneratorError.self) {
    try await generator.generate(
      from: CardGenerationRequest(recognizedText: " \n -- ")
    )
  }
}

@Test
func duplicateAnswerIsExcluded() {
  let source = "国内総生産とは国内で生産された付加価値の合計です。"
  let candidates = [
    StudyCard(
      question: "国内総生産とは何ですか？",
      answer: "国内で生産された付加価値の合計",
      explanation: "国内の付加価値を合計した指標です。",
      sourceText: source,
      confidence: 0.9
    ),
    StudyCard(
      question: "国内で生産された価値の総額を何と説明しますか？",
      answer: "国内で生産された付加価値の合計",
      explanation: "同じ定義を別の聞き方にしたものです。",
      sourceText: source,
      confidence: 0.9
    )
  ]

  let filtered = CardQualityFilter.filter(
    candidates,
    sourceText: source,
    maximumCount: 10,
    prohibitedQuestions: []
  )

  #expect(filtered.count == 1)
}

@Test
func fallbackDoesNotExceedMaximumCount() {
  let cards = DeterministicCardGenerator.generate(
    text: """
    国内総生産とは国内で生産された付加価値の合計です。
    国民総所得とは国民が得た所得の合計です。
    消費者物価指数とは消費者が購入する商品の価格変動を示す指標です。
    """,
    maximumCount: 2,
    subjectHint: nil,
    prohibitedQuestions: []
  )

  #expect(cards.count == 2)
}

@Test
func unavailableModelUsesFallbackWhenDefinitionExists() async throws {
  let status = OnDeviceAIAvailability.currentStatus()
  guard status != .available else { return }

  let generator = OnDeviceCardGenerator()
  let result = try await generator.generate(
    from: CardGenerationRequest(
      recognizedText: "就業不能保険とは、病気やけがで働けない状態に備える保険です。"
    )
  )

  #expect(result.engine == .deterministicFallback)
  #expect(!result.cards.isEmpty)
}
