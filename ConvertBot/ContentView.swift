import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import UserNotifications

// `ContentView` remains the app's main view; helper types are split into separate files under
// `Helpers/` and `Views/` for readability: `ExportType`, `AudioExportType`, `FFmpegRunner`,
// `AlertMessage`, `ProgressBarView`, and `AboutWindow`.

// Main view. Helpers live in Helpers/, Views/, Utils/.
struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var selectedContentType: UTType?
    @State private var statusMessage = ""
    @State private var progress: Double = 0
    @State private var isConverting = false
    @State private var showSuccess = false
    @State private var alertMessage: AlertMessage?
    @State private var showAbout = false
    @State private var compressMedia = false
    @State private var selectedVideoPreset: String = AVAssetExportPresetHighestQuality
    @StateObject private var ffmpegRunner = FFmpegRunner()

    // Pending export selection: user must press `Export` to start
    @State private var aboutHover: Bool = false
    @State private var pendingVideoExport: ExportType?
    @State private var pendingAudioExport: AudioExportType?
    @State private var pendingDestinationURL: URL?
    @State private var exportTimer: Timer?
    @State private var exportPollTask: Task<Void, Never>?
    @State private var activeExporter: AVAssetExportSession?
    @State private var exporterCancelled: Bool = false
    @State private var hoveredVideoType: String? = nil
    @State private var hoveredAudioType: String? = nil
    @State private var compactUI: Bool = false
    @State private var lastDestinationURL: URL? = nil
    @State private var destinationLog: [URL] = []
    @State private var hoveringSavedDestination: Bool = false
    @State private var compressionExpanded: Bool = false
    @Namespace private var selectionNamespace
    
    private struct PendingExport {
        enum Kind {
            case video(ExportType)
            case audio(AudioExportType)
        }
        let kind: Kind
        let sourceURL: URL
        let compress: Bool
        let destinationURL: URL
        let openInFinder: Bool
    }

    @State private var pendingOverwriteExport: PendingExport? = nil
    @State private var showOverwriteConfirm: Bool = false

    var body: some View {
        GeometryReader { geo in
            let verticalCompact = geo.size.height < 600
            let topPadding = verticalCompact ? (UIConstants.smallSpacing / 1.5) : UIConstants.smallSpacing
            let bottomPadding = verticalCompact ? (UIConstants.smallSpacing) : UIConstants.outerPadding
            let vSpacing = verticalCompact ? UIConstants.smallSpacing : UIConstants.mediumSpacing

            ZStack {
                VStack(spacing: vSpacing) {
                // App title row (now includes About button aligned right)
                HStack {
                    VStack(alignment: .leading) {
                        Text("ConvertBot")
                            .font(.system(.title3, design: .monospaced))
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)

                        Text("by Thomas Boom")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()

                    Button(action: { showAbout.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary)
                            .opacity(aboutHover ? 1.0 : 0.95)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 28, height: 28)
                    .onHover { hovering in withAnimation(.easeInOut(duration: 0.14)) { aboutHover = hovering } }
                    .help("About ConvertBot")
                }
                    .padding(.horizontal, UIConstants.innerHorizontalPadding)

                // Main grouped controls
                Group {
                    fileSelectionView
                    // Right-aligned short subjects for major areas
                    formatSelectorsView
                    DisclosureGroup(isExpanded: $compressionExpanded) {
                        HStack(spacing: UIConstants.mediumSpacing) {
                            Toggle("Compress for smaller file size", isOn: $compressMedia)
                                .font(.system(size: 12, design: .monospaced))

                            Spacer()

                            Picker("Video Quality", selection: $selectedVideoPreset) {
                                Text("Highest Quality").tag(AVAssetExportPresetHighestQuality)
                                Text("Medium Quality").tag(AVAssetExportPresetMediumQuality)
                                Text("Low Quality").tag(AVAssetExportPresetLowQuality)
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 12, design: .monospaced))
                            .disabled(!compressMedia)
                            .opacity(compressMedia ? 1 : 0.5)
                        }
                        .padding(.vertical, 6)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Compression")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(alignment: .trailing)
                        }
                    }
                    .animation(.easeInOut, value: compressionExpanded)

                    exportControlsView
                }
                    .padding(.vertical, UIConstants.groupVerticalPadding)
                    .padding(.horizontal, UIConstants.innerHorizontalPadding)

                // Remove unnecessary placeholder spacer row to avoid extra vertical collapse
            }
            // Adjust card padding dynamically so content stays visible when vertical space is tight
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .padding(.horizontal, UIConstants.contentHorizontalPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.contentCornerRadius, style: .continuous))
            .padding(.all, verticalCompact ? (UIConstants.smallSpacing) : UIConstants.outerPadding)
        }
                .padding(.top, UIConstants.smallSpacing)
                .padding(.bottom, UIConstants.outerPadding)
                .padding(.horizontal, UIConstants.contentHorizontalPadding)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.contentCornerRadius, style: .continuous))
                .padding(.all, UIConstants.outerPadding)

            // Bottom status bar (persistent). Shows a brief idle message when not converting.
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Group {
                        if isConverting {
                            Text(statusMessage)
                        } else {
                            if statusMessage.isEmpty {
                                Text("Ready.")
                            } else if statusMessage.starts(with: "Saved to"), let url = lastDestinationURL {
                                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                                    HStack(spacing: 6) {
                                        Text("Saved to ")
                                        Image(systemName: "folder")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(url.lastPathComponent)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.accentColor.opacity(hoveringSavedDestination ? 0.06 : 0.0))
                                    )
                                    .overlay(alignment: .bottom) {
                                        if hoveringSavedDestination {
                                            ZStack {
                                                Capsule()
                                                    .fill(Color.white)
                                                    .frame(height: 4)
                                                    .padding(.horizontal, 6)
                                                    .blur(radius: 4)
                                                    .opacity(0.14)
                                                    .matchedGeometryEffect(id: "savedSelectionGlow", in: selectionNamespace)

                                                Capsule()
                                                    .fill(Color.accentColor)
                                                    .frame(height: 1)
                                                    .matchedGeometryEffect(id: "savedSelection", in: selectionNamespace)
                                                    .padding(.horizontal, 10)
                                            }
                                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                            .animation(.easeInOut(duration: 0.22), value: hoveringSavedDestination)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.16)) { hoveringSavedDestination = hovering }
                                }
                                .help("Reveal in Finder")
                            } else {
                                Text(statusMessage)
                            }
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(isConverting ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                    // Show the last-chosen destination filename (short) with a hover tooltip
                    // Show the short chosen destination only when the status line doesn't
                    // already contain the saved filename (avoid duplicate filename display).
                    if let last = lastDestinationURL, !statusMessage.starts(with: "Saved to") {
                        Text(last.lastPathComponent)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(last.path)
                            .padding(.leading, 8)
                    }

                    Spacer()

                    // FFmpeg availability indicator moved into the status bar
                    HStack(spacing: 6) {
                        if ffmpegAvailable() {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("FFmpeg")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "xmark.seal.fill")
                                .foregroundStyle(.red)
                            Text("FFmpeg missing")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                    .padding(.vertical, UIConstants.statusBarVerticalPadding)
                    .padding(.horizontal, UIConstants.statusBarHorizontalPadding)
                .background(
                    ZStack {
                        // Base material for the liquid glass effect
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)

                        // Slight tint to differentiate from the main grey background
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(isConverting ? 0.035 : 0.02))

                        // Subtle top highlight to create depth
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(LinearGradient(colors: [Color.white.opacity(0.10), Color.clear], startPoint: .top, endPoint: .bottom), lineWidth: 0.5)
                            .blendMode(.overlay)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, UIConstants.statusBarHorizontalPadding)
                    .padding(.bottom, UIConstants.smallSpacing)
                .animation(.easeInOut, value: isConverting)
            }

            
        }
        // Give the content a fixed size so the window fits the controls nicely
        .frame(minWidth: 720, minHeight: 480)
        
        // Ensure the containing NSWindow enforces a reasonable minimum size so the
        // UI never becomes unusable when the user aggressively resizes.
        .background(HostingWindowFinder { window in
            guard let w = window else { return }
            w.minSize = NSSize(width: 720, height: 480)
        })

        // No transient toast: keep the persistent status bar as the single source of truth.

        .sheet(isPresented: $showAbout) {
            AboutWindow()
        }
        .alert(item: $alertMessage) { message in
            if let log = message.logURL {
                return Alert(title: Text("Error"), message: Text(message.text), primaryButton: .default(Text("Show Log"), action: { NSWorkspace.shared.activateFileViewerSelecting([log]) }), secondaryButton: .cancel())
            } else {
                return Alert(title: Text("Error"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
        }
        .confirmationDialog("A file with the chosen name already exists.", isPresented: $showOverwriteConfirm, titleVisibility: .visible) {
            Button("Overwrite", role: .destructive) { performPendingOverwrite() }
            Button("Make unique") { performMakeUniquePendingExport() }
            Button("Cancel", role: .cancel) { pendingOverwriteExport = nil }
        } message: {
            Text("Choose whether to overwrite the existing file or save with a unique name.")
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your file has been converted successfully.")
        }
    }

    // MARK: - Small subviews to keep `body` readable
    private var fileSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedFile == nil {
                Text("Choose a media file to get started.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                Button("Choose File") { chooseFile() }
                    .buttonStyle(.bordered)

                if let f = selectedFile {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.lastPathComponent)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                        Text(f.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("No file selected")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Button("Clear") {
                    selectedFile = nil
                    selectedContentType = nil
                    pendingVideoExport = nil
                    pendingAudioExport = nil
                    statusMessage = ""
                    progress = 0
                }
                .buttonStyle(.bordered)
                .disabled(selectedFile == nil)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedFile)
    }

    private var formatSelectorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("Video")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Video Export Format")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExportType.allCases) { t in
                        let isSelected = pendingVideoExport == t
                        let isHovered = hoveredVideoType == t.id
                        Button(action: {
                            pendingVideoExport = t
                            pendingAudioExport = nil
                        }) {
                            Text(t.description)
                                .font(.system(size: 12, design: .monospaced))
                                .fontWeight(isSelected ? .semibold : .regular)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .frame(minHeight: UIConstants.controlHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
                                )
                                .overlay(alignment: .bottom) {
                                    // Animated underline for selected item; subtle hover line when not selected
                                    if isSelected {
                                        ZStack {
                                            // Subtle white glow behind the underline
                                            Capsule()
                                                .fill(Color.white)
                                                .frame(height: 8)
                                                .padding(.horizontal, 6)
                                                .blur(radius: 6)
                                                .opacity(0.28)
                                                .matchedGeometryEffect(id: "videoSelectionGlow", in: selectionNamespace)

                                            Capsule()
                                                .fill(Color.accentColor)
                                                .frame(height: 3)
                                                .matchedGeometryEffect(id: "videoSelection", in: selectionNamespace)
                                                .padding(.horizontal, 10)
                                        }
                                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                        .animation(.easeInOut(duration: 0.22), value: isSelected)
                                    } else if isHovered {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.10))
                                            .frame(height: 1)
                                            .padding(.horizontal, 12)
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.18), value: isHovered)
                                    }
                                }
                                .shadow(color: (isSelected ? Color.accentColor.opacity(0.04) : Color.clear), radius: isSelected ? 1 : 0, x: 0, y: 1)
                                .scaleEffect(isSelected ? 1.01 : 1.0)
                        }
                        // Add a helpful tooltip for formats that use the embedded FFmpeg path
                        .help(t == .mkv ? "Uses FFmpeg — may be slower" : t.description)
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                hoveredVideoType = hovering ? t.id : (hoveredVideoType == t.id ? nil : hoveredVideoType)
                            }
                        }
                        .disabled(selectedFile == nil || !isVideoSelection)
                        .opacity((selectedFile == nil || !isVideoSelection) ? 0.45 : 1.0)
                    }
                }
            }

            HStack {
                Spacer()
                Text("Audio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Audio Export Format")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AudioExportType.allCases) { a in
                        let isSelected = pendingAudioExport == a
                        let isHovered = hoveredAudioType == a.id
                        Button(action: {
                            pendingAudioExport = a
                            pendingVideoExport = nil
                        }) {
                            Text(a.description)
                                .font(.system(size: 12, design: .monospaced))
                                .fontWeight(isSelected ? .semibold : .regular)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .frame(minHeight: UIConstants.controlHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
                                )
                                .overlay(alignment: .bottom) {
                                    if isSelected {
                                        ZStack {
                                            Capsule()
                                                .fill(Color.white)
                                                .frame(height: 8)
                                                .padding(.horizontal, 6)
                                                .blur(radius: 6)
                                                .opacity(0.28)
                                                .matchedGeometryEffect(id: "audioSelectionGlow", in: selectionNamespace)

                                            Capsule()
                                                .fill(Color.accentColor)
                                                .frame(height: 3)
                                                .matchedGeometryEffect(id: "audioSelection", in: selectionNamespace)
                                                .padding(.horizontal, 10)
                                        }
                                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                        .animation(.easeInOut(duration: 0.22), value: isSelected)
                                    } else if isHovered {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.10))
                                            .frame(height: 1)
                                            .padding(.horizontal, 12)
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.18), value: isHovered)
                                    }
                                }
                                .shadow(color: (isSelected ? Color.accentColor.opacity(0.04) : Color.clear), radius: isSelected ? 1 : 0, x: 0, y: 1)
                                .scaleEffect(isSelected ? 1.01 : 1.0)
                        }
                        .help(a == .mp3 ? (ffmpegAvailable() ? "Uses FFmpeg" : "Requires FFmpeg (missing)") : a.description)
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                hoveredAudioType = hovering ? a.id : (hoveredAudioType == a.id ? nil : hoveredAudioType)
                            }
                        }
                        .disabled(selectedFile == nil || !isAudioSelection)
                        .opacity((selectedFile == nil || !isAudioSelection) ? 0.45 : 1.0)
                    }
                }
            }
        }
    }

    private var exportRowView: some View {
        HStack(spacing: 12) {
            // Export action
            Button(action: {
                guard let src = selectedFile else { alertMessage = AlertMessage(text: "Please select a file first."); return }
                if let v = pendingVideoExport {
                    let suggestedName = src.deletingLastPathComponent().lastPathComponent + ".\(v.rawValue)"
                    let allowed: [UTType]? = (UTType(filenameExtension: v.rawValue)).map { [$0] }
                    let (url, openInFinder) = runSavePanel(suggestedDirectory: src.deletingLastPathComponent(), suggestedName: suggestedName, allowedTypes: allowed)
                    if let url = url {
                        // Log the chosen destination and record it
                        lastDestinationURL = url
                        if destinationLog.last != url { destinationLog.append(url) }
                        pendingDestinationURL = url
                        pendingVideoExport = nil
                        let dest = pendingDestinationURL
                        pendingDestinationURL = nil
                        statusMessage = "Starting export to \(v.description)…"
                        Task { @MainActor in await convertVideo(at: src, to: v, compress: compressMedia, destinationURL: dest, openInFinder: openInFinder) }
                    } else {
                        statusMessage = "Export cancelled."
                    }
                } else if let a = pendingAudioExport {
                    let suggestedName = src.deletingLastPathComponent().lastPathComponent + ".\(a.rawValue)"
                    let allowed: [UTType]? = (UTType(filenameExtension: a.rawValue)).map { [$0] }
                    let (url, openInFinder) = runSavePanel(suggestedDirectory: src.deletingLastPathComponent(), suggestedName: suggestedName, allowedTypes: allowed)
                    if let url = url {
                        // Log the chosen destination and record it
                        lastDestinationURL = url
                        if destinationLog.last != url { destinationLog.append(url) }
                        pendingDestinationURL = url
                        pendingAudioExport = nil
                        let dest = pendingDestinationURL
                        pendingDestinationURL = nil
                        statusMessage = "Starting export to \(a.description)…"
                        Task { @MainActor in await convertAudio(at: src, to: a, compress: compressMedia, destinationURL: dest, openInFinder: openInFinder) }
                    } else {
                        statusMessage = "Export cancelled."
                    }
                }
            }) {
                Text("Export")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConverting || (pendingVideoExport == nil && pendingAudioExport == nil) || selectedFile == nil)

            Spacer()

            HStack(spacing: 8) {
                    ProgressBarView(progress: progress)
                        .frame(maxWidth: 420, maxHeight: UIConstants.progressBarHeight)
                        .padding(.leading, 6)
                        .opacity(progress > 0 ? 1 : 0.65)
            }

            Spacer()

            Button("Cancel") {
                if ffmpegRunner.isRunning {
                    ffmpegRunner.cancel()
                    statusMessage = "Cancelling…"
                } else if let exporter = activeExporter {
                    exporter.cancelExport()
                    exporterCancelled = true
                    exportTimer?.invalidate()
                    exportTimer = nil
                    activeExporter = nil
                    statusMessage = "Cancelling…"
                } else {
                    statusMessage = "Cancelling…"
                }
            }
            .buttonStyle(.bordered)
            .disabled(!isConverting)
        }
    }

    private var exportControlsView: some View {
        HStack {
            exportRowView
                .frame(maxWidth: .infinity)
        }
    }

    // Removed `progressStatusView` to avoid duplicating status text; the bottom status bar
    // now provides a single, persistent status line for the app.
    

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
    private func convertVideo(at sourceURL: URL, to type: ExportType, compress: Bool, destinationURL: URL? = nil, openInFinder: Bool = false, forceOverwrite: Bool = false) async {
        isConverting = true; progress = 0
        statusMessage = "Preparing video…"
        // If the caller provided a destination URL (from Save panel), respect it but prevent
        // accidental overwrites: if the file already exists and we were not forced to overwrite,
        // prompt the user to confirm.
        if let dest = destinationURL {
            if FileManager.default.fileExists(atPath: dest.path) {
                if !forceOverwrite {
                    pendingOverwriteExport = PendingExport(kind: .video(type), sourceURL: sourceURL, compress: compress, destinationURL: dest, openInFinder: openInFinder)
                    showOverwriteConfirm = true
                    isConverting = false
                    return
                } else {
                    // attempt to remove existing file before overwriting
                    do { try FileManager.default.removeItem(at: dest) } catch {
                        isConverting = false
                        alertMessage = AlertMessage(text: "Failed to overwrite existing file: \(error.localizedDescription)")
                        return
                    }
                }
            }
        }

        let destinationURL = destinationURL ?? uniqueURL(base: sourceURL.deletingPathExtension(), ext: type.rawValue)
        // Record final chosen destination
        if lastDestinationURL != destinationURL {
            lastDestinationURL = destinationURL
            if destinationLog.last != destinationURL { destinationLog.append(destinationURL) }
        }
        // Record final chosen destination
        if lastDestinationURL != destinationURL {
            lastDestinationURL = destinationURL
            if destinationLog.last != destinationURL { destinationLog.append(destinationURL) }
        }

        // If exporting to AVI or MKV, use FFmpeg (AVFoundation doesn't natively export these)
        if type == .avi || type == .mkv {
            statusMessage = "Converting to \(type.description) via FFmpeg…"

            guard let ffmpegURL = ffmpegExecutableURL() else {
                alertMessage = AlertMessage(text: "FFmpeg binary not found in app bundle or common system paths.")
                isConverting = false
                return
            }

            // Prepare ffmpeg args depending on container
            let args: [String]
            if type == .avi {
                // Use MPEG4 for AVI to maximize compatibility
                args = ["-y", "-i", sourceURL.path, "-c:v", "mpeg4", "-q:v", "5", destinationURL.path]
            } else {
                // MKV: encode using libx264 with a reasonable CRF for quality/size balance
                args = ["-y", "-i", sourceURL.path, "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-c:a", "copy", destinationURL.path]
            }

            // Attempt to determine duration from the asset so we can show percent; if unavailable,
            // try to extract it from ffmpeg's initial stderr "Duration: hh:mm:ss" line.
            let srcAsset = AVURLAsset(url: sourceURL)
            var durationSeconds: Double? = nil
            do {
                let dur = try await srcAsset.load(.duration)
                if dur.isValid { durationSeconds = CMTimeGetSeconds(dur) }
            } catch {
                // ignore load errors; duration may be unavailable
                durationSeconds = nil
            }

            // Keep a mutable total that we can update if ffmpeg prints a Duration line
            var ffTotal: Double? = durationSeconds
            // Estimated total used while ffTotal is unknown; will be updated as time progresses
            var ffEstimatedTotal: Double? = nil

            // Run ffmpeg via runner
            let exit = await ffmpegRunner.run(ffmpegURL: ffmpegURL, arguments: args, durationSeconds: durationSeconds) { timeOrNil, raw in
                // Try to detect a Duration line in ffmpeg stderr when we don't have a total yet.
                if ffTotal == nil, let range = raw.range(of: "Duration:") {
                    // ffmpeg usually prints: "  Duration: 00:01:23.45, start: ..."
                    let after = raw[range.upperBound...]
                    let durToken = after.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !durToken.isEmpty, let parsed = FFmpegRunner.timeStringToSeconds(durToken) {
                        ffTotal = parsed
                    }
                }

                DispatchQueue.main.async {
                    if let t = timeOrNil {
                        if let total = ffTotal, total > 0 {
                            // We know the real total: show accurate percent
                            let pct = min(max(t / total, 0), 1)
                            progress = pct
                            statusMessage = "Converting \(type.description) — \(formatTime(t)) / \(formatTime(total))"
                        } else {
                            // No total yet: maintain an estimated total that grows as time progresses.
                            // Start with a conservative estimate (double the elapsed) so early progress
                            // shows forward motion without immediately hitting 100%.
                            if ffEstimatedTotal == nil {
                                // Use a minimum guess of 30s to avoid tiny denominators
                                ffEstimatedTotal = max(30.0, t * 2.0)
                            } else {
                                // Gradually increase the estimate if elapsed reaches it (assume longer job)
                                if t > (ffEstimatedTotal ?? 0) * 0.9 {
                                    ffEstimatedTotal = (ffEstimatedTotal ?? (t * 2.0)) * 1.25
                                }
                            }

                            if let est = ffEstimatedTotal, est > 0 {
                                let pct = min(0.98, max(0.0, t / est))
                                progress = pct
                            } else {
                                // Fallback soft progress
                                progress = min(0.95, 0.02 + tanh(t / 60.0) * 0.6)
                            }

                            statusMessage = "Converting \(type.description) — time \(formatTime(t))"
                        }
                    } else {
                        // Use raw stderr line as status fallback
                        statusMessage = raw
                    }
                }
            }

            if exit == 0 {
                progress = 1
                statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                showSuccess = true
                if openInFinder { NSWorkspace.shared.activateFileViewerSelecting([destinationURL]) }
                NSSound(named: NSSound.Name("Glass"))?.play()
                showCompletionNotification(fileName: destinationURL.lastPathComponent)
            } else if exit == -1 {
                let log = ffmpegRunner.logURL
                alertMessage = AlertMessage(text: "FFmpeg failed to start. Check the binary is executable.", logURL: log)
                statusMessage = "Failed."
                if let log = log { showFailureNotification(logURL: log) }
            } else {
                let log = ffmpegRunner.logURL
                alertMessage = AlertMessage(text: "FFmpeg conversion failed with code \(exit).", logURL: log)
                statusMessage = "Failed."
                if let log = log { showFailureNotification(logURL: log) }
            }

            isConverting = false
            return
        }

        // For non-AVI files, use AVAssetExportSession
        let asset = AVURLAsset(url: sourceURL)
        do { _ = try await asset.load(.duration) } catch { }
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

        // Hold reference so Cancel can call cancelExport()
        exporterCancelled = false
        activeExporter = exporter

        // Poll exporter.progress on a Task to avoid @Sendable capture warnings
        exportPollTask = Task { @MainActor in
            while activeExporter === exporter {
                progress = Double(exporter.progress)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }

        do {
            try await exporter.export(to: destinationURL, as: type.utType)
            progress = 1
            statusMessage = "Saved to \(destinationURL.lastPathComponent)"
            showSuccess = true
            if openInFinder { NSWorkspace.shared.activateFileViewerSelecting([destinationURL]) }
            NSSound(named: NSSound.Name("Glass"))?.play()
            showCompletionNotification(fileName: destinationURL.lastPathComponent)
        } catch {
            if exporterCancelled {
                statusMessage = "Cancelled."
            } else {
                alertMessage = AlertMessage(text: error.localizedDescription)
                statusMessage = "Failed."
            }
        }

        // Clean up references
        exportPollTask?.cancel()
        exportPollTask = nil
        exportTimer?.invalidate()
        exportTimer = nil
        activeExporter = nil
        isConverting = false
    }

    @MainActor
    private func convertAudio(at sourceURL: URL, to type: AudioExportType, compress: Bool, destinationURL: URL? = nil, openInFinder: Bool = false, forceOverwrite: Bool = false) async {
        isConverting = true; progress = 0; statusMessage = "Preparing audio…"
        // If the caller provided a destination URL (from Save panel), respect it but prevent
        // accidental overwrites: if the file already exists and we were not forced to overwrite,
        // prompt the user to confirm.
        if let dest = destinationURL {
            if FileManager.default.fileExists(atPath: dest.path) {
                if !forceOverwrite {
                    pendingOverwriteExport = PendingExport(kind: .audio(type), sourceURL: sourceURL, compress: compress, destinationURL: dest, openInFinder: openInFinder)
                    showOverwriteConfirm = true
                    isConverting = false
                    return
                } else {
                    do { try FileManager.default.removeItem(at: dest) } catch {
                        isConverting = false
                        alertMessage = AlertMessage(text: "Failed to overwrite existing file: \(error.localizedDescription)")
                        return
                    }
                }
            }
        }

        let destinationURL = destinationURL ?? uniqueURL(base: sourceURL.deletingPathExtension(), ext: type.rawValue)
        let asset = AVURLAsset(url: sourceURL)
        do { _ = try await asset.load(.duration) } catch { }

        // MP3 is handled exclusively by FFmpeg — AVFoundation does not provide
        // a reliable MP3 encoder on macOS. Route MP3 exports to FFmpeg immediately.
        if type == .mp3 {
            statusMessage = "Converting MP3 via FFmpeg…"
            guard let ffmpegURL = ffmpegExecutableURL() else {
                alertMessage = AlertMessage(text: "FFmpeg binary not found in app bundle or common system paths.")
                isConverting = false
                return
            }

            let args = ["-y", "-i", sourceURL.path, "-codec:a", "libmp3lame", "-q:a", "2", destinationURL.path]

            var durationSeconds: Double? = nil
            do {
                let dur = try await asset.load(.duration)
                if dur.isValid { durationSeconds = CMTimeGetSeconds(dur) }
            } catch { }

            var ffTotal: Double? = durationSeconds
            var ffEstimatedTotal: Double? = nil

            let exit = await ffmpegRunner.run(ffmpegURL: ffmpegURL, arguments: args, durationSeconds: durationSeconds) { timeOrNil, raw in
                if ffTotal == nil, let range = raw.range(of: "Duration:") {
                    let after = raw[range.upperBound...]
                    let durToken = after.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !durToken.isEmpty, let parsed = FFmpegRunner.timeStringToSeconds(durToken) {
                        ffTotal = parsed
                    }
                }

                DispatchQueue.main.async {
                    if let t = timeOrNil {
                        if let total = ffTotal, total > 0 {
                            let pct = min(max(t / total, 0), 1)
                            progress = pct
                            statusMessage = "Converting MP3 — \(formatTime(t)) / \(formatTime(total))"
                        } else {
                            if ffEstimatedTotal == nil {
                                ffEstimatedTotal = max(30.0, t * 2.0)
                            } else {
                                if t > (ffEstimatedTotal ?? 0) * 0.9 {
                                    ffEstimatedTotal = (ffEstimatedTotal ?? (t * 2.0)) * 1.25
                                }
                            }

                            if let est = ffEstimatedTotal, est > 0 {
                                let pct = min(0.98, max(0.0, t / est))
                                progress = pct
                            } else {
                                progress = min(0.95, 0.02 + tanh(t / 60.0) * 0.6)
                            }

                            statusMessage = "Converting MP3 — time \(formatTime(t))"
                        }
                    } else {
                        statusMessage = raw
                    }
                }
            }

            if exit == 0 {
                progress = 1
                statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                showSuccess = true
                if openInFinder { NSWorkspace.shared.activateFileViewerSelecting([destinationURL]) }
                NSSound(named: NSSound.Name("Glass"))?.play()
                showCompletionNotification(fileName: destinationURL.lastPathComponent)
            } else if exit == -1 {
                let log = ffmpegRunner.logURL
                alertMessage = AlertMessage(text: "FFmpeg failed to start. Check the binary is executable.", logURL: log)
                statusMessage = "Failed."
                if let log = log { showFailureNotification(logURL: log) }
            } else {
                let log = ffmpegRunner.logURL
                alertMessage = AlertMessage(text: "FFmpeg conversion failed with code \(exit).", logURL: log)
                statusMessage = "Failed."
                if let log = log { showFailureNotification(logURL: log) }
            }

            isConverting = false
            return
        }

        var exporter: AVAssetExportSession?
        let presetsToTry: [String]
        if compress {
            switch type {
            case .m4a, .aac:
                presetsToTry = [AVAssetExportPresetAppleM4A]
            case .mp3:
                // MP3 support via AVFoundation is not guaranteed; try passthrough first.
                presetsToTry = [AVAssetExportPresetPassthrough]
            case .wav, .aiff:
                presetsToTry = [AVAssetExportPresetAppleM4A, AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]
            }
        } else {
            presetsToTry = type.preferredPresets
        }

        for preset in presetsToTry {
            if let session = AVAssetExportSession(asset: asset, presetName: preset), session.supportedFileTypes.contains(type.utType) {
                exporter = session
                break
            }
        }

        // If AVFoundation could not produce an exporter and the user requested MP3,
        // fall back to FFmpeg and inform the user via the status bar.
        if let audioExporter = exporter {
            audioExporter.outputURL = destinationURL
            audioExporter.outputFileType = type.utType
            audioExporter.shouldOptimizeForNetworkUse = true
            statusMessage = "Converting audio…"

            // Hold reference to allow cancellation
            exporterCancelled = false
            activeExporter = audioExporter
            exportPollTask = Task { @MainActor in
                while activeExporter === audioExporter {
                    progress = Double(audioExporter.progress)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }

            do {
                try await audioExporter.export(to: destinationURL, as: type.utType)
                progress = 1
                statusMessage = "Saved to \(destinationURL.lastPathComponent)"
                showSuccess = true
                if openInFinder { NSWorkspace.shared.activateFileViewerSelecting([destinationURL]) }
                NSSound(named: NSSound.Name("Glass"))?.play()
                showCompletionNotification(fileName: destinationURL.lastPathComponent)
            } catch {
                if exporterCancelled {
                    statusMessage = "Cancelled."
                } else {
                    alertMessage = AlertMessage(text: error.localizedDescription)
                    statusMessage = "Failed."
                }
            }
        } else {
            isConverting = false
            alertMessage = AlertMessage(text: "macOS could not create an audio export session for this combination.")
            return
        }
        // Clean up
        exportPollTask?.cancel()
        exportPollTask = nil
        exportTimer?.invalidate()
        exportTimer = nil
        activeExporter = nil
        isConverting = false
    }

    // Notifications are provided by `Utils/Notifications.swift`.

    // MARK: - Helpers

    // Transient toast helper removed — we rely on the persistent status bar only.

    private func performPendingOverwrite() {
        guard let pending = pendingOverwriteExport else { return }
        let dest = pending.destinationURL
        // attempt to remove the existing file
        if FileManager.default.fileExists(atPath: dest.path) {
            do { try FileManager.default.removeItem(at: dest) } catch {
                alertMessage = AlertMessage(text: "Could not remove existing file: \(error.localizedDescription)")
                pendingOverwriteExport = nil
                showOverwriteConfirm = false
                return
            }
        }
        // Clear pending and trigger the actual export with forceOverwrite = true
        pendingOverwriteExport = nil
        showOverwriteConfirm = false
        switch pending.kind {
        case .video(let type):
            Task { @MainActor in await convertVideo(at: pending.sourceURL, to: type, compress: pending.compress, destinationURL: dest, openInFinder: pending.openInFinder, forceOverwrite: true) }
        case .audio(let a):
            Task { @MainActor in await convertAudio(at: pending.sourceURL, to: a, compress: pending.compress, destinationURL: dest, openInFinder: pending.openInFinder, forceOverwrite: true) }
        }
    }

    private func performMakeUniquePendingExport() {
        guard let pending = pendingOverwriteExport else { return }
        let dest = pending.destinationURL
        // Compute a unique URL using the helper (base without extension, ext = pathExtension)
        let unique = uniqueURL(base: dest.deletingPathExtension(), ext: dest.pathExtension)
        // Clear pending and trigger the actual export to the unique path
        pendingOverwriteExport = nil
        showOverwriteConfirm = false
        switch pending.kind {
        case .video(let type):
            Task { @MainActor in await convertVideo(at: pending.sourceURL, to: type, compress: pending.compress, destinationURL: unique, openInFinder: pending.openInFinder, forceOverwrite: false) }
        case .audio(let a):
            Task { @MainActor in await convertAudio(at: pending.sourceURL, to: a, compress: pending.compress, destinationURL: unique, openInFinder: pending.openInFinder, forceOverwrite: false) }
        }
    }

    private var isVideoSelection: Bool {
        guard let t = selectedContentType else { return false }
        return t.conforms(to: .movie) || t.conforms(to: .video)
    }

    private var isAudioSelection: Bool {
        guard let t = selectedContentType else { return false }
        return t.conforms(to: .audio)
    }

    // Utilities such as `ffmpegAvailable()`, `ffmpegExecutableURL()`, `uniqueURL(base:ext:)`, and
    // `formatTime(_:)` are provided by `Utils/Utilities.swift`. The visual progress bar is in
    // `Views/ProgressBarView.swift` and used above.
}
