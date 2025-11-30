import Foundation
import Combine

final class FFmpegRunner: ObservableObject {
    private(set) var process: Process?
    private(set) var logURL: URL?
    @Published var isRunning: Bool = false

    // Serial queue and buffer for processing ffmpeg stderr safely across threads.
    private let bufferQueue = DispatchQueue(label: "com.convertbot.ffmpeg.stderr")
    private var stderrBuffer: String = ""

    func run(ffmpegURL: URL, arguments: [String], durationSeconds: Double?, progressHandler: @escaping (Double?, String) -> Void) async -> Int32 {
        let tmp = FileManager.default.temporaryDirectory
        let logFile = tmp.appendingPathComponent("ffmpeg-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logFile.path, contents: nil, attributes: nil)
        await MainActor.run { [weak self] in
            self?.logURL = logFile
        }

        let pipe = Pipe()
        let outHandle = pipe.fileHandleForReading

        let fh = try? FileHandle(forWritingTo: logFile)

        let proc = Process()
        proc.executableURL = ffmpegURL
        proc.arguments = arguments
        proc.standardError = pipe
        proc.standardOutput = Pipe()

        await MainActor.run { [weak self] in
            self?.process = proc
            self?.isRunning = true
        }

        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            guard let chunk = String(data: data, encoding: .utf8) else { return }

            // Append to temp log (best-effort)
            if let fh = fh, let d = chunk.data(using: .utf8) {
                try? fh.write(contentsOf: d)
            }
            // Offload parsing to a helper to keep the handler body small.
            self?.processChunk(chunk, progressHandler: progressHandler)
        }

        let exitStatus: Int32 = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            proc.terminationHandler = { p in
                outHandle.readabilityHandler = nil
                if let fh = fh {
                    try? fh.close()
                }
                continuation.resume(returning: p.terminationStatus)
            }

            do {
                try proc.run()
            } catch {
                outHandle.readabilityHandler = nil
                if let fh = fh {
                    try? fh.close()
                }
                continuation.resume(returning: -1)
            }
        }

        await MainActor.run { [weak self] in
            self?.isRunning = false
            self?.process = nil
        }
        return exitStatus
    }

    // Process a chunk of stderr text on the internal buffer queue and call the progress handler
    private func processChunk(_ chunk: String, progressHandler: @escaping (Double?, String) -> Void) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            self.stderrBuffer += chunk
            let lines = self.stderrBuffer.components(separatedBy: "\n")
            let processLines: [String]
            if !self.stderrBuffer.hasSuffix("\n") {
                processLines = Array(lines.dropLast())
                self.stderrBuffer = lines.last ?? ""
            } else {
                processLines = Array(lines)
                self.stderrBuffer = ""
            }

            for line in processLines where !line.isEmpty {
                if let r = line.range(of: "time=") {
                    let after = line[r.upperBound...]
                    let timeStr = after.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? String(after)
                    if let t = FFmpegRunner.timeStringToSeconds(timeStr) {
                        progressHandler(t, timeStr)
                    } else {
                        progressHandler(nil, timeStr)
                    }
                } else {
                    progressHandler(nil, line)
                }
            }
        }
    }

    func cancel() {
        guard let p = process else { return }
        p.interrupt()
    }

    static func timeStringToSeconds(_ s: String) -> Double? {
        let parts = s.split(separator: ":").map(String.init)
        if parts.count == 3 {
            if let h = Double(parts[0]), let m = Double(parts[1]), let sec = Double(parts[2]) {
                return h * 3600 + m * 60 + sec
            }
        } else if parts.count == 2 {
            if let m = Double(parts[0]), let sec = Double(parts[1]) {
                return m * 60 + sec
            }
        } else if parts.count == 1 {
            return Double(parts[0])
        }
        return nil
    }
}
