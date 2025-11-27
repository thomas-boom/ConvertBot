import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import UserNotifications

enum ExportType: String, CaseIterable, Identifiable {
    case mov, mp4, m4v
    var id: String { rawValue }

    var description: String {
        switch self {
        case .mov: return "MOV"
        case .mp4: return "MP4"
        case .m4v: return "M4V"
        }
    }

    var utType: AVFileType {
        switch self {
        case .mov: return .mov
        case .mp4: return .mp4
        case .m4v: return .m4v
        }
    }
}

enum AudioExportType: String, CaseIterable, Identifiable {
    case m4a, wav, caf, aac, aiff
    var id: String { rawValue }

    var description: String { rawValue.uppercased() }

    var utType: AVFileType {
        switch self {
        case .m4a: return .m4a
        case .wav: return .wav
        case .caf: return .caf
        case .aac: return .m4a
        case .aiff: return .aiff
        }
    }

    var preferredPresets: [String] {
        switch self {
        case .m4a:
            return [AVAssetExportPresetAppleM4A, AVAssetExportPresetPassthrough]
        case .aac:
            return [AVAssetExportPresetAppleM4A]
        case .wav, .caf, .aiff:
            return [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]
        }
    }
}

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var selectedContentType: UTType?
    @State private var statusMessage = "Choose a media file to get started."
    @State private var progress: Double = 0
    @State private var isConverting = false
    @State private var showSuccess = false
    @State private var alertMessage: AlertMessage?
    @State private var showAbout = false
    @State private var compressMedia = false
    @State private var selectedVideoPreset: String = AVAssetExportPresetPassthrough

    init() {
        // Request notification permission on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error { print("Notification auth error: \(error)") }
        }
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 20) {
                Text("ConvertBot")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))

                Text(statusMessage)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Divider()

                Label(selectedFile?.lastPathComponent ?? "No file selected", systemImage: "film")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(selectedFile == nil ? .secondary : .primary)

                HStack(spacing: 16) {
                    Button("Choose Media…", action: chooseFile)
                        .buttonStyle(.borderedProminent)

                    Menu("Convert Video…") {
                        ForEach(ExportType.allCases) { type in
                            Button("Convert to \(type.description)") {
                                convertSelectedFile(to: type)
                            }
                        }
                    }
                    .disabled(selectedFile == nil || isConverting || !isVideoSelection)

                    Menu("Convert Audio…") {
                        ForEach(AudioExportType.allCases) { type in
                            Button("Convert to \(type.description)") {
                                convertSelectedAudioFile(to: type)
                            }
                        }
                    }
                    .disabled(selectedFile == nil || isConverting || !isAudioSelection)

                    if isConverting {
                        ProgressView()
                    }
                }

                Toggle("Compress for smaller file size", isOn: $compressMedia)
                    .font(.system(size: 12, design: .monospaced))

                Picker("Video Quality", selection: $selectedVideoPreset) {
                    if selectedFile != nil {
                        // Only show Passthrough if it's different from source file
                        if selectedVideoPreset != AVAssetExportPresetPassthrough {
                            Text("Passthrough (original)").tag(AVAssetExportPresetPassthrough)
                        }
                    }
                    Text("Highest Quality").tag(AVAssetExportPresetHighestQuality)
                    Text("Medium Quality").tag(AVAssetExportPresetMediumQuality)
                    Text("Low Quality").tag(AVAssetExportPresetLowQuality)
                }
                .pickerStyle(.menu)
                .font(.system(size: 12, design: .monospaced))
                .disabled(!compressMedia)
                .opacity(compressMedia ? 1 : 0.5)

                // Progress display
                progressBar

                Spacer()
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding()

            // Bottom-left ? button
            VStack {
                Spacer()
                HStack {
                    Button(action: { showAbout.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.borderless)
                    .padding()
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutWindow()
        }
        .alert(item: $alertMessage) { message in
            Alert(title: Text("Error"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your file has been converted successfully.")
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        let videoTypes: [UTType] = [.mpeg4Movie, .movie, .quickTimeMovie, .avi, UTType(filenameExtension: "m4v"), .video].compactMap { $0 }
        let audioTypes: [UTType] = [.audio, .mp3, .wav, .aiff, UTType(filenameExtension: "aifc"), UTType(filenameExtension: "caf"), UTType(filenameExtension: "flac"), .midi, .appleProtectedMPEG4Audio, .appleProtectedMPEG4Video].compactMap { $0 }
        panel.allowedContentTypes = videoTypes + audioTypes
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            selectedFile = panel.url
            if let ext = panel.url?.pathExtension.lowercased(), !ext.isEmpty, let kind = UTType(filenameExtension: ext) {
                selectedContentType = kind
            } else {
                selectedContentType = nil
            }
            statusMessage = "Ready to convert."
            progress = 0
        }
    }

    private func convertSelectedFile(to type: ExportType) {
        guard let url = selectedFile else { alertMessage = AlertMessage(text: "Please select a file first."); return }
        guard isVideoSelection else { alertMessage = AlertMessage(text: "Selected file is not a video. Pick a video file for this option."); return }
        let compress = compressMedia
        Task { @MainActor in await convertVideo(at: url, to: type, compress: compress) }
    }

    private func convertSelectedAudioFile(to type: AudioExportType) {
        guard let url = selectedFile else { alertMessage = AlertMessage(text: "Please select a file first."); return }
        guard isAudioSelection else { alertMessage = AlertMessage(text: "Selected file is not recognized as audio."); return }
        let compress = compressMedia
        Task { @MainActor in await convertAudio(at: url, to: type, compress: compress) }
    }

    @MainActor
    private func convertVideo(at sourceURL: URL, to type: ExportType, compress: Bool) async {
        isConverting = true; progress = 0
        statusMessage = "Preparing video…"

        let destinationURL = uniqueURL(base: sourceURL.deletingPathExtension(), ext: type.rawValue)

        // Use FFmpeg for AVI files
        if sourceURL.pathExtension.lowercased() == "avi" {
            statusMessage = "Converting AVI via FFmpeg…"

            guard let ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) else {
                alertMessage = AlertMessage(text: "FFmpeg binary not found in app bundle.")
                isConverting = false
                return
            }

            let process = Process()
            process.executableURL = ffmpegURL
            process.arguments = ["-i", sourceURL.path, destinationURL.path]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                // Polling FFmpeg progress is complex; for simplicity just wait
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    progress = 1
                    statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                    showSuccess = true
                    NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                    NSSound(named: NSSound.Name("Glass"))?.play()
                    showCompletionNotification(fileName: destinationURL.lastPathComponent)
                } else {
                    alertMessage = AlertMessage(text: "FFmpeg conversion failed with code \(process.terminationStatus).")
                    statusMessage = "Failed."
                }
            } catch {
                alertMessage = AlertMessage(text: "FFmpeg failed: \(error.localizedDescription)")
                statusMessage = "Failed."
            }

            isConverting = false
            return
        }

        // For non-AVI files, use AVAssetExportSession
        let asset = AVAsset(url: sourceURL)
        let presetsToTry: [String] = compress
            ? [selectedVideoPreset]
            : [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]

        var session: AVAssetExportSession?
        for preset in presetsToTry {
            if let s = AVAssetExportSession(asset: asset, presetName: preset), s.supportedFileTypes.contains(type.utType) { session = s; break }
        }

        guard let exporter = session else {
            isConverting = false
            alertMessage = AlertMessage(text: "No compatible export preset available. Try a different format.")
            return
        }

        exporter.outputURL = destinationURL
        exporter.outputFileType = type.utType
        exporter.shouldOptimizeForNetworkUse = true
        statusMessage = "Converting video…"

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress = Double(exporter.progress)
        }

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                timer.invalidate()
                DispatchQueue.main.async {
                    switch exporter.status {
                    case .completed:
                        progress = 1
                        statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                        showSuccess = true
                        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                        NSSound(named: NSSound.Name("Glass"))?.play()
                        showCompletionNotification(fileName: destinationURL.lastPathComponent)
                    case .failed:
                        alertMessage = AlertMessage(text: exporter.error?.localizedDescription ?? "Unknown conversion error.")
                        statusMessage = "Failed."
                    case .cancelled:
                        statusMessage = "Cancelled."
                    default: break
                    }
                    isConverting = false
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func convertAudio(at sourceURL: URL, to type: AudioExportType, compress: Bool) async {
        isConverting = true; progress = 0; statusMessage = "Preparing audio…"
        let destinationURL = uniqueURL(base: sourceURL.deletingPathExtension(), ext: type.rawValue)
        let asset = AVAsset(url: sourceURL)
        var exporter: AVAssetExportSession?
        let presetsToTry: [String]
        if compress {
            // Prefer more compressed formats/presets for smaller file sizes
            switch type {
            case .m4a, .aac:
                presetsToTry = [AVAssetExportPresetAppleM4A]
            case .wav, .caf, .aiff:
                // No real compressed preset for these, but try highest quality second
                presetsToTry = [AVAssetExportPresetAppleM4A, AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]
            }
        } else {
            presetsToTry = type.preferredPresets
        }
        for preset in presetsToTry {
            if let session = AVAssetExportSession(asset: asset, presetName: preset), session.supportedFileTypes.contains(type.utType) { exporter = session; break }
        }
        guard let audioExporter = exporter else { isConverting = false; alertMessage = AlertMessage(text: "macOS could not create an audio export session for this combination."); return }
        audioExporter.outputURL = destinationURL; audioExporter.outputFileType = type.utType; audioExporter.shouldOptimizeForNetworkUse = true
        statusMessage = "Converting audio…"
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in progress = Double(audioExporter.progress) }
        await withCheckedContinuation { continuation in
            audioExporter.exportAsynchronously {
                timer.invalidate()
                DispatchQueue.main.async {
                    switch audioExporter.status {
                    case .completed:
                        progress = 1
                        statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                        showSuccess = true
                        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                        NSSound(named: NSSound.Name("Glass"))?.play()
                        showCompletionNotification(fileName: destinationURL.lastPathComponent)
                    case .failed:
                        alertMessage = AlertMessage(text: audioExporter.error?.localizedDescription ?? "Unknown audio conversion error.")
                        statusMessage = "Failed."
                    case .cancelled:
                        statusMessage = "Cancelled."
                    default: break
                    }
                    isConverting = false; continuation.resume()
                }
            }
        }
    }

    private func showCompletionNotification(fileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conversion Complete"
        content.body = "\(fileName) is ready."
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private var isVideoSelection: Bool {
        guard let t = selectedContentType else { return false }
        return t.conforms(to: .movie) || t.conforms(to: .video)
    }

    private var isAudioSelection: Bool {
        guard let t = selectedContentType else { return false }
        return t.conforms(to: .audio)
    }

    private func uniqueURL(base: URL, ext: String) -> URL {
        var dest = base.appendingPathExtension(ext)
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let name = "\(base.lastPathComponent)-\(counter)"
            dest = base.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(ext)
            counter += 1
        }
        return dest
    }

    private var progressBar: some View {
        let barHeight: CGFloat = 16
        let cornerRadius: CGFloat = 14
        let fillInset: CGFloat = 2

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .frame(height: barHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: cornerRadius - fillInset)
                        .fill(Color.pink.opacity(0.7))
                        .frame(width: max(geo.size.width * CGFloat(progress) - fillInset * 2, 0), height: barHeight - fillInset * 2)
                        .animation(.easeInOut(duration: 0.2), value: progress)
                        .offset(x: fillInset, y: fillInset)
                }
                .frame(height: barHeight)
            }

            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// Simple alert wrapper used by the view
private struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

// Minimal About window shown by the sheet; keep lightweight for now
struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let v = v, let b = b { return "v\(v) (build \(b))" }
        return v ?? b ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("ConvertBot")
                    .font(.title2)
                    .bold()

                Text(appVersion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("ConvertBot is a lightweight macOS utility for quickly converting audio and video files between common formats. It uses AVFoundation presets for typical exports and falls back to an embedded FFmpeg binary for formats not handled directly (e.g. AVI). Use the UI to pick a file, select the desired output format, and choose compression options if you need smaller files.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            HStack(spacing: 8) {
                Text("Author:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("thomas boom")
                    .font(.footnote)
                    .bold()
            }

            Divider()

            HStack {
                Spacer()
                Button("OK") {
                    // Dismiss sheet presentation
                    dismiss()

                    // Close any standalone About window opened programmatically
                    if let win = NSApp.windows.first(where: { $0.title == "About ConvertBot" }) {
                        win.close()
                    } else {
                        NSApp.keyWindow?.close()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 220)
    }
}
