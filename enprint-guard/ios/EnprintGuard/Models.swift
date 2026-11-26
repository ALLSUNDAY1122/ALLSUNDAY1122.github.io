import Foundation

enum TaskCategory: String, CaseIterable, Codable, Identifiable {
    case submission
    case event
    case item
    case purchase
    case response

    var id: String { rawValue }

    var title: String {
        switch self {
        case .submission: return "提出"
        case .event: return "行事"
        case .item: return "持ち物"
        case .purchase: return "購入・準備"
        case .response: return "回答・申込"
        }
    }
}

enum TaskState: String, CaseIterable, Codable {
    case review
    case todo
    case inProgress
    case completed
    case confirmed

    var title: String {
        switch self {
        case .review: return "確認待ち"
        case .todo: return "未着手"
        case .inProgress: return "対応中"
        case .completed: return "完了"
        case .confirmed: return "確認済み"
        }
    }
}

struct ChildProfile: Identifiable, Codable {
    var id: UUID = UUID()
    var displayName: String
    var schoolName: String = ""
}

struct SourceDocument: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var imageFilename: String
    var ocrText: String
    var createdAt: Date = Date()
    var childID: UUID?
}

struct HouseholdTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var category: TaskCategory
    var dueDate: Date?
    var rawDateText: String?
    var sourceDocumentID: UUID
    var sourceExcerpt: String
    var state: TaskState = .review
    var assignee: String?
    var childID: UUID?
    var confidence: Double
}

struct ExtractionCandidate: Identifiable {
    var id = UUID()
    var title: String
    var category: TaskCategory
    var dueDate: Date?
    var rawDateText: String?
    var sourceExcerpt: String
    var confidence: Double
}
