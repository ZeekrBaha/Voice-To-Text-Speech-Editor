import Testing
@testable import SpeechEditor

@Suite("TranscriptionEngine contract")
struct TranscriptionEngineContractTests {
    @Test("returns text and receives vocabulary")
    func transcribes() async throws {
        let engine = FakeTranscriptionEngine()
        engine.result = "hello world"
        let out = try await engine.transcribe(
            AudioBuffer(samples: [0.1], sampleRate: 16000), vocabulary: ["Xcode"])
        #expect(out == "hello world")
        #expect(engine.receivedVocabulary == ["Xcode"])
    }
}
