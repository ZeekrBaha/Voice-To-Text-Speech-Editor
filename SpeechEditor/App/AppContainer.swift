import AppKit
import Foundation

@MainActor
final class AppContainer {
    let settingsStore = SettingsStore()
    let editorStore = EditorStore()
    let permissions = PermissionsService()
    let windowManager = WindowManager()
    let status = StatusCenter()
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
            enhancerProvider: { [unowned self] in self.makeEnhancer() },
            sink: CursorPasteSink(),
            vocabulary: vocabulary,
            settingsProvider: { [unowned self] in self.settingsStore.settings },
            store: editorStore,
            status: status)
        hotkeys = HotkeyManager(
            onStart: { [weak self] in self?.hud.show(); self?.dictation.startRecording() },
            onStop:  { [weak self] in
                guard let self else { return }
                self.hud.hide()
                Task {
                    await self.dictation.stopRecordingAndProcess()
                    // If the pipeline posted an error, flash it on the HUD so it's
                    // visible even when the Editor window is closed.
                    if let msg = self.status.current, msg.severity == .error {
                        self.hud.flash(msg.text)
                    }
                }
            })
    }

    func start() { hotkeys.start() }

    func showEditor() {
        windowManager.showEditor(store: editorStore, enhancer: makeEnhancer(),
                                 vocabulary: vocabulary, status: status)
    }

    func showOnboarding() {
        windowManager.showOnboarding(permissions: permissions)
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
