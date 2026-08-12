import Foundation

public enum ExamSubject: String, Codable, CaseIterable, Sendable {
    case administrativeLaw = "不動産に関する行政法規"
    case valuationTheory = "不動産の鑑定評価に関する理論"
}

public enum ExamEdition: Int, Codable, CaseIterable, Sendable {
    case reiwa6 = 2024
    case reiwa7 = 2025
    case reiwa8 = 2026

    public var officialQuestionCountPerSubject: Int { 40 }
    public var officialQuestionCountTotal: Int { officialQuestionCountPerSubject * ExamSubject.allCases.count }
}

public struct EvidenceSource: Codable, Hashable, Sendable {
    public let title: String
    public let url: URL
    public let checkedDate: String

    public init(title: String, url: URL, checkedDate: String) {
        self.title = title
        self.url = url
        self.checkedDate = checkedDate
    }
}

public struct Question: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let edition: ExamEdition
    public let subject: ExamSubject
    public let domain: String
    public let prompt: String
    public let choices: [String]
    public let correctChoiceIndex: Int
    public let explanation: String
    public let memoryPoint: String
    public let evidence: [EvidenceSource]

    public init(
        id: String,
        edition: ExamEdition,
        subject: ExamSubject,
        domain: String,
        prompt: String,
        choices: [String],
        correctChoiceIndex: Int,
        explanation: String,
        memoryPoint: String,
        evidence: [EvidenceSource]
    ) {
        self.id = id
        self.edition = edition
        self.subject = subject
        self.domain = domain
        self.prompt = prompt
        self.choices = choices
        self.correctChoiceIndex = correctChoiceIndex
        self.explanation = explanation
        self.memoryPoint = memoryPoint
        self.evidence = evidence
    }

    public var isProductionReady: Bool {
        !id.isEmpty &&
        !domain.isEmpty &&
        !prompt.isEmpty &&
        choices.count >= 2 &&
        choices.indices.contains(correctChoiceIndex) &&
        !explanation.isEmpty &&
        !memoryPoint.isEmpty &&
        !evidence.isEmpty &&
        evidence.allSatisfy { !$0.title.isEmpty && !$0.checkedDate.isEmpty }
    }
}

public struct AttemptRecord: Codable, Hashable, Sendable {
    public let questionID: String
    public let isCorrect: Bool
    public let isUncertain: Bool
    public let answeredAt: Date

    public init(questionID: String, isCorrect: Bool, isUncertain: Bool, answeredAt: Date = Date()) {
        self.questionID = questionID
        self.isCorrect = isCorrect
        self.isUncertain = isUncertain
        self.answeredAt = answeredAt
    }
}

public enum StudyMode: String, Codable, Sendable {
    case standardSprint
    case domainPractice
    case mockExam
    case weakReview
}

public struct ResumeState: Codable, Equatable, Sendable {
    public let mode: StudyMode
    public let questionIDs: [String]
    public var currentIndex: Int
    public var selectedAnswers: [String: Int]
    public var uncertainQuestionIDs: Set<String>

    public init(
        mode: StudyMode,
        questionIDs: [String],
        currentIndex: Int = 0,
        selectedAnswers: [String: Int] = [:],
        uncertainQuestionIDs: Set<String> = []
    ) {
        self.mode = mode
        self.questionIDs = questionIDs
        self.currentIndex = currentIndex
        self.selectedAnswers = selectedAnswers
        self.uncertainQuestionIDs = uncertainQuestionIDs
    }
}

public struct ProgressSnapshot: Codable, Equatable, Sendable {
    public var attempts: [AttemptRecord]
    public var resumeState: ResumeState?

    public init(attempts: [AttemptRecord] = [], resumeState: ResumeState? = nil) {
        self.attempts = attempts
        self.resumeState = resumeState
    }
}
