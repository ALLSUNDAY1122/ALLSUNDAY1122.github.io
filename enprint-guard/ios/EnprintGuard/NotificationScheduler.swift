import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func schedule(for task: HouseholdTask) {
        guard task.state != .review,
              task.state != .completed,
              let dueDate = task.dueDate else { return }

        cancel(taskID: task.id)
        let calendar = Calendar.current
        let reminders: [(String, Date)] = [
            ("3d", calendar.date(byAdding: .day, value: -3, to: dueDate) ?? dueDate),
            ("1d", calendar.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate),
            ("day", dueDate)
        ]

        for (suffix, date) in reminders where date > Date() {
            let content = UNMutableNotificationContent()
            content.title = task.category == .event ? "行事の予定" : "園のタスク"
            content.body = task.title
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(task.id.uuidString)-\(suffix)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancel(taskID: UUID) {
        let ids = ["3d", "1d", "day"].map { "\(taskID.uuidString)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
