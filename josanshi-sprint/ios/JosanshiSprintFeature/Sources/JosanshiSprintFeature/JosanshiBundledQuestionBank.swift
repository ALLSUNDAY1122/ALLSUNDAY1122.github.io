import Foundation

public enum JosanshiBundledQuestionBankError: Error, Equatable, LocalizedError {
    case resourceMissing
    case notFullyAudited(String)
    case invalidQuestionCount(Int)
    case invalidScenarioCount(Int)
    case unapprovedQuestion(String)
    case unapprovedScenario(String)

    public var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "監査済み問題データが見つかりません。"
        case .notFullyAudited(let status):
            return "問題データがFULL監査済みではありません: \(status)"
        case .invalidQuestionCount(let count):
            return "問題数が330問ではありません: \(count)"
        case .invalidScenarioCount(let count):
            return "症例数が36症例ではありません: \(count)"
        case .unapprovedQuestion(let id):
            return "独立監査未完了の問題があります: \(id)"
        case .unapprovedScenario(let id):
            return "独立監査未完了の症例があります: \(id)"
        }
    }
}

public extension JosanshiQuestionBankLoader {
    static func bundled() throws -> JosanshiQuestionBankDocument {
        guard let url = Bundle.module.url(forResource: "questions", withExtension: "json") else {
            throw JosanshiBundledQuestionBankError.resourceMissing
        }
        let document = try decode(Data(contentsOf: url))
        guard document.status == "audited" else {
            throw JosanshiBundledQuestionBankError.notFullyAudited(document.status)
        }
        guard document.questions.count == JosanshiExamConfiguration.originalProductionQuestionTarget else {
            throw JosanshiBundledQuestionBankError.invalidQuestionCount(document.questions.count)
        }
        guard document.scenarios.count == JosanshiExamConfiguration.originalScenarioCaseTarget else {
            throw JosanshiBundledQuestionBankError.invalidScenarioCount(document.scenarios.count)
        }
        if let question = document.questions.first(where: { $0.auditStatus != "pass" }) {
            throw JosanshiBundledQuestionBankError.unapprovedQuestion(question.id)
        }
        if let scenario = document.scenarios.first(where: { $0.auditStatus != "pass" }) {
            throw JosanshiBundledQuestionBankError.unapprovedScenario(scenario.scenarioId)
        }
        return document
    }
}
