import Foundation
import Supabase
import SwiftUI

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    private let client: SupabaseClient
    private let redirectURL = URL(string: "enprintguard://login-callback")!

    @Published private(set) var userEmail: String?
    @Published private(set) var householdID: UUID?
    @Published private(set) var statusMessage = ""
    @Published var inviteURL: URL?

    var isSignedIn: Bool { userEmail != nil }

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://qwvdrxkuongnevupxywp.supabase.co")!,
            supabaseKey: "sb_publishable_z5Laqwz29cMz9hq1HMQjRA_39QJ0gg2"
        )
        Task { await refreshSession() }
    }

    func sendMagicLink(email: String) async {
        do {
            try await client.auth.signInWithOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines), redirectTo: redirectURL)
            statusMessage = "ログイン用メールを送信しました。メール内のリンクをこの端末で開いてください。"
        } catch {
            statusMessage = "認証メールを送信できませんでした: \(error.localizedDescription)"
        }
    }

    func handleOpenURL(_ url: URL) async {
        if url.scheme != "enprintguard" { return }
        if url.host == "join", let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
            do {
                let _: String = try await client.rpc("accept_household_invite", params: ["p_token": token]).execute().value
                await refreshSession()
                statusMessage = "家族グループに参加しました。"
            } catch {
                statusMessage = "招待リンクを確認できませんでした: \(error.localizedDescription)"
            }
            return
        }
        do {
            _ = try await client.auth.session(from: url)
            await refreshSession()
            statusMessage = "ログインしました。"
        } catch {
            statusMessage = "ログインを完了できませんでした: \(error.localizedDescription)"
        }
    }

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            userEmail = session.user.email
            let memberships: [MembershipRow] = try await client
                .from("household_members")
                .select("household_id,role")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            householdID = memberships.first?.householdID
            if householdID == nil { statusMessage = "ログイン済みです。家族グループを作成するか、招待リンクで参加してください。" }
        } catch {
            userEmail = nil
            householdID = nil
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            userEmail = nil
            householdID = nil
            inviteURL = nil
            statusMessage = "ログアウトしました。"
        } catch {
            statusMessage = "ログアウトできませんでした。"
        }
    }

    func createHousehold(name: String) async {
        do {
            let response = try await client.rpc("create_household", params: ["p_name": name]).execute()
            let idString = String(data: response.data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n")) ?? ""
            householdID = UUID(uuidString: idString)
            statusMessage = householdID == nil ? "グループを作成しましたが、IDを読み取れませんでした。" : "家族グループを作成しました。"
        } catch {
            statusMessage = "グループを作成できませんでした: \(error.localizedDescription)"
        }
    }

    func createInvite() async {
        guard let householdID else { return }
        do {
            var bytes = [UInt8](repeating: 0, count: 32)
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
            let token = Data(bytes).base64URLEncodedString()
            _ = try await client.rpc("create_household_invite", params: [
                "p_household_id": householdID.uuidString,
                "p_token": token
            ]).execute()
            var components = URLComponents()
            components.scheme = "enprintguard"
            components.host = "join"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            inviteURL = components.url
            statusMessage = "7日間有効の招待リンクを作成しました。"
        } catch {
            statusMessage = "招待リンクを作成できませんでした: \(error.localizedDescription)"
        }
    }

    struct CloudSnapshot {
        let documents: [SourceDocument]
        let tasks: [HouseholdTask]
        let children: [ChildProfile]
    }

    func syncSnapshot(
        documents: [SourceDocument],
        tasks: [HouseholdTask],
        children: [ChildProfile],
        localFolder: URL,
        allowAIAnalysis: Bool
    ) async throws -> CloudSnapshot {
        guard let householdID else { throw CloudError.noHousehold }
        let session = try await client.auth.session
        let userID = session.user.id

        let childRows = children.map {
            ChildUpload(id: $0.id, householdID: householdID, displayName: $0.displayName, schoolName: $0.schoolName)
        }
        if !childRows.isEmpty {
            try await client.from("children").upsert(childRows, onConflict: "id").execute()
        }

        for document in documents {
            let localURL = localFolder.appendingPathComponent(document.imageFilename)
            guard let imageData = try? Data(contentsOf: localURL) else { continue }
            let path = "\(householdID.uuidString)/\(document.id.uuidString).jpg"
            try await client.storage.from("enprint-documents").upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
            let row = DocumentUpload(
                id: document.id,
                householdID: householdID,
                childID: document.childID,
                createdBy: userID,
                title: document.title,
                imagePath: path,
                ocrText: document.ocrText
            )
            try await client.from("documents").upsert(row, onConflict: "id").execute()
        }

        let taskRows = tasks.map { task in
            TaskUpload(
                id: task.id,
                householdID: householdID,
                documentID: task.sourceDocumentID,
                childID: task.childID,
                createdBy: userID,
                title: task.title,
                category: task.category.rawValue,
                dueDate: task.dueDate.map(Self.dateString),
                rawDateText: task.rawDateText,
                sourceExcerpt: task.sourceExcerpt,
                state: Self.stateString(task.state),
                aiConfidence: "unrated"
            )
        }
        if !taskRows.isEmpty {
            try await client.from("tasks").upsert(taskRows, onConflict: "id").execute()
        }

        // The function is JWT-protected. It returns 503 until OPENAI_API_KEY is
        // explicitly configured in Supabase Edge Function Secrets.
        var aiUnavailable = false
        if allowAIAnalysis {
        for document in documents where !document.ocrText.isEmpty {
            do {
                let _: AIExtractionResponse = try await client.functions.invoke(
                    "extract-print-tasks",
                    options: FunctionInvokeOptions(body: [
                        "household_id": householdID.uuidString,
                        "document_id": document.id.uuidString,
                        "ocr_text": document.ocrText
                    ])
                )
            } catch {
                // Preserve the OCR/local workflow; AI can be retried from a later sync.
                aiUnavailable = true
            }
        }
        }

        let remoteChildren: [RemoteChild] = try await client
            .from("children").select().eq("household_id", value: householdID.uuidString).execute().value
        let remoteDocuments: [RemoteDocument] = try await client
            .from("documents").select().eq("household_id", value: householdID.uuidString).execute().value
        let remoteTasks: [RemoteTask] = try await client
            .from("tasks").select().eq("household_id", value: householdID.uuidString).execute().value

        var mergedDocuments = documents
        for remote in remoteDocuments {
            let filename = "\(remote.id.uuidString).jpg"
            let localURL = localFolder.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: localURL.path) {
                let data = try await client.storage.from("enprint-documents").download(path: remote.imagePath)
                try data.write(to: localURL, options: .atomic)
            }
            let local = SourceDocument(
                id: remote.id,
                title: remote.title,
                imageFilename: filename,
                ocrText: remote.ocrText,
                createdAt: Self.parseDate(remote.createdAt) ?? Date(),
                childID: remote.childID
            )
            if let index = mergedDocuments.firstIndex(where: { $0.id == local.id }) {
                mergedDocuments[index] = local
            } else {
                mergedDocuments.insert(local, at: 0)
            }
        }

        var mergedTasks = tasks
        for remote in remoteTasks {
            let local = HouseholdTask(
                id: remote.id,
                title: remote.title,
                category: TaskCategory(rawValue: remote.category) ?? .other,
                dueDate: remote.dueDate.flatMap(Self.parseDateOnly),
                rawDateText: remote.rawDateText,
                sourceDocumentID: remote.documentID,
                sourceExcerpt: remote.sourceExcerpt,
                state: Self.taskState(remote.state),
                assignee: remote.assigneeUserID?.uuidString,
                childID: remote.childID
            )
            if let index = mergedTasks.firstIndex(where: { $0.id == local.id }) {
                mergedTasks[index] = local
            } else {
                mergedTasks.insert(local, at: 0)
            }
        }

        let mergedChildren = remoteChildren.map {
            ChildProfile(id: $0.id, displayName: $0.displayName, schoolName: $0.schoolName)
        }
        statusMessage = aiUnavailable
            ? "家族データを同期しました。AI解析はAPI設定または利用上限の確認待ちです。"
            : "家族データを同期しました。"
        return CloudSnapshot(documents: mergedDocuments, tasks: mergedTasks, children: mergedChildren)
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDateOnly(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func stateString(_ state: TaskState) -> String {
        switch state {
        case .review: return "review"
        case .todo: return "todo"
        case .inProgress: return "in_progress"
        case .completed: return "completed"
        case .confirmed: return "confirmed"
        }
    }

    private static func taskState(_ value: String) -> TaskState {
        switch value {
        case "todo": return .todo
        case "in_progress": return .inProgress
        case "completed": return .completed
        case "confirmed": return .confirmed
        default: return .review
        }
    }

    private enum CloudError: Error { case noHousehold }
}

private struct MembershipRow: Decodable {
    let householdID: UUID
    enum CodingKeys: String, CodingKey { case householdID = "household_id" }
}

private struct ChildUpload: Encodable {
    let id: UUID
    let householdID: UUID
    let displayName: String
    let schoolName: String
    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case displayName = "display_name"
        case schoolName = "school_name"
    }
}

private struct DocumentUpload: Encodable {
    let id: UUID
    let householdID: UUID
    let childID: UUID?
    let createdBy: UUID
    let title: String
    let imagePath: String
    let ocrText: String
    enum CodingKeys: String, CodingKey {
        case id, title
        case householdID = "household_id"
        case childID = "child_id"
        case createdBy = "created_by"
        case imagePath = "image_path"
        case ocrText = "ocr_text"
    }
}

private struct TaskUpload: Encodable {
    let id: UUID
    let householdID: UUID
    let documentID: UUID
    let childID: UUID?
    let createdBy: UUID
    let title: String
    let category: String
    let dueDate: String?
    let rawDateText: String?
    let sourceExcerpt: String
    let state: String
    let aiConfidence: String
    enum CodingKeys: String, CodingKey {
        case id, title, category, state
        case householdID = "household_id"
        case documentID = "document_id"
        case childID = "child_id"
        case createdBy = "created_by"
        case dueDate = "due_date"
        case rawDateText = "raw_date_text"
        case sourceExcerpt = "source_excerpt"
        case aiConfidence = "ai_confidence"
    }
}

private struct RemoteChild: Decodable {
    let id: UUID
    let displayName: String
    let schoolName: String
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case schoolName = "school_name"
    }
}

private struct RemoteDocument: Decodable {
    let id: UUID
    let title: String
    let imagePath: String
    let ocrText: String
    let createdAt: String
    let childID: UUID?
    enum CodingKeys: String, CodingKey {
        case id, title
        case imagePath = "image_path"
        case ocrText = "ocr_text"
        case createdAt = "created_at"
        case childID = "child_id"
    }
}

private struct RemoteTask: Decodable {
    let id: UUID
    let documentID: UUID
    let childID: UUID?
    let title: String
    let category: String
    let dueDate: String?
    let rawDateText: String?
    let sourceExcerpt: String
    let state: String
    let assigneeUserID: UUID?
    enum CodingKeys: String, CodingKey {
        case id, title, category, state
        case documentID = "document_id"
        case childID = "child_id"
        case dueDate = "due_date"
        case rawDateText = "raw_date_text"
        case sourceExcerpt = "source_excerpt"
        case assigneeUserID = "assignee_user_id"
    }
}

private struct AIExtractionResponse: Decodable {
    let ok: Bool
    let tasksCreated: Int?
    enum CodingKeys: String, CodingKey {
        case ok
        case tasksCreated = "tasks_created"
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
