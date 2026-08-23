import XCTest
@testable import YobiTantouSprint

final class QuestionContentUseGateTests: XCTestCase {
    private func releaseQuestion(
        id: String = "RELEASE-001",
        examYear: Int? = nil,
        contentUse: QuestionContentUse? = .practice,
        originType: String = "original_from_primary_source",
        difficulty: QuestionDifficulty? = .foundation
    ) -> StudyQuestion {
        StudyQuestion(
            id: id,
            examYear: examYear,
            subject: "憲法",
            topic: "用途分離テスト",
            stem: "練習問題と公式年度模試を混同しないための構造テスト。",
            choices: ["A", "B"],
            correctIndices: [0],
            explanation: "構造テスト説明。",
            memory: "用途を分離する。",
            sourceTitle: "一次資料",
            sourceURL: "https://example.invalid/primary",
            evidenceCheckedDate: "2026-08-14",
            lawBasisDate: "2026-01-01",
            originType: originType,
            releaseEligible: true,
            contentUse: contentUse,
            difficulty: difficulty
        )
    }

    private func data(_ questions: [StudyQuestion]) throws -> Data {
        try JSONEncoder().encode(questions)
    }

    func testPracticeReleaseRequiresNoOfficialExamYear() throws {
        let decoded = try QuestionRepository().decode(
            try data([releaseQuestion()]),
            kind: .release
        )

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].contentUse, .practice)
        XCTAssertEqual(decoded[0].difficulty, .foundation)
        XCTAssertNil(decoded[0].examYear)
        XCTAssertTrue(decoded[0].isPracticeQuestion)
        XCTAssertFalse(decoded[0].isOfficialMockQuestion)
    }

    func testPracticeReleaseRejectsFakeOfficialExamYear() throws {
        XCTAssertThrowsError(
            try QuestionRepository().decode(
                try data([releaseQuestion(examYear: 2026)]),
                kind: .release
            )
        ) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("RELEASE-001"))
        }
    }

    func testOfficialMockCannotEnterOrdinaryPracticeBank() throws {
        XCTAssertThrowsError(
            try QuestionRepository().decode(
                try data([
                    releaseQuestion(
                        examYear: 2024,
                        contentUse: .officialMock,
                        originType: "official_exam_reproduced"
                    )
                ]),
                kind: .release
            )
        ) { error in
            XCTAssertEqual(
                error as? QuestionBankError,
                .officialMockRequiresDedicatedBank("RELEASE-001")
            )
        }
    }

    func testReleaseRejectsMissingContentUse() throws {
        XCTAssertThrowsError(
            try QuestionRepository().decode(
                try data([releaseQuestion(contentUse: nil)]),
                kind: .release
            )
        ) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("RELEASE-001"))
        }
    }

    func testReleaseRejectsMissingDifficulty() throws {
        XCTAssertThrowsError(
            try QuestionRepository().decode(
                try data([releaseQuestion(difficulty: nil)]),
                kind: .release
            )
        ) { error in
            XCTAssertEqual(error as? QuestionBankError, .invalidReleaseGate("RELEASE-001"))
        }
    }
}
