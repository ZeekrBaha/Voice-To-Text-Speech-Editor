import Testing
@testable import SpeechEditor

@Suite("DictationController")
struct DictationControllerTests {
    @MainActor
    private func makeController(
        capture: FakeAudioCapture = .init(),
        engine: FakeTranscriptionEngine = .init(),
        enhancer: FakeTextEnhancer = .init(),
        sink: FakeOutputSink = .init(),
        settings: AppSettings = .default,
        store: EditorStore = .init()
    ) -> DictationController {
        DictationController(capture: capture, engine: engine, enhancer: enhancer,
                            sink: sink, vocabulary: ["Xcode"], settings: settings, store: store)
    }

    @MainActor
    @Test("happy path: transcribes, enhances, delivers, stores")
    func happyPath() async throws {
        let engine = FakeTranscriptionEngine(); engine.result = "helo wrld"
        let enhancer = FakeTextEnhancer(); enhancer.cleanResult = "Hello, world."
        let sink = FakeOutputSink(); let store = EditorStore()
        let c = makeController(engine: engine, enhancer: enhancer, sink: sink, store: store)
        c.startRecording()
        await c.stopRecordingAndProcess()
        #expect(sink.delivered == ["Hello, world."])
        #expect(store.transcripts.last?.rawText == "helo wrld")
        #expect(store.transcripts.last?.enhancedText == "Hello, world.")
        #expect(engine.receivedVocabulary == ["Xcode"])
    }

    @MainActor
    @Test("audio too short: no transcription, no delivery")
    func tooShort() async throws {
        let capture = FakeAudioCapture()
        capture.bufferToReturn = AudioBuffer(samples: [0.1], sampleRate: 16000)
        let sink = FakeOutputSink()
        let c = makeController(capture: capture, sink: sink)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(sink.delivered.isEmpty)
    }

    @MainActor
    @Test("enhancement disabled: delivers raw text")
    func enhancementOff() async throws {
        var settings = AppSettings.default; settings.enhancementEnabled = false
        let engine = FakeTranscriptionEngine(); engine.result = "raw text"
        let sink = FakeOutputSink()
        let c = makeController(engine: engine, sink: sink, settings: settings)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(sink.delivered == ["raw text"])
    }

    @MainActor
    @Test("enhancement failure still delivers raw transcript")
    func enhancementFails() async throws {
        let engine = FakeTranscriptionEngine(); engine.result = "raw text"
        let enhancer = FakeTextEnhancer(); enhancer.errorToThrow = AppError.enhancementFailed("x")
        let sink = FakeOutputSink()
        let c = makeController(engine: engine, enhancer: enhancer, sink: sink)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(sink.delivered == ["raw text"])
    }
}
