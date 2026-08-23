import Foundation
import LearningSprintCore

public enum JosanshiQuestionBankError: Error, Equatable {
    case invalidQualification(String)
    case invalidContentVersion(String)
    case duplicateQuestionID(String)
    case duplicateScenarioID(String)
    case invalidAnswerType(String)
    case brokenScenarioReference(String)
}

public struct JosanshiClinicalFrame: Codable, Hashable, Sendable {
    public let phase: String
    public let timeline: String
    public let keyFindings: [String]

    public init(phase: String, timeline: String, keyFindings: [String]) {
        self.phase = phase
        self.timeline = timeline
        self.keyFindings = keyFindings
    }
}

public struct JosanshiScenarioRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { scenarioId }

    public let scenarioId: String
    public let mockRound: Int
    public let session: String
    public let scenarioFamily: String
    public let scenarioText: String
    public let clinicalFrame: JosanshiClinicalFrame
    public let questionIds: [String]
    public let sourceIds: [String]
    public let sourceCheckedAt: String
    public let rightsBasis: String
    public let auditStatus: String
    public let authoringBatch: String?

    public init(
        scenarioId: String,
        mockRound: Int,
        session: String,
        scenarioFamily: String,
        scenarioText: String,
        clinicalFrame: JosanshiClinicalFrame,
        questionIds: [String],
        sourceIds: [String],
        sourceCheckedAt: String,
        rightsBasis: String,
        auditStatus: String,
        authoringBatch: String? = nil
    ) {
        self.scenarioId = scenarioId
        self.mockRound = mockRound
        self.session = session
        self.scenarioFamily = scenarioFamily
        self.scenarioText = scenarioText
        self.clinicalFrame = clinicalFrame
        self.questionIds = questionIds
        self.sourceIds = sourceIds
        self.sourceCheckedAt = sourceCheckedAt
        self.rightsBasis = rightsBasis
        self.auditStatus = auditStatus
        self.authoringBatch = authoringBatch
    }
}

public struct JosanshiProductionQuestion: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let mockRound: Int
    public let session: String
    public let slotNumber: Int
    public let questionType: String
    public let scenarioId: String?
    public let scenarioIndex: Int?
    public let scenarioTotal: Int?
    public let subject: String
    public let topicId: String
    public let intentId: String
    public let intentFocus: String
    public let answerType: String
    public let prompt: String
    public let choices: [String]
    public let correctIndices: [Int]
    public let explanation: String
    public let memoryPoint: String
    public let sourceIds: [String]
    public let sourceCheckedAt: String
    public let lawBaselineDate: String
    public let rightsBasis: String
    public let originType: String
    public let contentVersion: String
    public let auditStatus: String
    public let evidenceNote: String?
    public let authoringBatch: String?

    public init(
        id: String,
        mockRound: Int,
        session: String,
        slotNumber: Int,
        questionType: String,
        scenarioId: String? = nil,
        scenarioIndex: Int? = nil,
        scenarioTotal: Int? = nil,
        subject: String,
        topicId: String,
        intentId: String,
        intentFocus: String,
        answerType: String,
        prompt: String,
        choices: [String],
        correctIndices: [Int],
        explanation: String,
        memoryPoint: String,
        sourceIds: [String],
        sourceCheckedAt: String,
        lawBaselineDate: String,
        rightsBasis: String,
        originType: String,
        contentVersion: String,
        auditStatus: String,
        evidenceNote: String? = nil,
        authoringBatch: String? = nil
    ) {
        self.id = id
        self.mockRound = mockRound
        self.session = session
        self.slotNumber = slotNumber
        self.questionType = questionType
        self.scenarioId = scenarioId
        self.scenarioIndex = scenarioIndex
        self.scenarioTotal = scenarioTotal
        self.subject = subject
        self.topicId = topicId
        self.intentId = intentId
        self.intentFocus = intentFocus
        self.answerType = answerType
        self.prompt = prompt
        self.choices = choices
        self.correctIndices = correctIndices
        self.explanation = explanation
        self.memoryPoint = memoryPoint
        self.sourceIds = sourceIds
        self.sourceCheckedAt = sourceCheckedAt
        self.lawBaselineDate = lawBaselineDate
        self.rightsBasis = rightsBasis
        self.originType = originType
        self.contentVersion = contentVersion
        self.auditStatus = auditStatus
        self.evidenceNote = evidenceNote
        self.authoringBatch = authoringBatch
    }

    public func asLearningQuestion(premium: Bool = false) throws -> LearningQuestion {
        guard let learningAnswerType = LearningAnswerType(rawValue: answerType) else {
            throw JosanshiQuestionBankError.invalidAnswerType(answerType)
        }
        return LearningQuestion(
            id: id,
            subject: subject,
            topic: topicId,
            answerType: learningAnswerType,
            prompt: prompt,
            choices: choices,
            correctIndices: correctIndices,
            memoryPoint: memoryPoint,
            explanation: explanation,
            sourceTitle: nil,
            sourceURL: nil,
            sourceRefs: sourceIds,
            sourceCheckedAt: sourceCheckedAt,
            lawBaselineDate: lawBaselineDate,
            contentVersion: contentVersion,
            premium: premium,
            examRound: String(mockRound),
            questionNumber: "\(session)-\(slotNumber)",
            rightsBasis: rightsBasis
        )
    }
}

public struct JosanshiQuestionBankDocument: Codable, Sendable {
    public let schemaVersion: String
    public let qualification: String
    public let contentVersion: String
    public let status: String
    public let questions: [JosanshiProductionQuestion]
    public let scenarios: [JosanshiScenarioRecord]

    public init(
        schemaVersion: String = "1.0",
        qualification: String = JosanshiExamConfiguration.qualificationName,
        contentVersion: String = JosanshiLocalPersistenceConfiguration.contentVersion,
        status: String,
        questions: [JosanshiProductionQuestion],
        scenarios: [JosanshiScenarioRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.qualification = qualification
        self.contentVersion = contentVersion
        self.status = status
        self.questions = questions
        self.scenarios = scenarios
    }

    public func scenario(for question: JosanshiProductionQuestion) -> JosanshiScenarioRecord? {
        guard let scenarioId = question.scenarioId else { return nil }
        return scenarios.first(where: { $0.scenarioId == scenarioId })
    }

    public func learningQuestions() throws -> [LearningQuestion] {
        let freeIDs = JosanshiMonetizationConfiguration.freeQuestionIDs(in: questions)
        return try questions.map { question in
            try question.asLearningQuestion(premium: !freeIDs.contains(question.id))
        }
    }
}

public enum JosanshiQuestionBankLoader {
    public static func decode(_ data: Data) throws -> JosanshiQuestionBankDocument {
        let document = try JSONDecoder().decode(JosanshiQuestionBankDocument.self, from: data)
        guard document.qualification == JosanshiExamConfiguration.qualificationName else {
            throw JosanshiQuestionBankError.invalidQualification(document.qualification)
        }
        guard document.contentVersion == JosanshiLocalPersistenceConfiguration.contentVersion else {
            throw JosanshiQuestionBankError.invalidContentVersion(document.contentVersion)
        }

        var seenQuestionIDs = Set<String>()
        for question in document.questions {
            guard seenQuestionIDs.insert(question.id).inserted else {
                throw JosanshiQuestionBankError.duplicateQuestionID(question.id)
            }
        }

        var seenScenarioIDs = Set<String>()
        for scenario in document.scenarios {
            guard seenScenarioIDs.insert(scenario.scenarioId).inserted else {
                throw JosanshiQuestionBankError.duplicateScenarioID(scenario.scenarioId)
            }
        }

        let scenarioIDs = Set(document.scenarios.map(\.scenarioId))
        for question in document.questions where question.questionType == "situation" {
            guard let scenarioId = question.scenarioId, scenarioIDs.contains(scenarioId) else {
                throw JosanshiQuestionBankError.brokenScenarioReference(question.id)
            }
        }
        return document
    }
}
