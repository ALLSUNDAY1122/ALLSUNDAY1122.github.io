import Foundation

private final class QuestionBankBundleToken {}

struct QuestionBankFile: Codable {
    let schemaVersion: String
    let dataSet: String
    let sourceFiles: QuestionBankSourceFiles
    let questionCount: Int
    let questions: [BankQuestion]
}
struct QuestionBankSourceFiles: Codable {
    let questionPdf: String
    let answerPdf: String
}
struct BankChoice: Codable {
    let label: String
    let text: String
}
struct BankQuestionSource: Codable {
    let title: String
    let url: String
    let page: Int?
    let figure: String?
    let figureRefs: [String]?
}
struct BankQuestionAudit: Codable {
    let transcription: String
    let answer: String
    let figureStatus: String
    let independentReview: String
    let releaseStatus: String
}
struct BankQuestion: Codable, Identifiable {
    let id: String
    let exam: String
    let examDate: String
    let section: String
    let questionNumber: Int
    let question: String
    let choices: [BankChoice]
    let answerOfficial: String
    let hereToRemember: String?
    let explanation: String?
    let source: BankQuestionSource
    let audit: BankQuestionAudit
    let auditStatus: String?
    let excludedFromQuiz: Bool?
    var isEligibleForQuiz: Bool { excludedFromQuiz != true }
    enum CodingKeys: String, CodingKey { case id, exam, examDate, section, questionNumber, question, choices, answerOfficial, hereToRemember, explanation, source, audit, auditStatus = "audit_status", excludedFromQuiz }
}
enum QuestionBankLoader {
    static func load() throws -> QuestionBankFile {
        guard let url=Bundle.main.url(forResource:"QUESTION_BANK",withExtension:"json") ?? Bundle(for: QuestionBankBundleToken.self).url(forResource:"QUESTION_BANK",withExtension:"json") else {
            throw NSError(domain:"QuestionBank",code:404,userInfo:[NSLocalizedDescriptionKey:"QUESTION_BANK.jsonが未配置です。"])
        }
        let bank=try JSONDecoder().decode(QuestionBankFile.self,from:Data(contentsOf:url))
        try validate(bank)
        return bank
    }
    static func validate(_ bank:QuestionBankFile)throws {
        guard bank.schemaVersion == "1.0", bank.dataSet == "E2-ALL-2022-2026",
              bank.questionCount == bank.questions.count else {
            throw NSError(domain:"QuestionBank",code:1,userInfo:[NSLocalizedDescriptionKey:"schemaVersion、dataSet、questionCountが不正です。"])
        }
        let ids=bank.questions.map(\.id)
        guard Set(ids).count == ids.count else {
            throw NSError(domain:"QuestionBank",code:2,userInfo:[NSLocalizedDescriptionKey:"問題IDが重複しています。"])
        }
        let labels=["イ","ロ","ハ","ニ"]
        for q in bank.questions {
            guard q.id.hasPrefix("E2-"), q.questionNumber >= 1, !q.question.isEmpty,
                  q.choices.map(\.label) == labels, q.choices.allSatisfy({ !$0.text.isEmpty }),
                  labels.contains(q.answerOfficial), (q.source.page == nil || q.source.page! >= 1),
                  !q.source.url.isEmpty, !q.audit.releaseStatus.isEmpty else {
                throw NSError(domain:"QuestionBank",code:3,userInfo:[NSLocalizedDescriptionKey:"問題 \(q.id) の必須項目または選択肢・正答・出典が不正です。"])
            }
        }
    }
}
