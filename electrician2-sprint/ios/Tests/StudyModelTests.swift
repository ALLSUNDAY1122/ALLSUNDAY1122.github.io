import XCTest
@testable import Electrician2Sprint

final class StudyModelTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testThreeConsecutiveCorrectAnswersGraduateWeakQuestion() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(1); model.answer((model.current!.answer + 1) % 4)
        XCTAssertTrue(model.weakIDs.contains(1))
        for _ in 0..<3 {
            model.start(1, weakOnly: true)
            model.answer(model.current!.answer)
        }
        XCTAssertFalse(model.weakIDs.contains(1))
        XCTAssertTrue(model.graduatedIDs.contains(1))
        XCTAssertEqual(model.weakStreak[1], 3)
    }

    func testWrongAnswerResetsStreakAndRemovesGraduation() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(1); model.answer((model.current!.answer + 1) % 4)
        model.start(1, weakOnly: true); model.answer(model.current!.answer)
        model.start(1, weakOnly: true); model.answer(0)
        XCTAssertEqual(model.weakStreak[1], 2)
        model.start(1, weakOnly: true); model.answer((model.current!.answer + 1) % 4)
        XCTAssertEqual(model.weakStreak[1], 0)
        XCTAssertTrue(model.weakIDs.contains(1))
        XCTAssertFalse(model.graduatedIDs.contains(1))
    }

    func testLearningStatePersistsAcrossModelRecreation() {
        let defaults = makeDefaults()
        let first = StudyModel(defaults: defaults)
        first.goal = 16
        first.fontScale = 2
        first.start(1); first.answer((first.current!.answer + 1) % 4)
        let restored = StudyModel(defaults: defaults)
        XCTAssertEqual(restored.goal, 16)
        XCTAssertEqual(restored.fontScale, 2)
        XCTAssertEqual(restored.completed, 1)
        XCTAssertEqual(restored.correct, 0)
        XCTAssertTrue(restored.weakIDs.contains(1))
        XCTAssertEqual(restored.answeredIDs, [1])
    }

    func testWeakOnlySessionDoesNotFallbackWhenEmpty() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(8, weakOnly: true)
        XCTAssertTrue(model.session.isEmpty)
        XCTAssertFalse(model.showQuestion)
    }

    func testBackupJSONRoundTripsLearningData() throws {
        let defaults = makeDefaults()
        let first = StudyModel(defaults: defaults)
        first.goal = 16
        first.fontScale = 2
        first.start(1)
        first.answer(1)
        let backup = try first.backupData()

        let restored = StudyModel(defaults: makeDefaults())
        try restored.restoreBackup(backup)
        XCTAssertEqual(restored.goal, 16)
        XCTAssertEqual(restored.fontScale, 2)
        XCTAssertEqual(restored.completed, 1)
        XCTAssertTrue(restored.weakIDs.contains(1))
    }

    func testQuestionBankSchemaDecodesAndValidates() throws {
        let json = """
        {
          "schemaVersion":"1.0",
          "dataSet":"E2-ALL-2022-2026",
          "sourceFiles":{"questionPdf":"multiple","answerPdf":"multiple"},
          "questionCount":1,
          "questions":[{
            "id":"E2-2026-U-001",
            "exam":"令和8年度第二種電気工事士上期学科試験",
            "examDate":"2026-05-24",
            "section":"一般問題",
            "questionNumber":1,
            "question":"テスト問題",
            "choices":[
              {"label":"イ","text":"選択肢1"},
              {"label":"ロ","text":"選択肢2"},
              {"label":"ハ","text":"選択肢3"},
              {"label":"ニ","text":"選択肢4"}
            ],
            "answerOfficial":"イ",
            "hereToRemember":null,
            "explanation":null,
            "source":{"title":"公式問題","url":"https://example.com/q.pdf","page":5,"figure":null},
            "audit":{"transcription":"転記","answer":"正答照合","figureStatus":"図版なし","independentReview":"未実施","releaseStatus":"PENDING_SOURCE_AND_VISUAL_AUDIT"}
          }]
        }
        """
        let bank = try JSONDecoder().decode(QuestionBankFile.self, from: Data(json.utf8))
        XCTAssertNoThrow(try QuestionBankLoader.validate(bank))
    }

}
