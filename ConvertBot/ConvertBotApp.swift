import SwiftUI
import AppKit

@main
struct ConvertBotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 420)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ConvertBot") {
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
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
