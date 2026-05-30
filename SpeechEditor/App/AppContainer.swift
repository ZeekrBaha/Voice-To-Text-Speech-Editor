import AppKit
import Foundation

@MainActor
final class AppContainer {
    let settingsStore = SettingsStore()
    let editorStore = EditorStore()
    let permissions = PermissionsService()
    let windowManager = WindowManager()
    private let hud = HUDController()
    private var dictation: DictationController!
    private var hotkeys: HotkeyManager!

    private let vocabulary: [String] = []  // personal vocabulary UI is a later iteration

    init() { buildPipeline() }

    private func makeEnhancer() -> TextEnhancer {
        let s = settingsStore.settings
        switch s.aiProvider {
        case .ollama:
            return OllamaEnhancer(model: s.ollamaModel)
        case .openai:
            let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
            return OpenAIEnhancer(apiKey: key, model: s.openAIModel)
        }
    }

    private func buildPipeline() {
        dictation = DictationController(
            capture: AVAudioCaptureService(),
            engine: AppleSpeechEngine(),
            enhancer: makeEnhancer(),
            sink: CursorPasteSink(),
            vocabulary: vocabulary,
            settings: settingsStore.settings,
            store: editorStore)
        hotkeys = HotkeyManager(
            onStart: { [weak self] in self?.hud.show(); self?.dictation.startRecording() },
            onStop:  { [weak self] in
                guard let self else { return }
                self.hud.hide()
                Task { await self.dictation.stopRecordingAndProcess() }
            })
    }

    func start() { hotkeys.start() }

    func showEditor() {
        windowManager.showEditor(store: editorStore, enhancer: makeEnhancer(), vocabulary: vocabulary)
    }

    func requestAllPermissions() {
        Task {
            _ = await permissions.requestMic()
            _ = await permissions.requestSpeech()
            permissions.promptAccessibility()
        }
    }

    func seedForUITest() {
        editorStore.add(Transcript(id: UUID(), createdAt: Date(),
                                   rawText: "seeded", enhancedText: "Seeded transcript."))
    }
}
