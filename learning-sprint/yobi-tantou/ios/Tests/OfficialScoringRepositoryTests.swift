import XCTest
@testable import YobiTantouSprint

final class OfficialScoringRepositoryTests: XCTestCase {
    private func loadCanonical() throws -> OfficialScoringCanonical {
        try OfficialScoringRepository.load(bundle: Bundle(for: AppBundleToken.self))
    }

    func testBundledCanonicalLoadsAndMatchesVerifiedExamContracts() throws {
        let canonical = try loadCanonical()
        let r6 = try OfficialScoringRepository.scoring(for: 2024, canonical: canonical)
        let r7 = try OfficialScoringRepository.scoring(for: 2025, canonical: canonical)

        XCTAssertEqual(r6.legal.questionCount, 95)
        XCTAssertEqual(r6.legal.maxPoints, 210)
        XCTAssertEqual(r6.generalEducation.offered, 42)
        XCTAssertEqual(r6.generalEducation.select, 20)
        XCTAssertEqual(r6.generalEducation.maxPoints, 60)
        XCTAssertEqual(r6.totalMaxPoints, 270)
        XCTAssertEqual(r6.officialPassScore, 165)

        XCTAssertEqual(r7.legal.questionCount, 95)
        XCTAssertEqual(r7.legal.maxPoints, 210)
        XCTAssertEqual(r7.generalEducation.offered, 44)
        XCTAssertEqual(r7.generalEducation.select, 20)
        XCTAssertEqual(r7.generalEducation.maxPoints, 60)
        XCTAssertEqual(r7.totalMaxPoints, 270)
        XCTAssertEqual(r7.officialPassScore, 159)
    }

    func testBundledCanonicalPreservesOfficialUnorderedPartialCreditRule() throws {
        let canonical = try loadCanonical()
        let r6 = try OfficialScoringRepository.scoring(for: 2024, canonical: canonical)
        guard let question = r6.legal.questions.first(where: {
            $0.subject == "民事訴訟法" && $0.questionNumber == 32
        }) else {
            return XCTFail("R6 民事訴訟法第32問の採点正本がありません")
        }

        XCTAssertEqual(question.maxPoints, 2)
        XCTAssertEqual(question.responseGroups.first?.orderSensitive, false)
        XCTAssertEqual(question.scoreBands, [
            OfficialScoreBand(minimumCorrect: 2, points: 2),
            OfficialScoreBand(minimumCorrect: 1, points: 1)
        ])

        guard let group = question.responseGroups.first,
              group.slotIDs.count == 2,
              group.correctOptions.count == 2 else {
            return XCTFail("R6 民事訴訟法第32問の解答欄構造が不正です")
        }

        let oneCorrect = [group.slotIDs[0]: group.correctOptions[0]]
        XCTAssertEqual(question.score(responses: oneCorrect), 1)

        let swapped = [
            group.slotIDs[0]: group.correctOptions[1],
            group.slotIDs[1]: group.correctOptions[0]
        ]
        XCTAssertEqual(question.score(responses: swapped), 2)
    }

    func testBundledCanonicalPreservesOfficialUnorderedNoPartialCreditRule() throws {
        let canonical = try loadCanonical()
        let r7 = try OfficialScoringRepository.scoring(for: 2025, canonical: canonical)
        guard let question = r7.legal.questions.first(where: {
            $0.subject == "刑法" && $0.questionNumber == 4
        }) else {
            return XCTFail("R7 刑法第4問の採点正本がありません")
        }

        XCTAssertEqual(question.maxPoints, 3)
        XCTAssertEqual(question.responseGroups.first?.orderSensitive, false)
        XCTAssertEqual(question.scoreBands, [OfficialScoreBand(minimumCorrect: 2, points: 3)])

        guard let group = question.responseGroups.first,
              group.slotIDs.count == 2,
              group.correctOptions.count == 2 else {
            return XCTFail("R7 刑法第4問の解答欄構造が不正です")
        }

        XCTAssertEqual(question.score(responses: [group.slotIDs[0]: group.correctOptions[0]]), 0)
        XCTAssertEqual(question.score(responses: [
            group.slotIDs[0]: group.correctOptions[1],
            group.slotIDs[1]: group.correctOptions[0]
        ]), 3)
    }
}
