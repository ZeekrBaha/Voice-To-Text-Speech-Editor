@testable import SpeechEditor

final class FakeTranscriptionEngine: TranscriptionEngine {
    var result = ""
    var errorToThrow: Error?
    private(set) var receivedVocabulary: [String] = []
    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String {
        receivedVocabulary = vocabulary
        if let e = errorToThrow { throw e }
        return result
    }
}
