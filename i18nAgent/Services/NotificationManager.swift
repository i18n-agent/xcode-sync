import Foundation
import AppKit

final class NotificationManager: NSObject {

    struct NotificationContent {
        let title: String
        let body: String
    }

    func requestPermission() {
        // NSUserNotificationCenter doesn't require explicit permission
    }

    func send(for result: SyncResult, projectName: String, projectDir: String? = nil) {
        let content = buildNotificationContent(for: result, projectName: projectName)

        let notification = NSUserNotification()
        notification.title = content.title
        notification.informativeText = content.body
        notification.soundName = NSUserNotificationDefaultSoundName
        if let dir = projectDir, !dir.isEmpty {
            notification.userInfo = ["projectDir": dir]
        }

        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.deliver(notification)
    }

    func buildNotificationContent(for result: SyncResult, projectName: String) -> NotificationContent {
        if let error = result.error {
            return NotificationContent(
                title: String(localized: "notificationErrorTitle \(projectName)"),
                body: error
            )
        }

        switch result.operation {
        case .pull:
            return NotificationContent(
                title: String(localized: "notificationPullTitle \(projectName)"),
                body: String(localized: "notificationPullBody \(result.languageCount) \(result.fileCount)")
            )
        case .push:
            return NotificationContent(
                title: String(localized: "notificationPushTitle \(projectName)"),
                body: String(localized: "notificationPushBody \(result.languageCount) \(result.fileCount)")
            )
        }
    }
}

// MARK: - NSUserNotificationCenterDelegate

extension NotificationManager: NSUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let dir = notification.userInfo?["projectDir"] as? String, !dir.isEmpty {
            NSWorkspace.shared.open(URL(fileURLWithPath: dir))
        }
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        true
    }
}
