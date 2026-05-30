import Testing
import Foundation
@testable import SpeechEditor

/// End-to-end exercise of the product-critical path with fakes for the boundaries that
/// need real audio/network/permissions: capture → transcribe → enhance → store → export.
@Suite("Editor pipeline integration")
struct EditorPipelineIntegrationTests {
    @MainActor
    @Test("dictate (fakes) → enhance → store → export file contains the result")
    func dictateThenExport() async throws {
        let capture = FakeAudioCapture()                       // default buffer is long enough
        let engine = FakeTranscriptionEngine(); engine.result = "raw words"
        let enhancer = FakeTextEnhancer(); enhancer.cleanResult = "Polished words."
        let sink = FakeOutputSink()
        let store = EditorStore(store: FakeTranscriptStore())
        let status = StatusCenter()
        let controller = DictationController(
            capture: capture, engine: engine,
            enhancerProvider: { enhancer }, sink: sink,
            settingsProvider: { .default }, store: store, status: status)

        controller.startRecording()
        await controller.stopRecordingAndProcess()

        // Pipeline produced + stored + delivered the enhanced text.
        #expect(store.transcripts.last?.rawText == "raw words")
        #expect(store.transcripts.last?.enhancedText == "Polished words.")
        #expect(sink.delivered == ["Polished words."])

        // Export to a real temp file and verify the content on disk.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("integration-\(UUID().uuidString).md")
        try store.exportText(.markdown, to: url)
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("Polished words."))
        try? FileManager.default.removeItem(at: url)
    }
}
