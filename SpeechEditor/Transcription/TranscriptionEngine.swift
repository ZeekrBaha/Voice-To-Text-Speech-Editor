import Foundation

protocol TranscriptionEngine {
    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String
}
