import Foundation
import UserNotifications
import AppKit

// Small helpers for posting completion/failure notifications and opening Finder

func showCompletionNotification(fileName: String) {
    let content = UNMutableNotificationContent()
    content.title = "Conversion Complete"
    content.body = "\(fileName) is ready."
    content.sound = UNNotificationSound.default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
}

func showFailureNotification(logURL: URL) {
    let content = UNMutableNotificationContent()
    content.title = "Conversion Failed"
    content.body = "FFmpeg failed. See log: \(logURL.path)"
    content.sound = UNNotificationSound.default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
}

func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
