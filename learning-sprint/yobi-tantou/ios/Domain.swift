import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct StudyQuestion: Codable, Identifiable, Equatable {
    let id: String
    let examYear: Int?
    let subject: String
    let topic: String
    let stem: String
    let choices: [String]
    let correctIndices: [Int]
    let explanation: String
    let memory: String
    let sourceTitle: String
    let sourceURL: String
    let evidenceCheckedDate: String
    let lawBasisDate: String?
    let originType: String
    let releaseEligible: Bool
}

struct AttemptState: Codable, Equatable {
    var answered = 0
    var correct = 0
    var consecutiveCorrect = 0
    var weak = false
    var unknown = false
}

struct DayStat: Codable, Equatable {
    var answered = 0
    var correct = 0
}

struct ResumeState: Codable, Equatable {
    let questionIDs: [String]
    var index: Int
    var correct: Int
    let title: String
    let consumesFreeSprint: Bool
}

struct PersistentState: Codable, Equatable {
    var attempts: [String: AttemptState] = [:]
    var dailyStats: [String: DayStat] = [:]
    var totalAnswered = 0
    var totalCorrect = 0
    var dailyGoal = 8
    var selectedTextSize = "medium"
    var examDate: Date?
    var resume: ResumeState?
    var freeSprintConsumed = false
}

enum SessionDescriptor: Equatable {
    case daily
    case weak
    case subject(String)
    case mock(Int)
}

struct SessionResult: Equatable {
    let title: String
    let answered: Int
    let correct: Int
}

struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let state: PersistentState
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension DateFormatter {
    static let sprintDayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
