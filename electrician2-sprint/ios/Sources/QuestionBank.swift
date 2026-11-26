import Foundation

struct QuestionBankFile: Codable {
    let schemaVersion: Int
    let exam: ExamDescriptor
    let sittings: [SittingDescriptor]
    let questions: [BankQuestion]
}
struct ExamDescriptor: Codable {
    let code: String
    let name: String
    let choiceCount: Int
    let officialSource: String
}
struct SittingDescriptor: Codable {
    let sittingID: String
    let year: Int
    let term: String
    let questionPDF: String
    let answerPDF: String
    let expectedQuestionCount: Int
}
struct BankQuestion: Codable, Identifiable {
    let id: String
    let sittingID: String
    let number: Int
    let prompt: String
    let choices: [String]
    let officialAnswer: Int
    let diagramRefs: [String]
    let auditStatus: String
    let sourcePage: Int?
    let memory: String?
    let explanation: String?
    enum CodingKeys: String, CodingKey {
        case id, sittingID = "sitting_id", number, prompt, choices
        case officialAnswer = "official_answer", diagramRefs = "diagram_refs"
        case auditStatus = "audit_status", sourcePage = "source_page", memory, explanation
    }
}
enum QuestionBankLoader {
    static func load() throws -> QuestionBankFile {
        guard let url=Bundle.main.url(forResource:"QUESTION_BANK",withExtension:"json") else {
            throw NSError(domain:"QuestionBank",code:404,userInfo:[NSLocalizedDescriptionKey:"QUESTION_BANK.jsonが未配置です。"])
        }
        let bank=try JSONDecoder().decode(QuestionBankFile.self,from:Data(contentsOf:url))
        try validate(bank)
        return bank
    }
    static func validate(_ bank:QuestionBankFile)throws {
        guard bank.schemaVersion == 1, bank.exam.code == "E2", bank.exam.choiceCount == 4 else {
            throw NSError(domain:"QuestionBank",code:1,userInfo:[NSLocalizedDescriptionKey:"問題バンクのschema_versionまたは試験定義が不正です。"])
        }
        let ids=bank.questions.map(\.id)
        guard Set(ids).count == ids.count else { throw NSError(domain:"QuestionBank",code:2,userInfo:[NSLocalizedDescriptionKey:"問題IDが重複しています。"]) }
        let sittingIDs=Set(bank.sittings.map(\.sittingID))
        for q in bank.questions {
            guard sittingIDs.contains(q.sittingID), q.number >= 1, q.choices.count == 4,
                  (1...4).contains(q.officialAnswer),
                  ["PENDING","PASS","FAIL","HOLD"].contains(q.auditStatus) else {
                throw NSError(domain:"QuestionBank",code:3,userInfo:[NSLocalizedDescriptionKey:"問題 \(q.id) の必須項目または値が不正です。"])
            }
        }
    }
}
