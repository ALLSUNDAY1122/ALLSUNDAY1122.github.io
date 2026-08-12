import Foundation
import LearningSprintCore

public enum HokenshiQuestionType: String, Codable, Sendable {
    case general
    case situational
}

public enum HokenshiAuditStatus: String, Codable, Sendable {
    case planned
    case drafted
    case structurePassed = "structure_passed"
    case evidencePassed = "evidence_passed"
    case contentPassed = "content_passed"
    case releaseReady = "release_ready"

    public var isProductEligible: Bool {
        self == .releaseReady
    }
}

public struct HokenshiQuestionRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let round: Int
    public let questionNumber: Int
    public let subject: String
    public let topic: String
    public let questionType: HokenshiQuestionType
    public let taxonomy: String
    public let scenarioID: String?
    public let scenarioIndex: Int?
    public let scenarioTotal: Int?
    public let scenarioText: String?
    public let answerType: LearningAnswerType
    public let prompt: String
    public let choices: [String]
    public let correctIndices: [Int]
    public let correctNumber: Double?
    public let acceptedRange: Double?
    public let unit: String?
    public let roundingRule: String?
    public let explanation: String
    public let memoryPoint: String
    public let sourceTitle: String
    public let sourceURL: String
    public let sourceRefs: [String]
    public let sourceCheckedAt: String
    public let lawBaselineDate: String
    public let contentVersion: String
    public let rightsBasis: String
    public let originType: String
    public let auditStatus: HokenshiAuditStatus
    public let premium: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case round
        case questionNumber = "question_number"
        case subject
        case topic
        case questionType = "question_type"
        case taxonomy
        case scenarioID = "scenario_id"
        case scenarioIndex = "scenario_index"
        case scenarioTotal = "scenario_total"
        case scenarioText = "scenario_text"
        case answerType = "answer_type"
        case prompt = "question"
        case choices
        case correctIndices = "correct_indices"
        case correctNumber = "correct_number"
        case acceptedRange = "accepted_range"
        case unit
        case roundingRule = "rounding_rule"
        case explanation
        case memoryPoint = "memory_point"
        case sourceTitle = "source_title"
        case sourceURL = "source_url"
        case sourceRefs = "source_refs"
        case sourceCheckedAt = "source_checked_at"
        case lawBaselineDate = "law_baseline_date"
        case contentVersion = "content_version"
        case rightsBasis = "rights_basis"
        case originType = "origin_type"
        case auditStatus = "audit_status"
        case premium
    }

    public init(
        id: String,
        round: Int,
        questionNumber: Int,
        subject: String,
        topic: String,
        questionType: HokenshiQuestionType,
        taxonomy: String,
        scenarioID: String? = nil,
        scenarioIndex: Int? = nil,
        scenarioTotal: Int? = nil,
        scenarioText: String? = nil,
        answerType: LearningAnswerType,
        prompt: String,
        choices: [String],
        correctIndices: [Int] = [],
        correctNumber: Double? = nil,
        acceptedRange: Double? = nil,
        unit: String? = nil,
        roundingRule: String? = nil,
        explanation: String,
        memoryPoint: String,
        sourceTitle: String,
        sourceURL: String,
        sourceRefs: [String],
        sourceCheckedAt: String,
        lawBaselineDate: String,
        contentVersion: String,
        rightsBasis: String,
        originType: String = "original_from_primary_source",
        auditStatus: HokenshiAuditStatus,
        premium: Bool = false
    ) {
        self.id = id
        self.round = round
        self.questionNumber = questionNumber
        self.subject = subject
        self.topic = topic
        self.questionType = questionType
        self.taxonomy = taxonomy
        self.scenarioID = scenarioID
        self.scenarioIndex = scenarioIndex
        self.scenarioTotal = scenarioTotal
        self.scenarioText = scenarioText
        self.answerType = answerType
        self.prompt = prompt
        self.choices = choices
        self.correctIndices = correctIndices
        self.correctNumber = correctNumber
        self.acceptedRange = acceptedRange
        self.unit = unit
        self.roundingRule = roundingRule
        self.explanation = explanation
        self.memoryPoint = memoryPoint
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sourceRefs = sourceRefs
        self.sourceCheckedAt = sourceCheckedAt
        self.lawBaselineDate = lawBaselineDate
        self.contentVersion = contentVersion
        self.rightsBasis = rightsBasis
        self.originType = originType
        self.auditStatus = auditStatus
        self.premium = premium
    }

    public var coreQuestion: LearningQuestion {
        LearningQuestion(
            id: id,
            subject: subject,
            topic: topic,
            answerType: answerType,
            prompt: prompt,
            choices: choices,
            correctIndices: correctIndices,
            correctNumber: correctNumber,
            acceptedRange: acceptedRange,
            unit: unit,
            roundingRule: roundingRule,
            memoryPoint: memoryPoint,
            explanation: explanation,
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            sourceRefs: sourceRefs,
            sourceCheckedAt: sourceCheckedAt,
            lawBaselineDate: lawBaselineDate,
            contentVersion: contentVersion,
            premium: premium,
            examRound: "独自模試 第\(round)回",
            questionNumber: String(questionNumber),
            rightsBasis: rightsBasis
        )
    }

    public var hasValidScenarioMetadata: Bool {
        switch questionType {
        case .general:
            return scenarioID == nil && scenarioIndex == nil && scenarioTotal == nil
        case .situational:
            guard let scenarioID, !scenarioID.isEmpty,
                  let scenarioIndex,
                  let scenarioTotal
            else { return false }
            guard scenarioTotal == 2 || scenarioTotal == 3 else { return false }
            return (1...scenarioTotal).contains(scenarioIndex)
        }
    }

    public var hasValidAnswerShape: Bool {
        switch answerType {
        case .singleChoice:
            guard choices.count >= 2, correctIndices.count == 1, correctNumber == nil else { return false }
            return choices.indices.contains(correctIndices[0])
        case .multiChoice:
            guard choices.count >= 2, correctIndices.count >= 2, correctNumber == nil else { return false }
            let unique = Set(correctIndices)
            guard unique.count == correctIndices.count else { return false }
            return correctIndices.allSatisfy { choices.indices.contains($0) }
        case .numeric:
            return correctNumber != nil && correctIndices.isEmpty
        case .blankSelect, .declaration:
            return false
        }
    }
}

public enum HokenshiContentStoreError: Error, Equatable {
    case invalidTotal(Int)
    case invalidRound(Int, Int)
    case invalidQuestionNumbers(Int)
    case invalidSubjectCount(Int, String, Int)
    case invalidQuestionTypeCount(Int, String, Int)
    case invalidScenarioPlan(Int)
    case duplicateID(String)
    case invalidScenario(String)
    case invalidAnswer(String)
    case unreleasedContent(String)
}

public struct HokenshiContentStore: Sendable {
    public let allRecords: [HokenshiQuestionRecord]

    public init(records: [HokenshiQuestionRecord], requireReleaseReady: Bool = true) throws {
        if records.count != HokenshiSprintConfiguration.plannedIndependentQuestionCount {
            throw HokenshiContentStoreError.invalidTotal(records.count)
        }

        var seen = Set<String>()
        for record in records {
            if !seen.insert(record.id).inserted {
                throw HokenshiContentStoreError.duplicateID(record.id)
            }
            if !record.hasValidScenarioMetadata {
                throw HokenshiContentStoreError.invalidScenario(record.id)
            }
            if !record.hasValidAnswerShape {
                throw HokenshiContentStoreError.invalidAnswer(record.id)
            }
            if requireReleaseReady && !record.auditStatus.isProductEligible {
                throw HokenshiContentStoreError.unreleasedContent(record.id)
            }
        }

        for round in 1...HokenshiSprintConfiguration.plannedMockExamCount {
            let roundRecords = records.filter { $0.round == round }
            if roundRecords.count != HokenshiSprintConfiguration.questionsPerMockExam {
                throw HokenshiContentStoreError.invalidRound(round, roundRecords.count)
            }

            let questionNumbers = roundRecords.map(\.questionNumber).sorted()
            if questionNumbers != Array(1...HokenshiSprintConfiguration.questionsPerMockExam) {
                throw HokenshiContentStoreError.invalidQuestionNumbers(round)
            }

            for subject in HokenshiExamBlueprint.current.subjects {
                let count = roundRecords.filter { $0.subject == subject }.count
                if count != HokenshiSprintConfiguration.plannedQuestionsPerSubjectPerMock {
                    throw HokenshiContentStoreError.invalidSubjectCount(round, subject, count)
                }
            }

            let generalCount = roundRecords.filter { $0.questionType == .general }.count
            if generalCount != HokenshiExamBlueprint.current.generalQuestions {
                throw HokenshiContentStoreError.invalidQuestionTypeCount(round, "general", generalCount)
            }
            let situationalCount = roundRecords.filter { $0.questionType == .situational }.count
            if situationalCount != HokenshiExamBlueprint.current.situationalQuestions {
                throw HokenshiContentStoreError.invalidQuestionTypeCount(round, "situational", situationalCount)
            }

            let scenarioGroups = Dictionary(grouping: roundRecords.filter { $0.questionType == .situational }) { $0.scenarioID ?? "" }
            let scenarioSizes = scenarioGroups.values.map(\.count).sorted()
            if scenarioGroups.count != 12 || scenarioSizes != [2] + Array(repeating: 3, count: 11) {
                throw HokenshiContentStoreError.invalidScenarioPlan(round)
            }
            for (_, group) in scenarioGroups {
                let expectedTotal = group.count
                let indexes = group.compactMap(\.scenarioIndex).sorted()
                let totals = Set(group.compactMap(\.scenarioTotal))
                if indexes != Array(1...expectedTotal) || totals != [expectedTotal] {
                    throw HokenshiContentStoreError.invalidScenario(group.first?.id ?? "unknown")
                }
            }
        }

        self.allRecords = records
    }

    public init(url: URL, requireReleaseReady: Bool = true) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let records = try decoder.decode([HokenshiQuestionRecord].self, from: data)
        try self.init(records: records, requireReleaseReady: requireReleaseReady)
    }

    public var productQuestions: [LearningQuestion] {
        allRecords.map(\.coreQuestion)
    }

    public func questions(round: Int) -> [HokenshiQuestionRecord] {
        allRecords
            .filter { $0.round == round }
            .sorted { $0.questionNumber < $1.questionNumber }
    }

    public func questions(subject: String) -> [HokenshiQuestionRecord] {
        allRecords.filter { $0.subject == subject }
    }

    public func scenario(id: String) -> [HokenshiQuestionRecord] {
        allRecords
            .filter { $0.scenarioID == id }
            .sorted { ($0.scenarioIndex ?? 0) < ($1.scenarioIndex ?? 0) }
    }
}
