import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var documents: [SourceDocument] = []
    @Published private(set) var tasks: [HouseholdTask] = []
    @Published var children: [ChildProfile] = [ChildProfile(displayName: "子ども1")]

    private struct Snapshot: Codable {
        var documents: [SourceDocument]
        var tasks: [HouseholdTask]
        var children: [ChildProfile]
    }

    private let folderURL: URL
    private let snapshotURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        folderURL = base.appendingPathComponent("EnprintGuard", isDirectory: true)
        snapshotURL = folderURL.appendingPathComponent("snapshot.json")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        load()
    }

    var reviewTasks: [HouseholdTask] {
        tasks.filter { $0.state == .review }
    }

    var activeTasks: [HouseholdTask] {
        tasks.filter { $0.state == .todo || $0.state == .inProgress }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var completedTasks: [HouseholdTask] {
        tasks.filter { $0.state == .completed || $0.state == .confirmed }
    }

    func importImage(_ image: UIImage, title: String = "園プリント") async throws {
        let result = try await ExtractionService().extract(from: image)
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw ExtractionError.unreadableImage
        }
        let documentID = UUID()
        let filename = "\(documentID.uuidString).jpg"
        try data.write(to: folderURL.appendingPathComponent(filename), options: .atomic)

        let document = SourceDocument(
            id: documentID,
            title: title,
            imageFilename: filename,
            ocrText: result.text
        )
        documents.insert(document, at: 0)

        for candidate in result.candidates {
            tasks.insert(
                HouseholdTask(
                    title: candidate.title,
                    category: candidate.category,
                    dueDate: candidate.dueDate,
                    rawDateText: candidate.rawDateText,
                    sourceDocumentID: documentID,
                    sourceExcerpt: candidate.sourceExcerpt,
                    state: .review,
                ),
                at: 0
            )
        }
        persist()
    }

    func approve(_ task: HouseholdTask, dueDate: Date?, assignee: String?) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if task.rawDateText != nil && dueDate == nil { return }
        tasks[index].dueDate = dueDate
        tasks[index].assignee = assignee
        tasks[index].state = .todo
        NotificationScheduler.shared.schedule(for: tasks[index])
        persist()
    }

    func update(_ task: HouseholdTask, dueDate: Date?, assignee: String?) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].dueDate = dueDate
        tasks[index].assignee = assignee
        if tasks[index].state == .todo || tasks[index].state == .inProgress {
            NotificationScheduler.shared.schedule(for: tasks[index])
        }
        persist()
    }

    func setState(_ state: TaskState, for task: HouseholdTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].state = state
        if state == .completed || state == .confirmed {
            NotificationScheduler.shared.cancel(taskID: task.id)
        } else {
            NotificationScheduler.shared.schedule(for: tasks[index])
        }
        persist()
    }

    func deleteTask(_ task: HouseholdTask) {
        tasks.removeAll { $0.id == task.id }
        NotificationScheduler.shared.cancel(taskID: task.id)
        persist()
    }

    func imageURL(for document: SourceDocument) -> URL {
        folderURL.appendingPathComponent(document.imageFilename)
    }

    private func load() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        documents = snapshot.documents
        tasks = snapshot.tasks
        children = snapshot.children
    }

    private func persist() {
        let snapshot = Snapshot(documents: documents, tasks: tasks, children: children)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }
}
