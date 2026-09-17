import Foundation

public enum LearningAnswerType: String, Codable, Sendable { case singleChoice, multiChoice, numeric, blankSelect, declaration }

public struct BlankField: Codable, Hashable, Sendable {
    public let key: String; public let label: String; public let options: [String]; public let correctValue: String
    public init(key: String, label: String, options: [String], correctValue: String) { self.key=key; self.label=label; self.options=options; self.correctValue=correctValue }
}

public struct DeclarationField: Codable, Hashable, Sendable {
    public let key: String; public let label: String; public let correctValue: String; public let aliases: [String]
    public init(key: String, label: String, correctValue: String, aliases: [String] = []) { self.key=key; self.label=label; self.correctValue=correctValue; self.aliases=aliases }
}

public struct LearningQuestion: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let subject: String
    public let topic: String
    public let answerType: LearningAnswerType
    public let prompt: String
    public let choices: [String]
    public let correctIndices: [Int]
    public let correctNumber: Double?
    public let acceptedRange: Double?
    public let unit: String?
    public let roundingRule: String?
    public let blanks: [BlankField]
    public let declarationFields: [DeclarationField]
    public let sourceText: String?
    public let memoryPoint: String
    public let explanation: String
    public let sourceTitle: String?
    public let sourceURL: String?
    public let sourceRefs: [String]
    public let sourceCheckedAt: String
    public let lawBaselineDate: String
    public let contentVersion: String
    public let premium: Bool
    public let examRound: String?
    public let questionNumber: String?
    public let rightsBasis: String?

    public init(id: String, subject: String, topic: String, answerType: LearningAnswerType, prompt: String, choices: [String] = [], correctIndices: [Int] = [], correctNumber: Double? = nil, acceptedRange: Double? = nil, unit: String? = nil, roundingRule: String? = nil, blanks: [BlankField] = [], declarationFields: [DeclarationField] = [], sourceText: String? = nil, memoryPoint: String, explanation: String, sourceTitle: String? = nil, sourceURL: String? = nil, sourceRefs: [String] = [], sourceCheckedAt: String, lawBaselineDate: String, contentVersion: String, premium: Bool = false, examRound: String? = nil, questionNumber: String? = nil, rightsBasis: String? = nil) {
        self.id=id; self.subject=subject; self.topic=topic; self.answerType=answerType; self.prompt=prompt; self.choices=choices; self.correctIndices=correctIndices; self.correctNumber=correctNumber; self.acceptedRange=acceptedRange; self.unit=unit; self.roundingRule=roundingRule; self.blanks=blanks; self.declarationFields=declarationFields; self.sourceText=sourceText; self.memoryPoint=memoryPoint; self.explanation=explanation; self.sourceTitle=sourceTitle; self.sourceURL=sourceURL; self.sourceRefs=sourceRefs; self.sourceCheckedAt=sourceCheckedAt; self.lawBaselineDate=lawBaselineDate; self.contentVersion=contentVersion; self.premium=premium; self.examRound=examRound; self.questionNumber=questionNumber; self.rightsBasis=rightsBasis
    }
}

public struct AnswerPayload: Codable, Equatable, Sendable {
    public var selectedIndices: [Int]; public var numberValue: Double?; public var blankValues: [String:String]; public var declarationValues: [String:String]; public var isUnknown: Bool
    public init(selectedIndices: [Int] = [], numberValue: Double? = nil, blankValues: [String:String] = [:], declarationValues: [String:String] = [:], isUnknown: Bool = false) { self.selectedIndices=selectedIndices; self.numberValue=numberValue; self.blankValues=blankValues; self.declarationValues=declarationValues; self.isUnknown=isUnknown }
    public static let unknown = AnswerPayload(isUnknown: true)
}

public struct AnswerEvaluation: Codable, Equatable, Sendable {
    public let isCorrect: Bool; public let isUnknown: Bool; public let message: String
    public init(isCorrect: Bool, isUnknown: Bool, message: String) { self.isCorrect=isCorrect; self.isUnknown=isUnknown; self.message=message }
}

public struct LearningAttempt: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID; public let questionID: String; public let answeredAt: Date; public let isCorrect: Bool; public let isUnknown: Bool; public let subject: String; public let topic: String
    public init(id: UUID = UUID(), questionID: String, answeredAt: Date = Date(), isCorrect: Bool, isUnknown: Bool, subject: String, topic: String) { self.id=id; self.questionID=questionID; self.answeredAt=answeredAt; self.isCorrect=isCorrect; self.isUnknown=isUnknown; self.subject=subject; self.topic=topic }
}

public struct WeakQuestionState: Codable, Equatable, Sendable {
    public var consecutiveCorrect: Int; public var lastAnsweredAt: Date
    public init(consecutiveCorrect: Int = 0, lastAnsweredAt: Date = Date()) { self.consecutiveCorrect=consecutiveCorrect; self.lastAnsweredAt=lastAnsweredAt }
}

public enum SessionKind: Codable, Equatable, Sendable {
    case sprint, weak, subject(String), mock(String)
    public var completionKey: String { switch self { case .sprint: return "sprint"; case .weak: return "weak"; case .subject(let v): return "subject:\(v)"; case .mock(let v): return "mock:\(v)" } }
}

public struct LearningSessionSnapshot: Codable, Equatable, Sendable {
    public let kind: SessionKind; public let questionIDs: [String]; public var currentIndex: Int; public let startedAt: Date; public var answers: [String:AnswerPayload]
    public init(kind: SessionKind, questionIDs: [String], currentIndex: Int = 0, startedAt: Date = Date(), answers: [String:AnswerPayload] = [:]) { self.kind=kind; self.questionIDs=questionIDs; self.currentIndex=currentIndex; self.startedAt=startedAt; self.answers=answers }
}

public struct LearningState: Codable, Equatable, Sendable {
    public var dailyTarget: Int
    public var attempts: [LearningAttempt]
    public var weakQuestions: [String:WeakQuestionState]
    public var resumeSession: LearningSessionSnapshot?
    public var examDate: Date?
    public var textSizeStep: Int
    public var contentVersion: String
    public var completionCounts: [String:Int]?
    public var shuffleQuestions: Bool?
    public var shuffleChoices: Bool?

    public init(dailyTarget: Int = 8, attempts: [LearningAttempt] = [], weakQuestions: [String:WeakQuestionState] = [:], resumeSession: LearningSessionSnapshot? = nil, examDate: Date? = nil, textSizeStep: Int = 1, contentVersion: String, completionCounts: [String:Int] = [:], shuffleQuestions: Bool? = true, shuffleChoices: Bool? = false) {
        self.dailyTarget = Self.validTarget(dailyTarget) ? dailyTarget : 8
        self.attempts=attempts; self.weakQuestions=weakQuestions; self.resumeSession=resumeSession; self.examDate=examDate; self.textSizeStep=min(2,max(0,textSizeStep)); self.contentVersion=contentVersion; self.completionCounts=completionCounts; self.shuffleQuestions=shuffleQuestions; self.shuffleChoices=shuffleChoices
    }
    public static func validTarget(_ value: Int) -> Bool { [4,8,16].contains(value) }
    public func completionCount(for kind: SessionKind) -> Int { completionCounts?[kind.completionKey] ?? 0 }
    public mutating func recordCompletion(for kind: SessionKind) { var counts=completionCounts ?? [:]; counts[kind.completionKey,default:0]+=1; completionCounts=counts }
}

public struct QualificationConfig: Codable, Equatable, Sendable {
    public let qualificationName: String; public let appDisplayName: String; public let bundleID: String; public let appStoreConnectID: String?; public let codemagicProfile: String; public let productID: String?; public let version: String; public let teamID: String; public let subjects: [String]; public let defaultExamDate: Date?
    public init(qualificationName: String, appDisplayName: String, bundleID: String, appStoreConnectID: String?, codemagicProfile: String, productID: String?, version: String = "1.0.0", teamID: String = "MN3D2ZM44N", subjects: [String], defaultExamDate: Date? = nil) { self.qualificationName=qualificationName; self.appDisplayName=appDisplayName; self.bundleID=bundleID; self.appStoreConnectID=appStoreConnectID; self.codemagicProfile=codemagicProfile; self.productID=productID; self.version=version; self.teamID=teamID; self.subjects=subjects; self.defaultExamDate=defaultExamDate }
}
