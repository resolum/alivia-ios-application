import Foundation
import UserNotifications

/// Local notifications for the pending reminders: one per future reminder, ten minutes before it starts.
/// Everything the app scheduled carries the same identifier prefix, so it can be replaced as a whole.
final class ReminderNotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let identifierPrefix = "alivia.reminder."
    static let leadTime: TimeInterval = 10 * 60
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 64

    private let center = UNUserNotificationCenter.current()

    /// Shows the notifications as banners with sound while the app is open. Call it once at launch.
    func activate() {
        center.delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Asks for permission the first time only; later calls find the answer already given.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces what the app scheduled before with one notification per reminder that starts in more than ten minutes.
    func reschedule(_ reminders: [CareActivity], now: Date = Date()) async {
        await cancelAll()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let upcoming = reminders
            .filter { $0.startsAt.timeIntervalSince(now) > Self.leadTime }
            .sorted { $0.startsAt < $1.startsAt }
            .prefix(Self.maxPending)
        for reminder in upcoming {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "\(reminder.assistedPerson) · \(Formats.time(reminder.startTime))"
            content.sound = .default
            if reminder.priority == .high { content.interruptionLevel = .timeSensitive }
            let interval = reminder.startsAt.timeIntervalSince(now) - Self.leadTime
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: Self.identifierPrefix + reminder.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Removes every notification the app scheduled, for example when the session closes.
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
