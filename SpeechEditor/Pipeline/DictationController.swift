import Foundation

@MainActor
final class DictationController {
    private let capture: AudioCapturing
    private let engine: TranscriptionEngine
    private let enhancer: TextEnhancer
    private let sink: OutputSink
    private let vocabulary: [String]
    private let settings: AppSettings
    private let store: EditorStore
    private let minSeconds: Double = 0.3

    init(capture: AudioCapturing, engine: TranscriptionEngine, enhancer: TextEnhancer,
         sink: OutputSink, vocabulary: [String], settings: AppSettings, store: EditorStore) {
        self.capture = capture; self.engine = engine; self.enhancer = enhancer
        self.sink = sink; self.vocabulary = vocabulary; self.settings = settings; self.store = store
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
            if settings.enhancementEnabled {
                enhanced = try? await enhancer.clean(raw, vocabulary: vocabulary)
            }
            let final = enhanced ?? raw
            store.add(Transcript(id: UUID(), createdAt: Date(), rawText: raw, enhancedText: enhanced))
            try sink.deliver(final)
        } catch {
            Log.pipeline.error("pipeline failed: \(error)")
        }
    }
}
