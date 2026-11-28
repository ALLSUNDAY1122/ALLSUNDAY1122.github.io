import Foundation
import UIKit

/// 保健師国家試験の問題。questions-546.json の1件に対応する。
struct Question: Codable, Identifiable {
    let id: String
    let session: Int
    let period: String // "AM" | "PM"
    let number: Int
    let type: String // "single" | "multi" | "numeric"
    let context: String
    let stem: String
    let choices: [String]
    let answer: AnswerValue
    let explanation: String
    let figure: Bool
    let figurePage: Int?
    let note: String

    var isNumeric: Bool { type == "numeric" }
    var isMulti: Bool { type == "multi" }
    var correctChoices: [Int] {
        if case .choices(let values) = answer { return values }
        return []
    }
    var numericAnswer: String {
        if case .numeric(let value) = answer { return value }
        return ""
    }
    var periodLabel: String { period == "AM" ? "午前" : "午後" }
    var title: String { "第\(session)回 \(periodLabel) 第\(number)問" }

    private enum CodingKeys: String, CodingKey {
        case id, session, period, number, type, context, stem, choices
        case answer, explanation, figure, figurePage, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        session = try c.decode(Int.self, forKey: .session)
        period = try c.decode(String.self, forKey: .period)
        number = try c.decode(Int.self, forKey: .number)
        type = try c.decode(String.self, forKey: .type)
        context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        stem = try c.decode(String.self, forKey: .stem)
        choices = try c.decodeIfPresent([String].self, forKey: .choices) ?? []
        answer = try c.decode(AnswerValue.self, forKey: .answer)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation) ?? ""
        figure = try c.decodeIfPresent(Bool.self, forKey: .figure) ?? false
        figurePage = try c.decodeIfPresent(Int.self, forKey: .figurePage)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

/// 正答は形式で型が違う: 選択式は番号配列 [2] / [3, 4]、数値入力は文字列 "57.5"。
enum AnswerValue: Codable {
    case choices([Int])
    case numeric(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let values = try? c.decode([Int].self) {
            self = .choices(values)
        } else if let value = try? c.decode(String.self) {
            self = .numeric(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "answer must be [Int] or String")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .choices(let values): try c.encode(values)
        case .numeric(let value): try c.encode(value)
        }
    }
}

@MainActor
final class QuestionStore: ObservableObject {
    static let shared = QuestionStore()

    @Published private(set) var questions: [Question] = []
    @Published private(set) var loadError = ""

    /// 無料で解ける問題: 最新回（第112回）の午前1〜15・午後1〜15 = 30問。
    static let freeSession = 112
    static let freeNumbers = 1...15

    static func isFree(_ question: Question) -> Bool {
        question.session == freeSession && freeNumbers.contains(question.number)
    }

    var freeQuestions: [Question] {
        questions.filter(Self.isFree)
    }

    var sessionsDescending: [Int] {
        Array(Set(questions.map(\.session))).sorted(by: >)
    }

    func questions(session: Int, period: String) -> [Question] {
        questions
            .filter { $0.session == session && $0.period == period }
            .sorted { $0.number < $1.number }
    }

    func question(id: String) -> Question? {
        questions.first { $0.id == id }
    }

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "questions-546", withExtension: "json") else {
            loadError = "問題データが見つかりません。"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            questions = try JSONDecoder().decode([Question].self, from: data)
        } catch {
            loadError = "問題データの読み込みに失敗しました。"
        }
    }
}

/// 図表画像。figures.json（id → PNG の Base64）を遅延読み込みしてキャッシュする。
final class FigureStore {
    static let shared = FigureStore()

    private var base64ByID: [String: String]?
    private var cache: [String: UIImage] = [:]

    func image(for questionID: String) -> UIImage? {
        if let cached = cache[questionID] { return cached }
        if base64ByID == nil {
            var merged: [String: String] = [:]
            for name in ["figures-1", "figures-2"] {
                guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let decoded = try? JSONDecoder().decode([String: String].self, from: data)
                else { return nil }
                merged.merge(decoded) { _, new in new }
            }
            base64ByID = merged
        }
        guard let encoded = base64ByID?[questionID],
              let data = Data(base64Encoded: encoded),
              let image = UIImage(data: data)
        else { return nil }
        cache[questionID] = image
        return image
    }
}
