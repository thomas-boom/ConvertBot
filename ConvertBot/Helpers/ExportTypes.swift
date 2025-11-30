import Foundation
import AVFoundation

enum ExportType: String, CaseIterable, Identifiable {
    case mov, mp4, m4v, avi, mkv
    var id: String { rawValue }

    var description: String {
        switch self {
        case .mov: return "MOV"
        case .mp4: return "MP4"
        case .m4v: return "M4V"
        case .avi: return "AVI"
        case .mkv: return "MKV"
        }
    }

    var utType: AVFileType {
        switch self {
        case .mov: return .mov
        case .mp4: return .mp4
        case .m4v: return .m4v
        case .avi: return .mov // Placeholder; AVI handled via FFmpeg
        case .mkv: return .mov // Placeholder; MKV handled via FFmpeg
        }
    }
}

enum AudioExportType: String, CaseIterable, Identifiable {
    case m4a, wav, mp3, aac, aiff
    var id: String { rawValue }

    var description: String { rawValue.uppercased() }

    var utType: AVFileType {
        switch self {
        case .m4a: return .m4a
        case .wav: return .wav
        case .mp3: return .mp3
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
        case .mp3:
            // AVFoundation doesn't always provide a native MP3 encoder; try passthrough
            // and let the caller fall back (or FFmpeg handle MP3) if unavailable.
            return [AVAssetExportPresetPassthrough]
        case .wav, .aiff:
            return [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality]
        }
    }
}
