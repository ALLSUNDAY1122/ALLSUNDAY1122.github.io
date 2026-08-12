import XCTest
@testable import JosanshiSprintFeature

final class JosanshiSprintFeatureTests: XCTestCase {
    func testGoldenMasterSprintTargetsAreFixed() {
        XCTAssertEqual(JosanshiExamConfiguration.standardSprintCount, 8)
        XCTAssertEqual(JosanshiExamConfiguration.selectableDailyTargets, [4, 8, 16])
    }

    func testOfficialSubjectsAreExactlyTheCurrentFour() {
        XCTAssertEqual(
            JosanshiExamConfiguration.subjects,
            ["基礎助産学", "助産診断・技術学", "地域母子保健", "助産管理"]
        )
    }

    func testLatestConfirmedStructureAndThreeMockTarget() {
        XCTAssertEqual(JosanshiExamConfiguration.latestConfirmedExamRound, 109)
        XCTAssertEqual(JosanshiExamConfiguration.morningQuestionCount, 55)
        XCTAssertEqual(JosanshiExamConfiguration.afternoonQuestionCount, 55)
        XCTAssertEqual(JosanshiExamConfiguration.latestConfirmedQuestionCount, 110)
        XCTAssertEqual(JosanshiExamConfiguration.generalQuestionCountPerMock, 75)
        XCTAssertEqual(JosanshiExamConfiguration.situationQuestionCountPerMock, 35)
        XCTAssertEqual(JosanshiExamConfiguration.scenarioCaseCountPerMock, 12)
        XCTAssertEqual(JosanshiExamConfiguration.originalProductionQuestionTarget, 330)
        XCTAssertEqual(JosanshiExamConfiguration.originalGeneralQuestionTarget, 225)
        XCTAssertEqual(JosanshiExamConfiguration.originalSituationQuestionTarget, 105)
        XCTAssertEqual(JosanshiExamConfiguration.originalScenarioCaseTarget, 36)
    }

    func testProductionIdentifiersRemainUnsetUntilCanonicalValuesExist() {
        let ids = JosanshiExamConfiguration.productionIdentifiers
        XCTAssertNil(ids.bundleID)
        XCTAssertNil(ids.appStoreConnectAppID)
        XCTAssertNil(ids.productID)
        XCTAssertFalse(ids.isReleaseIdentityReady)
        XCTAssertFalse(ids.isStoreKitReady)
    }

    @MainActor
    func testInvalidDailyTargetIsRejected() {
        let model = JosanshiDashboardModel()
        model.setDailyTarget(16)
        XCTAssertEqual(model.dailyTarget, 16)

        model.setDailyTarget(12)
        XCTAssertEqual(model.dailyTarget, 16)
    }

    @MainActor
    func testSubjectRequestOnlyAcceptsOfficialSubject() {
        let model = JosanshiDashboardModel()
        model.requestSubjectPractice("助産管理")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertTrue(model.isContentGatePresented)

        model.isContentGatePresented = false
        model.requestSubjectPractice("未定義科目")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertFalse(model.isContentGatePresented)
    }
}
