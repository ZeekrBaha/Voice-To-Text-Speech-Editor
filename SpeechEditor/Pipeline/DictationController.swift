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
    private let status: StatusCenter
    private let minSeconds: Double = 0.3

    init(capture: AudioCapturing, engine: TranscriptionEngine,
         enhancerProvider: @escaping () -> TextEnhancer,
         sink: OutputSink, vocabulary: [String],
         settingsProvider: @escaping () -> AppSettings, store: EditorStore,
         status: StatusCenter) {
        self.capture = capture; self.engine = engine; self.enhancerProvider = enhancerProvider
        self.sink = sink; self.vocabulary = vocabulary
        self.settingsProvider = settingsProvider; self.store = store; self.status = status
    }

    func startRecording() {
        do { try capture.start() } catch { Log.pipeline.error("capture start failed: \(error)") }
    }

    func stopRecordingAndProcess() async {
        let buffer = capture.stop()
        guard !buffer.isTooShort(minSeconds: minSeconds) else {
            Log.pipeline.info("audio too short, ignoring"); return
        }

        let raw: String
        do {
            raw = try await engine.transcribe(buffer, vocabulary: vocabulary)
        } catch {
            Log.pipeline.error("transcription failed: \(error)")
            status.post((error as? AppError) ?? .transcriptionFailed(error.localizedDescription))
            return
        }
        guard !raw.isEmpty else { return }

        var enhanced: String? = nil
        if settingsProvider().enhancementEnabled {
            do {
                enhanced = try await enhancerProvider().clean(raw, vocabulary: vocabulary)
            } catch {
                // Best-effort: keep the raw transcript, but tell the user why it wasn't cleaned.
                Log.pipeline.info("AI cleanup unavailable: \(error)")
                status.post("AI cleanup unavailable — using the raw transcript.", severity: .info)
            }
        }

        let final = enhanced ?? raw
        // Store before delivering so words are never lost if the paste fails (spec §7).
        store.add(Transcript(id: UUID(), createdAt: Date(), rawText: raw, enhancedText: enhanced))
        do {
            try sink.deliver(final)
        } catch {
            Log.pipeline.error("paste failed: \(error)")
            status.post((error as? AppError) ?? .pasteFailed)
        }
    }
}
