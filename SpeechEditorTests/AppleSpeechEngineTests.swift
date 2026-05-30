import Testing
@testable import SpeechEditor

@Suite("AppleSpeechEngine")
struct AppleSpeechEngineTests {
    // Type-level only: constructing the engine must not require Speech authorization.
    // Calling transcribe() needs permission + a live recognizer, so it is validated manually.
    @Test("conforms to TranscriptionEngine")
    func conformsToTranscriptionEngine() {
        let engine: TranscriptionEngine = AppleSpeechEngine()
        _ = engine
    }
}
