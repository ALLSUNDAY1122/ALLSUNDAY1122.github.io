import Foundation
import LearningSprintCore

struct NativeQuestionPayload: Codable {
    let schemaVersion: Int
    let qualification: String
    let bundleID: String
    let contentVersion: String
    let sourceAuditDate: String
    let questions: [LearningQuestion]
}

enum QuestionRepositoryError: LocalizedError {
    case missingResource, invalidMetadata, invalidQuestionBank([ContentValidationIssue]), invalidRound(Int)
    var errorDescription: String? {
        switch self {
        case .missingResource: return "問題データを読み込めませんでした。"
        case .invalidMetadata: return "問題データの識別情報が正本と一致しません。"
        case .invalidQuestionBank: return "問題データの監査に失敗しました。"
        case .invalidRound(let round): return "第\(round)回の問題構成が200問ではありません。"
        }
    }
}

struct QuestionRepository {
    let payload: NativeQuestionPayload
    static func load(bundle: Bundle = .main) throws -> QuestionRepository {
        guard let url=bundle.url(forResource:"questions.native",withExtension:"json") else { throw QuestionRepositoryError.missingResource }
        let payload=try JSONDecoder().decode(NativeQuestionPayload.self,from:Data(contentsOf:url))
        guard payload.schemaVersion==1,payload.bundleID==KanriAppConfig.bundleID,payload.contentVersion==KanriAppConfig.contentVersion,payload.qualification==KanriAppConfig.qualificationName else { throw QuestionRepositoryError.invalidMetadata }
        let errors=ContentValidator.validate(questions:payload.questions,expectedContentVersion:KanriAppConfig.contentVersion).filter{$0.severity == .error}
        guard errors.isEmpty else { throw QuestionRepositoryError.invalidQuestionBank(errors) }
        let repository=QuestionRepository(payload:payload); try repository.validateExamComposition(); return repository
    }
    var questions:[LearningQuestion]{payload.questions}
    var freeQuestions:[LearningQuestion]{questions.filter{!$0.premium}}
    func round(_ value:Int)->[LearningQuestion]{questions.filter{$0.examRound=="第\(value)回"}}
    func round(_ value:Int,subject:String)->[LearningQuestion]{round(value).filter{$0.subject==subject}}
    func question(id:String)->LearningQuestion?{questions.first{$0.id==id}}
    private func validateExamComposition() throws {
        guard questions.count==600,freeQuestions.count==60 else { throw QuestionRepositoryError.invalidMetadata }
        for r in 1...3 { let set=round(r); guard set.count==200 else{throw QuestionRepositoryError.invalidRound(r)}; guard Dictionary(grouping:set,by:\.subject).mapValues(\.count)==KanriAppConfig.expectedPerRound else{throw QuestionRepositoryError.invalidRound(r)} }
        let freeCounts=Dictionary(grouping:freeQuestions,by:\.subject).mapValues(\.count)
        guard freeCounts==Dictionary(uniqueKeysWithValues:KanriAppConfig.subjects.map{($0,6)}) else{throw QuestionRepositoryError.invalidMetadata}
    }
}
