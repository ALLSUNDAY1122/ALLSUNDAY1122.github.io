import Foundation

enum QuestionRepository {
    static func load() throws -> [Question] {
        guard let url = Bundle.main.url(forResource: "questions.generated", withExtension: "json") else {
            throw NSError(domain: "ShoshiQuestions", code: 1, userInfo: [NSLocalizedDescriptionKey: "210問の教材データがアプリに含まれていません。"])
        }
        let data = try Data(contentsOf: url)
        let questions = try JSONDecoder().decode([Question].self, from: data)
        guard questions.count == 210, Set(questions.map(\.id)).count == 210 else {
            throw NSError(domain: "ShoshiQuestions", code: 2, userInfo: [NSLocalizedDescriptionKey: "教材データの件数またはID整合性に問題があります。"])
        }
        guard let special = questions.first(where: { $0.id == "SHOSHI-R7-PM-33" }), special.isAllCorrect, special.officialAnswerNo == nil else {
            throw NSError(domain: "ShoshiQuestions", code: 3, userInfo: [NSLocalizedDescriptionKey: "令和7年度午後第33問の公式採点情報が不整合です。"])
        }
        return questions
    }
}
