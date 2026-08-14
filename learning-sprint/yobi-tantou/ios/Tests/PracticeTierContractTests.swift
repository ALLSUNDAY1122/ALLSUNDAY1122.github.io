import XCTest
@testable import YobiTantouSprint

@MainActor
final class PracticeTierContractTests: XCTestCase {
    func testFormalPracticeBankHasThreeBalancedAuditedTiers() {
        let model = AppModel(bundle: Bundle(for: AppBundleToken.self))

        XCTAssertNil(model.startupError)
        XCTAssertEqual(model.questions.count, 42)
        XCTAssertEqual(model.questions.filter { $0.difficulty == .foundation }.count, 14)
        XCTAssertEqual(model.questions.filter { $0.difficulty == .standard }.count, 14)
        XCTAssertEqual(model.questions.filter { $0.difficulty == .applied }.count, 14)
        XCTAssertTrue(model.questions.allSatisfy {
            $0.releaseEligible &&
            $0.contentUse == .practice &&
            $0.examYear == nil &&
            !$0.isOfficialMockQuestion
        })
    }

    func testEveryTierCoversAllSevenLegalSubjectsTwice() {
        let model = AppModel(bundle: Bundle(for: AppBundleToken.self))
        let legalSubjects = Set(AppModel.officialSubjects).subtracting([AppModel.generalEducationSubject])

        for difficulty in QuestionDifficulty.allCases {
            let tierQuestions = model.questions.filter { $0.difficulty == difficulty }
            XCTAssertEqual(tierQuestions.count, 14)
            for subject in legalSubjects {
                XCTAssertEqual(
                    tierQuestions.filter { $0.subject == subject }.count,
                    2,
                    "\(difficulty.rawValue) must contain exactly two \(subject) questions"
                )
            }
        }
    }
}
