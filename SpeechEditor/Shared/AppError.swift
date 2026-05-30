import Foundation

enum AppError: Error, Equatable {
    case audioTooShort
    case modelMissing
    case transcriptionFailed(String)
    case enhancementFailed(String)
    case pasteFailed
    case permissionDenied(String)

    var userMessage: String {
        switch self {
        case .audioTooShort: return "That recording was too short to transcribe."
        case .modelMissing: return "No transcription model is installed yet."
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        case .enhancementFailed(let m): return "AI cleanup failed: \(m)"
        case .pasteFailed: return "Couldn't paste the text at your cursor."
        case .permissionDenied(let what): return "\(what) permission is required."
        }
    }
}
