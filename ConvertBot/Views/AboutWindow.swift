import SwiftUI
import AppKit

struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let v = v, let b = b { return "v\(v) (build \(b))" }
        return v ?? b ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("ConvertBot")
                    .font(.system(.title2, design: .monospaced))
                    .bold()

                Text(appVersion)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 10) {
                    Text("ConvertBot is a lightweight macOS utility for quickly converting audio and video files between common formats. It uses AVFoundation presets for typical exports and falls back to an embedded FFmpeg binary for formats not handled directly (e.g. AVI). Use the UI to pick a file, select the desired output format, and choose compression options if you need smaller files.")
                        .font(.system(.subheadline, design: .monospaced))
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text("Author:")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("thomas boom")
                            .font(.system(.footnote, design: .monospaced))
                            .bold()
                    }

                    Divider()

                    if let repoURL = URL(string: "https://github.com/thomas-boom/ConvertBot") {
                        Link(destination: repoURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                Text(repoURL.absoluteString)
                                    .font(.system(.footnote, design: .monospaced))
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 260)

            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                    if let win = NSApp.windows.first(where: { $0.title == "About ConvertBot" }) {
                        win.close()
                    } else {
                        NSApp.keyWindow?.close()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(UIConstants.outerPadding)
        .frame(minWidth: 520, minHeight: 320)
    }
}
