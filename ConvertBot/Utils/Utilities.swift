import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// Utilities used across the app

func ffmpegAvailable() -> Bool {
    if Bundle.main.url(forResource: "ffmpeg", withExtension: nil) != nil { return true }
    let candidates = ["/usr/local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/bin/ffmpeg"]
    for p in candidates {
        if FileManager.default.isExecutableFile(atPath: p) { return true }
    }
    // Also check Application Support (installer path)
    if let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.ConvertBot"
        let candidate = appSupport.appendingPathComponent(bundleId).appendingPathComponent("ffmpeg")
        if FileManager.default.isExecutableFile(atPath: candidate.path) { return true }
    }
    return false
}

func ffmpegExecutableURL() -> URL? {
    if let b = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) { return b }
    if let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.ConvertBot"
        let candidate = appSupport.appendingPathComponent(bundleId).appendingPathComponent("ffmpeg")
        if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
    }
    let candidates = ["/usr/local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/bin/ffmpeg"]
    for p in candidates {
        if FileManager.default.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
    }
    return nil
}

func uniqueURL(base: URL, ext: String) -> URL {
    var dest = base.appendingPathExtension(ext)
    var counter = 1
    while FileManager.default.fileExists(atPath: dest.path) {
        let name = "\(base.lastPathComponent)-\(counter)"
        dest = base.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(ext)
        counter += 1
    }
    return dest
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "--:--" }
    let s = Int(seconds.rounded())
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%02d:%02d", m, sec)
}

/// Present a `NSSavePanel` with a small accessory checkbox and return the chosen URL and
/// whether the user checked "Open in Finder when finished".
/// - Parameters:
///   - suggestedDirectory: optional directory to show when presenting the panel
///   - suggestedName: a suggested filename to pre-fill
///   - allowedTypes: optional array of `UTType` values to limit allowed file types
/// - Returns: `(selectedURL, openInFinder)` tuple. If user cancels, `selectedURL` is `nil`.
func runSavePanel(suggestedDirectory: URL?, suggestedName: String, allowedTypes: [UTType]?) -> (URL?, Bool) {
    let panel = NSSavePanel()
    panel.directoryURL = suggestedDirectory
    panel.nameFieldStringValue = suggestedName
    if let types = allowedTypes { panel.allowedContentTypes = types }

    let openCheckbox = NSButton(checkboxWithTitle: "Open in Finder when finished", target: nil, action: nil)
    panel.accessoryView = openCheckbox

    let resp = panel.runModal()
    if resp == .OK, let url = panel.url {
        return (url, openCheckbox.state == .on)
    }
    return (nil, false)
}
