import Foundation
import SwiftUI

public enum JosanshiFeatureTab: Hashable, Sendable {
    case home
    case mock
    case history
    case settings
}

@MainActor
public final class JosanshiDashboardModel: ObservableObject {
    @Published public var selectedTab: JosanshiFeatureTab = .home
    @Published public private(set) var dailyTarget = JosanshiExamConfiguration.standardSprintCount
    @Published public var selectedSubject: String?
    @Published public var isContentGatePresented = false

    public init() {}

    public func setDailyTarget(_ value: Int) {
        guard JosanshiExamConfiguration.selectableDailyTargets.contains(value) else { return }
        dailyTarget = value
    }

    public func requestStandardSprint() {
        selectedSubject = nil
        isContentGatePresented = true
    }

    public func requestSubjectPractice(_ subject: String) {
        guard JosanshiExamConfiguration.subjects.contains(subject) else { return }
        selectedSubject = subject
        isContentGatePresented = true
    }

    public var productionQuestionTargetText: String {
        "全\(JosanshiExamConfiguration.originalProductionQuestionTarget)問（独自模試3回分）"
    }
}
