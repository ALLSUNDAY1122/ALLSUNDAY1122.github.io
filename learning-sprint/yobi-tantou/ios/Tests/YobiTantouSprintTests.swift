import XCTest
@testable import YobiTantouSprint

@MainActor
final class YobiTantouSprintTests: XCTestCase {
    private func freshModel() -> AppModel {
        let model = AppModel(bundle: Bundle(for: AppBundleToken.self))
        model.state = PersistentState()
        model.activeSession = nil
        model.lastResult = nil
        return model
    }

    private func releaseQuestion(
        id: String = "YOBI-RELEASE-001",
        subject: String = "憲法",
        releaseEligible: Bool = true,
        lawBasisDate: String? = "2026-01-01",
        difficulty: QuestionDifficulty? = .foundation
    ) -> StudyQuestion {
        StudyQuestion(
            id: id,
            examYear: nil,
            subject: subject,
            topic: "テスト用正式教材ゲート",
            stem: "正式教材バンクの構造テストです。",
            choices: ["正しい", "誤り"],
            correctIndices: [0],
            explanation: "テスト用の説明です。",
            memory: "テスト用の要点です。",
            sourceTitle: "一次資料テスト",
            sourceURL: "https://example.invalid/primary",
            evidenceCheckedDate: "2026-08-14",
            lawBasisDate: lawBasisDate,
            originType: "original_from_primary_source",
            releaseEligible: releaseEligible,
            contentUse: .practice,
            difficulty: difficulty
        )
    }

    func testPreviewFixtureStillHasEightNonReleaseQuestions() throws {
        let bundle = Bundle(for: AppBundleToken.self)
        guard let url = bundle.url(forResource: "questions.preview", withExtension: "json") else {
            return XCTFail("preview resource missing")
        }
        let decoded = try QuestionRepository().decode(Data(contentsOf: url), kind: .preview)
        XCTAssertEqual(decoded.count, 8)
        XCTAssertTrue(decoded.allSatisfy {
            !$0.releaseEligible && $0.originType == "original_preview" && $0.contentUse == nil && $0.difficulty == nil
        })
    }

    func testBundledFormalPracticeBankLoadsTwentyEightReleasedQuestionsAcrossTwoTiers() {
        let model = freshModel()
        XCTAssertNil(model.startupError)
        XCTAssertEqual(model.questions.count, 28)
        XCTAssertTrue(model.questions.allSatisfy {
            $0.releaseEligible && $0.contentUse == .practice && $0.examYear == nil && !$0.isOfficialMockQuestion
        })
        XCTAssertFalse(model.isPreviewBank)
        XCTAssertEqual(
            Set(model.questions.map(\.subject)).intersection(Set(AppModel.officialSubjects)).count,
            7
        )
        XCTAssertEqual(model.questions.filter { $0.difficulty == .foundation }.count, 14)
        XCTAssertEqual(model.questions.filter { $0.difficulty == .standard }.count, 14)
        XCTAssertEqual(model.questions.filter { $0.difficulty == .applied }.count, 0)
    }

    func testReleaseRepositoryAcceptsAuditedDifficulty() throws {
        let data = try JSONEncoder().encode([releaseQuestion(difficulty: .standard)])
        let decoded = try QuestionRepository().decode(data, kind: .release)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertTrue(decoded[0].releaseEligible)
        XCTAssertEqual(decoded[0].contentUse, .practice)
        XCTAssertEqual(decoded[0].difficulty, .standard)
        XCTAssertNil(decoded[0].examYear)
    }

    func testReleaseRepositoryRejectsMissingDifficulty() throws {
        let data = try JSONEncoder().encode([releaseQuestion(difficulty: nil)])
        XCTAssertThrowsError(try QuestionRepository().decode(data, kind: .release)) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("YOBI-RELEASE-001"))
        }
    }

    func testReleaseRepositoryRejectsNonReleaseQuestion() throws {
        let data = try JSONEncoder().encode([releaseQuestion(releaseEligible: false)])
        XCTAssertThrowsError(try QuestionRepository().decode(data, kind: .release)) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("YOBI-RELEASE-001"))
        }
    }

    func testReleaseRepositoryRejectsMissingLawBasisDateForLegalSubject() throws {
        let data = try JSONEncoder().encode([releaseQuestion(lawBasisDate: nil)])
        XCTAssertThrowsError(try QuestionRepository().decode(data, kind: .release)) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("YOBI-RELEASE-001"))
        }
    }

    func testReleaseRepositoryAllowsGeneralEducationWithoutLawBasisDate() throws {
        let data = try JSONEncoder().encode([releaseQuestion(subject: "一般教養", lawBasisDate: nil)])
        let decoded = try QuestionRepository().decode(data, kind: .release)
        XCTAssertEqual(decoded.first?.subject, "一般教養")
        XCTAssertNil(decoded.first?.lawBasisDate)
        XCTAssertEqual(decoded.first?.contentUse, .practice)
        XCTAssertEqual(decoded.first?.difficulty, .foundation)
    }

    func testReleaseRepositoryRejectsDuplicateIDs() throws {
        let question = releaseQuestion()
        let data = try JSONEncoder().encode([question, question])
        XCTAssertThrowsError(try QuestionRepository().decode(data, kind: .release)) { error in
            XCTAssertEqual(error as? QuestionBankError, .duplicateID("YOBI-RELEASE-001"))
        }
    }

    func testWeakQuestionClearsAfterThreeConsecutiveCorrectAnswers() {
        let model = freshModel()
        guard let question = model.questions.first else { return XCTFail("release question missing") }
        model.state.attempts[question.id] = AttemptState(answered: 1, correct: 0, consecutiveCorrect: 0, weak: true, unknown: false)

        for expected in 1...3 {
            XCTAssertTrue(model.start(.weak, premium: true))
            XCTAssertEqual(model.currentQuestion?.id, question.id)
            model.answer(selectedIndices: Set(question.correctIndices))
            XCTAssertEqual(model.state.attempts[question.id]?.consecutiveCorrect, expected)
        }
        XCTAssertEqual(model.state.attempts[question.id]?.weak, false)
    }

    func testResumePreservesCorrectCount() {
        let model = freshModel()
        XCTAssertTrue(model.start(.daily, premium: true))
        guard let question = model.currentQuestion else { return XCTFail("question missing") }
        model.answer(selectedIndices: Set(question.correctIndices))
        XCTAssertEqual(model.state.resume?.correct, 1)

        model.activeSession = nil
        XCTAssertTrue(model.resume(premium: true))
        XCTAssertEqual(model.activeSession?.correct, 1)
        XCTAssertEqual(model.activeSession?.index, 1)
    }

    func testPremiumOnlySessionCannotResumeAfterEntitlementLoss() {
        let model = freshModel()
        guard let question = model.questions.first else { return XCTFail("release question missing") }
        model.state.attempts[question.id] = AttemptState(answered: 1, correct: 0, consecutiveCorrect: 0, weak: true, unknown: false)
        XCTAssertTrue(model.start(.weak, premium: true))
        XCTAssertEqual(model.state.resume?.requiresPremium, true)
        model.activeSession = nil

        XCTAssertFalse(model.resume(premium: false))
        XCTAssertNil(model.activeSession)
    }

    func testFreeSprintIsConsumedAtStartAndSameSessionCanResume() {
        let model = freshModel()
        XCTAssertFalse(model.state.freeSprintConsumed)
        XCTAssertTrue(model.start(.daily, premium: false))
        XCTAssertTrue(model.state.freeSprintConsumed)
        XCTAssertEqual(model.state.resume?.consumesFreeSprint, true)
        let originalIDs = model.activeSession?.ids
        model.activeSession = nil

        XCTAssertTrue(model.resume(premium: false))
        XCTAssertEqual(model.activeSession?.ids, originalIDs)
        XCTAssertEqual(model.activeSession?.consumesFreeSprint, true)
    }

    func testPartialFreeSprintCannotBeAbandonedForNewFreeSprint() {
        let model = freshModel()
        XCTAssertTrue(model.start(.daily, premium: false))
        model.activeSession = nil
        model.state.resume = nil

        XCTAssertFalse(model.start(.daily, premium: false))
    }

    func testDailySessionStartedAsPremiumCanResumeAsFreeAndConsumesTrial() {
        let model = freshModel()
        XCTAssertTrue(model.start(.daily, premium: true))
        XCTAssertFalse(model.state.freeSprintConsumed)
        XCTAssertEqual(model.state.resume?.requiresPremium, false)
        model.activeSession = nil

        XCTAssertTrue(model.resume(premium: false))
        XCTAssertTrue(model.state.freeSprintConsumed)
        XCTAssertEqual(model.activeSession?.requiresPremium, false)
        XCTAssertEqual(model.activeSession?.consumesFreeSprint, true)
        XCTAssertEqual(model.state.resume?.consumesFreeSprint, true)
    }

    func testConsumedFreeSprintBlocksPremiumStartedDailyResumeWithoutPremium() {
        let model = freshModel()
        XCTAssertTrue(model.start(.daily, premium: true))
        model.activeSession = nil
        model.state.freeSprintConsumed = true

        XCTAssertFalse(model.resume(premium: false))
    }

    func testLegacyResumeWithoutRequiresPremiumStillDecodesSafely() throws {
        let json = #"{"questionIDs":["Q1","Q2"],"index":1,"correct":1,"title":"苦手をつぶす","consumesFreeSprint":false}"#.data(using: .utf8)!
        let resume = try JSONDecoder().decode(ResumeState.self, from: json)
        XCTAssertNil(resume.requiresPremium)
        XCTAssertTrue(resume.resolvedRequiresPremium)
    }

    func testBackupCannotRestoreConsumedFreeSprint() throws {
        let model = freshModel()
        model.state.freeSprintConsumed = false
        let oldBackup = try model.backupData()
        model.state.freeSprintConsumed = true

        try model.importBackup(oldBackup)
        XCTAssertTrue(model.state.freeSprintConsumed)
    }

    func testResetCannotRestoreConsumedFreeSprint() {
        let model = freshModel()
        model.state.freeSprintConsumed = true
        model.state.totalAnswered = 50
        model.resetLearningData()
        XCTAssertTrue(model.state.freeSprintConsumed)
        XCTAssertEqual(model.state.totalAnswered, 0)
    }

    func testBackupRejectsImpossibleCounts() throws {
        let model = freshModel()
        var invalid = PersistentState()
        invalid.totalAnswered = 1
        invalid.totalCorrect = 2
        let payload = BackupPayload(schemaVersion: 1, exportedAt: Date(), state: invalid)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        XCTAssertThrowsError(try model.importBackup(data))
    }

    func testBackupRejectsInvalidResumeProgress() throws {
        let model = freshModel()
        var invalid = PersistentState()
        invalid.resume = ResumeState(
            questionIDs: ["Q1", "Q2"],
            index: 1,
            correct: 2,
            title: "今日のスプリント",
            consumesFreeSprint: true,
            requiresPremium: false
        )
        let payload = BackupPayload(schemaVersion: 1, exportedAt: Date(), state: invalid)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        XCTAssertThrowsError(try model.importBackup(data))
    }

    func testBackupRejectsOversizedPayload() {
        let model = freshModel()
        XCTAssertThrowsError(try model.importBackup(Data(repeating: 0x20, count: 5 * 1024 * 1024 + 1)))
    }
}
