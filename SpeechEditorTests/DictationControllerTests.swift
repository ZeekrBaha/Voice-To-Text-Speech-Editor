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
        store: EditorStore? = nil,
        status: StatusCenter? = nil
    ) -> DictationController {
        let store = store ?? EditorStore(store: FakeTranscriptStore())
        let status = status ?? StatusCenter()
        return DictationController(capture: capture, engine: engine,
                            enhancerProvider: { enhancer },
                            sink: sink, vocabulary: ["Xcode"],
                            settingsProvider: { settings }, store: store, status: status)
    }

    @MainActor
    @Test("happy path: transcribes, enhances, delivers, stores")
    func happyPath() async throws {
        let engine = FakeTranscriptionEngine(); engine.result = "helo wrld"
        let enhancer = FakeTextEnhancer(); enhancer.cleanResult = "Hello, world."
        let sink = FakeOutputSink(); let store = EditorStore(store: FakeTranscriptStore())
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
    @Test("enhancement failure still delivers raw transcript and posts an info status")
    func enhancementFails() async throws {
        let engine = FakeTranscriptionEngine(); engine.result = "raw text"
        let enhancer = FakeTextEnhancer(); enhancer.errorToThrow = AppError.enhancementFailed("x")
        let sink = FakeOutputSink(); let status = StatusCenter()
        let c = makeController(engine: engine, enhancer: enhancer, sink: sink, status: status)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(sink.delivered == ["raw text"])
        #expect(status.current?.severity == .info)
    }

    @MainActor
    @Test("transcription failure posts an error status and delivers nothing")
    func transcriptionFails() async throws {
        let engine = FakeTranscriptionEngine(); engine.errorToThrow = AppError.transcriptionFailed("boom")
        let sink = FakeOutputSink(); let status = StatusCenter()
        let c = makeController(engine: engine, sink: sink, status: status)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(sink.delivered.isEmpty)
        #expect(status.current?.severity == .error)
    }

    @MainActor
    @Test("paste failure posts an error status but the transcript is still stored")
    func pasteFails() async throws {
        let engine = FakeTranscriptionEngine(); engine.result = "kept words"
        let sink = FakeOutputSink(); sink.errorToThrow = AppError.pasteFailed
        let status = StatusCenter(); let store = EditorStore(store: FakeTranscriptStore())
        let c = makeController(engine: engine, sink: sink, store: store, status: status)
        c.startRecording(); await c.stopRecordingAndProcess()
        #expect(status.current?.severity == .error)
        #expect(store.transcripts.last?.rawText == "kept words")  // never lost
    }
}
