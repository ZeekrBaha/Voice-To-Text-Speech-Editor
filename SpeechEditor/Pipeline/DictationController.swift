import Foundation

@MainActor
final class DictationController {
    private let capture: AudioCapturing
    private let engine: TranscriptionEngine
    /// Resolved per dictation so a provider/model change in Settings takes effect without a relaunch.
    private let enhancerProvider: () -> TextEnhancer
    private let sink: OutputSink
    private let vocabulary: [String]
    /// Read per dictation for the same reason (e.g. toggling enhancement off).
    private let settingsProvider: () -> AppSettings
    private let store: EditorStore
    private let minSeconds: Double = 0.3

    init(capture: AudioCapturing, engine: TranscriptionEngine,
         enhancerProvider: @escaping () -> TextEnhancer,
         sink: OutputSink, vocabulary: [String],
         settingsProvider: @escaping () -> AppSettings, store: EditorStore) {
        self.capture = capture; self.engine = engine; self.enhancerProvider = enhancerProvider
        self.sink = sink; self.vocabulary = vocabulary
        self.settingsProvider = settingsProvider; self.store = store
    }

    func startRecording() {
        do { try capture.start() } catch { Log.pipeline.error("capture start failed: \(error)") }
    }

    func stopRecordingAndProcess() async {
        let buffer = capture.stop()
        guard !buffer.isTooShort(minSeconds: minSeconds) else {
            Log.pipeline.info("audio too short, ignoring"); return
        }
        do {
            let raw = try await engine.transcribe(buffer, vocabulary: vocabulary)
            guard !raw.isEmpty else { return }
            var enhanced: String? = nil
            if settingsProvider().enhancementEnabled {
                enhanced = try? await enhancerProvider().clean(raw, vocabulary: vocabulary)
            }
            let final = enhanced ?? raw
            store.add(Transcript(id: UUID(), createdAt: Date(), rawText: raw, enhancedText: enhanced))
            try sink.deliver(final)
        } catch {
            Log.pipeline.error("pipeline failed: \(error)")
        }
    }
}
