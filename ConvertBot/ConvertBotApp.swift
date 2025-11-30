import SwiftUI
import AppKit
import UserNotifications

@main
struct ConvertBotApp: App {
    init() {
        // Request notification permission on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("Notification auth error: %@", String(describing: error))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowToolbarStyle(.unifiedCompact)
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button("About ConvertBot") {
                        let window = NSWindow(
                            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                            styleMask: [.titled, .closable, .miniaturizable],
                            backing: .buffered,
                            defer: false
                        )
                        window.center()
                        window.title = "About ConvertBot"
                        window.contentView = NSHostingView(rootView: AboutWindow())
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
    }
}
