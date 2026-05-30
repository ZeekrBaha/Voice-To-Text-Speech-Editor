# Voice to Text Speech Editor Implementation Plan

> ⚠️ **Historical note (corrected in v0.2):** This plan targets whisper.cpp for local
> transcription. **whisper.cpp was never shipped** — it does not integrate on the
> current toolchain. The product uses **Apple's Speech framework** behind the
> `TranscriptionEngine` protocol; whisper remains a roadmap item. The whisper-specific
> tasks below were not completed and are kept only for history.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app where holding ⌃ Right-Control records speech, transcribes it locally with whisper.cpp, runs an AI cleanup pass, pastes the result at the cursor, and also feeds a first-class Editor window with AI actions, history, and export.

**Architecture:** A protocol-seamed pipeline — `AudioCapturing → TranscriptionEngine → TextEnhancer → OutputSink` — orchestrated by a `DictationController`, with an independent `EditorStore`/`EditorWindow` consuming the same transcripts. Every layer is a Swift protocol with one concrete impl plus a fake for tests. SwiftUI + AppKit shell, macOS 14+.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit, XcodeGen (`project.yml`), Swift Testing, SPM packages (`KeyboardShortcuts`, `LaunchAtLogin`, `Sparkle`, `Zip`), whisper.cpp (`whisper.xcframework`), Ollama (local AI) with OpenAI fallback.

**Spec:** `docs/superpowers/specs/2026-05-30-voice-to-text-speech-editor-design.md`

---

## Conventions used in every task

- **Run tests:** `xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' 2>&1 | xcbeautify` (or via XcodeBuildMCP `test_sim`-equivalent macOS test tool). A filtered run uses `-only-testing:SpeechEditorTests/<Suite>/<test>`.
- **Regenerate project after adding files:** `xcodegen generate` (only needed when files/targets change; XcodeGen globs sources so new files in existing folders are picked up automatically on next generate).
- **Commit cadence:** one commit per task (the final step of each task).
- **Test framework:** Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest, except `SpeechEditorUITests` which uses XCUITest.
- **Module name:** the app target is `SpeechEditor`; tests `@testable import SpeechEditor`.

---

## File Structure (decomposition locked here)

```
Voice to Text Speech Editor/
├── project.yml                         # XcodeGen project definition
├── SpeechEditor/
│   ├── App/
│   │   ├── SpeechEditorApp.swift        # @main, SwiftUI App, MenuBarExtra
│   │   ├── AppDelegate.swift            # NSApplicationDelegate, lifecycle, permissions bootstrap
│   │   └── AppContainer.swift           # dependency wiring (composition root)
│   ├── Capture/
│   │   ├── AudioCapturing.swift         # protocol + AudioBuffer type
│   │   └── AVAudioCaptureService.swift  # AVAudioEngine 16kHz mono impl
│   ├── Transcription/
│   │   ├── TranscriptionEngine.swift    # protocol
│   │   ├── WhisperEngine.swift          # whisper.cpp bridge impl
│   │   └── ModelManager.swift           # model list, download, on-disk location
│   ├── Enhancement/
│   │   ├── TextEnhancer.swift           # protocol + EditorAction enum
│   │   ├── OllamaEnhancer.swift         # local Ollama HTTP impl
│   │   ├── OpenAIEnhancer.swift         # cloud fallback impl
│   │   └── PromptLibrary.swift          # prompts for clean + each EditorAction
│   ├── Output/
│   │   ├── OutputSink.swift             # protocol
│   │   └── CursorPasteSink.swift        # clipboard save→paste(Cmd+V)→restore
│   ├── Pipeline/
│   │   ├── DictationController.swift     # orchestrates capture→transcribe→enhance→output
│   │   └── HotkeyManager.swift          # hold ⌃ Right-Control state machine
│   ├── Editor/
│   │   ├── EditorStore.swift            # observable transcript+history state, export
│   │   ├── EditorWindow.swift           # SwiftUI editor surface
│   │   └── EditorToolbar.swift          # AI action buttons
│   ├── Settings/
│   │   ├── SettingsStore.swift          # persisted settings (UserDefaults)
│   │   └── SettingsView.swift           # SwiftUI settings UI
│   ├── HUD/
│   │   ├── MiniRecorderHUD.swift        # floating recording indicator
│   │   └── HUDController.swift          # NSPanel show/hide
│   ├── Onboarding/
│   │   ├── PermissionsService.swift     # mic + accessibility checks/prompts
│   │   └── OnboardingView.swift         # first-run flow
│   ├── Models/
│   │   ├── Transcript.swift
│   │   ├── VocabularyEntry.swift
│   │   └── AppSettings.swift
│   ├── Shared/
│   │   ├── AppError.swift               # typed errors
│   │   └── Logger.swift                 # os.Logger wrapper
│   ├── Resources/
│   │   └── Info.plist                   # usage strings, LSUIElement
│   └── SpeechEditor.entitlements        # mic, no sandbox (Accessibility needs it off)
├── SpeechEditorTests/                  # Swift Testing units + fakes
│   ├── Fakes/
│   │   ├── FakeAudioCapture.swift
│   │   ├── FakeTranscriptionEngine.swift
│   │   ├── FakeTextEnhancer.swift
│   │   └── FakeOutputSink.swift
│   └── ...                              # one test file per unit under test
└── SpeechEditorUITests/
    └── EditorSmokeUITests.swift
```

**Boundary rationale:** each pipeline layer is a protocol so it can be faked; `DictationController` is the only place they compose, so the pipeline is testable end-to-end with fakes and no real audio/models. `EditorStore` is pure state (no UI), so AI actions/history/export are unit-testable without driving SwiftUI.

---

## Phase 0 — Project scaffold

### Task 0.1: XcodeGen project + empty app that launches

**Files:**
- Create: `project.yml`
- Create: `SpeechEditor/App/SpeechEditorApp.swift`
- Create: `SpeechEditor/Resources/Info.plist`
- Create: `SpeechEditor/SpeechEditor.entitlements`

- [ ] **Step 1: Write `project.yml`**

```yaml
name: SpeechEditor
options:
  bundleIdPrefix: com.baha.speecheditor
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: 2.2.0
  LaunchAtLogin:
    url: https://github.com/sindresorhus/LaunchAtLogin-Modern
    from: 1.1.0
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.6.0
  Zip:
    url: https://github.com/marmelroy/Zip
    from: 2.1.2
targets:
  SpeechEditor:
    type: application
    platform: macOS
    sources: [SpeechEditor]
    settings:
      base:
        INFOPLIST_FILE: SpeechEditor/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: SpeechEditor/SpeechEditor.entitlements
        ENABLE_HARDENED_RUNTIME: YES
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
    dependencies:
      - package: KeyboardShortcuts
      - package: LaunchAtLogin
      - package: Sparkle
      - package: Zip
  SpeechEditorTests:
    type: bundle.unit-test
    platform: macOS
    sources: [SpeechEditorTests]
    dependencies:
      - target: SpeechEditor
  SpeechEditorUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [SpeechEditorUITests]
    dependencies:
      - target: SpeechEditor
schemes:
  SpeechEditor:
    build:
      targets:
        SpeechEditor: all
        SpeechEditorTests: [test]
        SpeechEditorUITests: [test]
    test:
      targets: [SpeechEditorTests, SpeechEditorUITests]
```

- [ ] **Step 2: Write minimal `SpeechEditorApp.swift`**

```swift
import SwiftUI

@main
struct SpeechEditorApp: App {
    var body: some Scene {
        MenuBarExtra("Speech Editor", systemImage: "mic.fill") {
            Text("Speech Editor running")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

- [ ] **Step 3: Write `Info.plist`** (menu-bar agent app, mic usage string)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Speech Editor records your voice to transcribe it to text on-device.</string>
    <key>CFBundleName</key>
    <string>SpeechEditor</string>
</dict>
</plist>
```

- [ ] **Step 4: Write `SpeechEditor.entitlements`** (no sandbox — Accessibility/CGEvent paste requires it)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Generate and build**

Run: `xcodegen generate && xcodebuild build -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' 2>&1 | xcbeautify`
Expected: BUILD SUCCEEDED. Launching shows a mic icon in the menu bar.

- [ ] **Step 6: Commit**

```bash
git add project.yml SpeechEditor/
git commit -m "chore: scaffold SpeechEditor macOS app with XcodeGen"
```

### Task 0.2: Test target smoke test

**Files:**
- Create: `SpeechEditorTests/SmokeTests.swift`

- [ ] **Step 1: Write a trivial passing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("Smoke")
struct SmokeTests {
    @Test("test harness runs")
    func harnessRuns() {
        #expect(1 + 1 == 2)
    }
}
```

- [ ] **Step 2: Generate, run the test**

Run: `xcodegen generate && xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' -only-testing:SpeechEditorTests/Smoke 2>&1 | xcbeautify`
Expected: TEST SUCCEEDED, 1 test passed.

- [ ] **Step 3: Commit**

```bash
git add SpeechEditorTests/
git commit -m "test: add Swift Testing smoke test"
```

---

## Phase 1 — Models & Shared

### Task 1.1: `Transcript` model

**Files:**
- Create: `SpeechEditor/Models/Transcript.swift`
- Test: `SpeechEditorTests/TranscriptTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("Transcript")
struct TranscriptTests {
    @Test("preserves raw and enhanced text")
    func preservesText() {
        let t = Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0),
                           rawText: "helo wrld", enhancedText: "Hello, world.")
        #expect(t.rawText == "helo wrld")
        #expect(t.enhancedText == "Hello, world.")
        #expect(t.displayText == "Hello, world.")
    }

    @Test("displayText falls back to raw when no enhancement")
    func fallback() {
        let t = Transcript(id: UUID(), createdAt: Date(), rawText: "raw only", enhancedText: nil)
        #expect(t.displayText == "raw only")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' -only-testing:SpeechEditorTests/Transcript 2>&1 | xcbeautify`
Expected: FAIL — "cannot find 'Transcript' in scope".

- [ ] **Step 3: Implement**

```swift
import Foundation

struct Transcript: Identifiable, Equatable, Codable {
    let id: UUID
    let createdAt: Date
    var rawText: String
    var enhancedText: String?

    var displayText: String { enhancedText ?? rawText }
}
```

- [ ] **Step 4: Run to verify pass** — Expected: 2 tests pass.
- [ ] **Step 5: Commit**

```bash
git add SpeechEditor/Models/Transcript.swift SpeechEditorTests/TranscriptTests.swift
git commit -m "feat: add Transcript model"
```

### Task 1.2: `VocabularyEntry` + normalization

**Files:**
- Create: `SpeechEditor/Models/VocabularyEntry.swift`
- Test: `SpeechEditorTests/VocabularyEntryTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("VocabularyEntry")
struct VocabularyEntryTests {
    @Test("trims and ignores empty terms")
    func trims() {
        #expect(VocabularyEntry(term: "  Xcode  ")?.term == "Xcode")
        #expect(VocabularyEntry(term: "   ") == nil)
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation

struct VocabularyEntry: Equatable, Codable, Identifiable {
    let id: UUID
    let term: String

    init?(term: String, id: UUID = UUID()) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.id = id
        self.term = trimmed
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add VocabularyEntry model`

### Task 1.3: `AppError` + `Logger`

**Files:**
- Create: `SpeechEditor/Shared/AppError.swift`
- Create: `SpeechEditor/Shared/Logger.swift`
- Test: `SpeechEditorTests/AppErrorTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("AppError")
struct AppErrorTests {
    @Test("has user-facing messages")
    func messages() {
        #expect(AppError.audioTooShort.userMessage.contains("short"))
        #expect(AppError.modelMissing.userMessage.contains("model"))
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation

enum AppError: Error, Equatable {
    case audioTooShort
    case modelMissing
    case transcriptionFailed(String)
    case enhancementFailed(String)
    case pasteFailed
    case permissionDenied(String)

    var userMessage: String {
        switch self {
        case .audioTooShort: return "That recording was too short to transcribe."
        case .modelMissing: return "No transcription model is installed yet."
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        case .enhancementFailed(let m): return "AI cleanup failed: \(m)"
        case .pasteFailed: return "Couldn't paste the text at your cursor."
        case .permissionDenied(let what): return "\(what) permission is required."
        }
    }
}
```

```swift
// Logger.swift
import os

enum Log {
    static let pipeline = Logger(subsystem: "com.baha.speecheditor", category: "pipeline")
    static let audio = Logger(subsystem: "com.baha.speecheditor", category: "audio")
    static let ai = Logger(subsystem: "com.baha.speecheditor", category: "ai")
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add AppError and Logger`

### Task 1.4: `AppSettings` model

**Files:**
- Create: `SpeechEditor/Models/AppSettings.swift`
- Test: `SpeechEditorTests/AppSettingsTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("has sane defaults")
    func defaults() {
        let s = AppSettings.default
        #expect(s.enhancementEnabled == true)
        #expect(s.aiProvider == .ollama)
        #expect(s.modelName == "ggml-small.en")
    }

    @Test("round-trips through Codable")
    func codable() throws {
        let data = try JSONEncoder().encode(AppSettings.default)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == .default)
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation

enum AIProvider: String, Codable, CaseIterable { case ollama, openai }

struct AppSettings: Codable, Equatable {
    var enhancementEnabled: Bool
    var aiProvider: AIProvider
    var modelName: String          // whisper.cpp model file stem
    var ollamaModel: String
    var openAIModel: String

    static let `default` = AppSettings(
        enhancementEnabled: true,
        aiProvider: .ollama,
        modelName: "ggml-small.en",
        ollamaModel: "qwen2.5:7b-instruct",
        openAIModel: "gpt-4o-mini"
    )
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add AppSettings model`

---

## Phase 2 — Capture layer

### Task 2.1: `AudioCapturing` protocol + `AudioBuffer`

**Files:**
- Create: `SpeechEditor/Capture/AudioCapturing.swift`
- Create: `SpeechEditorTests/Fakes/FakeAudioCapture.swift`
- Test: `SpeechEditorTests/AudioBufferTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("AudioBuffer")
struct AudioBufferTests {
    @Test("durationSeconds derives from sample count and rate")
    func duration() {
        let buf = AudioBuffer(samples: Array(repeating: 0, count: 16000), sampleRate: 16000)
        #expect(buf.durationSeconds == 1.0)
    }

    @Test("isTooShort below threshold")
    func tooShort() {
        let buf = AudioBuffer(samples: Array(repeating: 0, count: 1600), sampleRate: 16000)
        #expect(buf.isTooShort(minSeconds: 0.3) == false) // 0.1s? -> too short
        #expect(AudioBuffer(samples: [], sampleRate: 16000).isTooShort(minSeconds: 0.3))
    }
}
```

> Note: 1600/16000 = 0.1s, which IS shorter than 0.3 → the first `#expect` should be `true`. Fix the test to assert `true` before implementing (this catches the off-by-one in the spec).

```swift
        #expect(buf.isTooShort(minSeconds: 0.3) == true)  // 0.1s < 0.3s
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement protocol + buffer**

```swift
import Foundation

struct AudioBuffer: Equatable {
    let samples: [Float]   // mono PCM, normalized -1...1
    let sampleRate: Int

    var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }
    func isTooShort(minSeconds: Double) -> Bool { durationSeconds < minSeconds }
}

protocol AudioCapturing: AnyObject {
    func start() throws
    func stop() -> AudioBuffer
}
```

- [ ] **Step 4: Write `FakeAudioCapture`**

```swift
@testable import SpeechEditor

final class FakeAudioCapture: AudioCapturing {
    var startCalled = false
    var bufferToReturn = AudioBuffer(samples: Array(repeating: 0.1, count: 16000), sampleRate: 16000)
    func start() throws { startCalled = true }
    func stop() -> AudioBuffer { bufferToReturn }
}
```

- [ ] **Step 5: Run — PASS.**
- [ ] **Step 6: Commit** `feat: add AudioCapturing protocol and AudioBuffer`

### Task 2.2: `AVAudioCaptureService` (real impl, smoke-built only)

**Files:**
- Create: `SpeechEditor/Capture/AVAudioCaptureService.swift`

> Real audio I/O isn't unit-tested (requires hardware + permission). It is exercised manually in Phase 9. Keep it thin so the untested surface is minimal.

- [ ] **Step 1: Implement using AVAudioEngine, 16kHz mono, accumulate samples**

```swift
import AVFoundation

final class AVAudioCaptureService: AudioCapturing {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let targetRate: Double = 16000
    private let lock = NSLock()

    func start() throws {
        samples.removeAll(keepingCapacity: true)
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: targetRate, channels: 1, interleaved: false)!
        let converter = AVAudioConverter(from: inputFormat, to: outFormat)!

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let cap = AVAudioFrameCount(outFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate) + 16
            guard let converted = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: cap) else { return }
            var error: NSError?
            var fed = false
            converter.convert(to: converted, error: &error) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return buffer
            }
            if let ch = converted.floatChannelData {
                let frames = Int(converted.frameLength)
                self.lock.lock()
                self.samples.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: frames))
                self.lock.unlock()
            }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> AudioBuffer {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); let s = samples; lock.unlock()
        return AudioBuffer(samples: s, sampleRate: Int(targetRate))
    }
}
```

- [ ] **Step 2: Build only**

Run: `xcodebuild build -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' 2>&1 | xcbeautify`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit** `feat: add AVAudioEngine 16kHz capture service`

---

## Phase 3 — Transcription layer

### Task 3.1: `TranscriptionEngine` protocol + `FakeTranscriptionEngine`

**Files:**
- Create: `SpeechEditor/Transcription/TranscriptionEngine.swift`
- Create: `SpeechEditorTests/Fakes/FakeTranscriptionEngine.swift`
- Test: `SpeechEditorTests/TranscriptionEngineContractTests.swift`

- [ ] **Step 1: Failing test (contract via fake)**

```swift
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
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement protocol + fake**

```swift
// TranscriptionEngine.swift
protocol TranscriptionEngine {
    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String
}
```

```swift
// FakeTranscriptionEngine.swift
@testable import SpeechEditor

final class FakeTranscriptionEngine: TranscriptionEngine {
    var result = ""
    var errorToThrow: Error?
    private(set) var receivedVocabulary: [String] = []
    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String {
        receivedVocabulary = vocabulary
        if let e = errorToThrow { throw e }
        return result
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add TranscriptionEngine protocol`

### Task 3.2: `ModelManager` — model catalog + on-disk location

**Files:**
- Create: `SpeechEditor/Transcription/ModelManager.swift`
- Test: `SpeechEditorTests/ModelManagerTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("ModelManager")
struct ModelManagerTests {
    @Test("catalog includes default model with a download URL")
    func catalog() {
        let m = ModelManager.catalog.first { $0.stem == "ggml-small.en" }
        #expect(m != nil)
        #expect(m?.downloadURL.absoluteString.contains("ggml-small.en.bin") == true)
    }

    @Test("isInstalled false when file absent")
    func notInstalled() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mm = ModelManager(modelsDirectory: dir)
        #expect(mm.isInstalled(stem: "ggml-small.en") == false)
        #expect(mm.fileURL(for: "ggml-small.en").lastPathComponent == "ggml-small.en.bin")
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation

struct WhisperModel: Equatable {
    let stem: String          // e.g. "ggml-small.en"
    let displayName: String
    let downloadURL: URL
    let approxSizeMB: Int
}

final class ModelManager {
    static let catalog: [WhisperModel] = [
        WhisperModel(stem: "ggml-base.en", displayName: "Base (English, fast)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!, approxSizeMB: 142),
        WhisperModel(stem: "ggml-small.en", displayName: "Small (English, balanced)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!, approxSizeMB: 466),
        WhisperModel(stem: "ggml-large-v3-turbo", displayName: "Large v3 Turbo (best)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!, approxSizeMB: 1600),
    ]

    private let modelsDirectory: URL
    private let fm = FileManager.default

    init(modelsDirectory: URL? = nil) {
        self.modelsDirectory = modelsDirectory ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechEditor/Models", isDirectory: true)
    }

    func fileURL(for stem: String) -> URL {
        modelsDirectory.appendingPathComponent("\(stem).bin")
    }
    func isInstalled(stem: String) -> Bool { fm.fileExists(atPath: fileURL(for: stem).path) }

    /// Downloads the model, reporting fractional progress. Throws AppError.modelMissing on failure.
    func download(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
        try fm.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let (tempURL, response) = try await URLSession.shared.download(from: model.downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppError.modelMissing }
        let dest = fileURL(for: model.stem)
        try? fm.removeItem(at: dest)
        try fm.moveItem(at: tempURL, to: dest)
        progress(1.0)
    }
}
```

> Note: the simple `download(from:)` gives no incremental progress; the `progress` callback is invoked once at completion for MVP. A delegate-based progressing download is a Phase 9 polish item, not MVP.

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add ModelManager with whisper.cpp model catalog`

### Task 3.3: Add `whisper.xcframework` dependency

**Files:**
- Modify: `project.yml` (add binary framework / SPM package for whisper.cpp)

- [ ] **Step 1: Add whisper.cpp via SPM**

Add to `project.yml` `packages:`:

```yaml
  whisper:
    url: https://github.com/ggerganov/whisper.cpp
    from: 1.7.1
```

Add to the `SpeechEditor` target `dependencies:`:

```yaml
      - package: whisper
        product: whisper
```

- [ ] **Step 2: Generate + build**

Run: `xcodegen generate && xcodebuild build -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' 2>&1 | xcbeautify`
Expected: BUILD SUCCEEDED (whisper module resolves).

> If SPM resolution of whisper.cpp fails on this toolchain, fall back to building `whisper.xcframework` per whisper.cpp's `build-xcframework.sh` and adding it as a local binary framework. Document whichever path succeeds in `BUILDING.md`.

- [ ] **Step 3: Commit** `chore: add whisper.cpp dependency`

### Task 3.4: `WhisperEngine` real impl (build-verified)

**Files:**
- Create: `SpeechEditor/Transcription/WhisperEngine.swift`

> The C bridge can't be meaningfully unit-tested without a model file; correctness is verified manually in Phase 9. The `vocabulary` is passed as whisper's `initial_prompt` to bias proper nouns.

- [ ] **Step 1: Implement**

```swift
import Foundation
import whisper

final class WhisperEngine: TranscriptionEngine {
    private let modelURL: URL
    private var ctx: OpaquePointer?

    init(modelURL: URL) { self.modelURL = modelURL }

    private func ensureContext() throws {
        if ctx != nil { return }
        var params = whisper_context_default_params()
        params.use_gpu = true
        ctx = modelURL.path.withCString { whisper_init_from_file_with_params(modelURL.path, params) }
        if ctx == nil { throw AppError.modelMissing }
    }

    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String {
        try ensureContext()
        guard let ctx else { throw AppError.transcriptionFailed("no context") }
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.language = ("en" as NSString).utf8String
        let prompt = vocabulary.isEmpty ? "" : "Vocabulary: " + vocabulary.joined(separator: ", ")
        return try prompt.withCString { promptPtr in
            if !vocabulary.isEmpty { params.initial_prompt = promptPtr }
            let ok = audio.samples.withUnsafeBufferPointer {
                whisper_full(ctx, params, $0.baseAddress, Int32($0.count))
            }
            guard ok == 0 else { throw AppError.transcriptionFailed("whisper_full \(ok)") }
            var text = ""
            for i in 0..<whisper_full_n_segments(ctx) {
                text += String(cString: whisper_full_get_segment_text(ctx, i))
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    deinit { if let ctx { whisper_free(ctx) } }
}
```

- [ ] **Step 2: Build only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3: Commit** `feat: add WhisperEngine whisper.cpp transcription`

---

## Phase 4 — Enhancement layer

### Task 4.1: `TextEnhancer` protocol + `EditorAction` + `FakeTextEnhancer`

**Files:**
- Create: `SpeechEditor/Enhancement/TextEnhancer.swift`
- Create: `SpeechEditorTests/Fakes/FakeTextEnhancer.swift`
- Test: `SpeechEditorTests/TextEnhancerContractTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("TextEnhancer contract")
struct TextEnhancerContractTests {
    @Test("clean returns enhanced text")
    func clean() async throws {
        let e = FakeTextEnhancer(); e.cleanResult = "Hello, world."
        #expect(try await e.clean("helo wrld", vocabulary: []) == "Hello, world.")
    }
    @Test("apply maps each action")
    func apply() async throws {
        let e = FakeTextEnhancer(); e.applyResult = "summary"
        let out = try await e.apply(.summarize, to: "long text")
        #expect(out == "summary")
        #expect(e.lastAction == .summarize)
    }
    @Test("EditorAction covers the MVP set")
    func actions() {
        #expect(Set(EditorAction.allCases) ==
                [.rewrite, .summarize, .changeTone, .translate, .fixGrammar])
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
// TextEnhancer.swift
enum EditorAction: CaseIterable, Equatable {
    case rewrite, summarize, changeTone, translate, fixGrammar
    var title: String {
        switch self {
        case .rewrite: return "Rewrite"
        case .summarize: return "Summarize"
        case .changeTone: return "Change Tone"
        case .translate: return "Translate"
        case .fixGrammar: return "Fix Grammar"
        }
    }
}

protocol TextEnhancer {
    func clean(_ text: String, vocabulary: [String]) async throws -> String
    func apply(_ action: EditorAction, to text: String) async throws -> String
}
```

```swift
// FakeTextEnhancer.swift
@testable import SpeechEditor

final class FakeTextEnhancer: TextEnhancer {
    var cleanResult = ""
    var applyResult = ""
    var errorToThrow: Error?
    private(set) var lastAction: EditorAction?
    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        if let e = errorToThrow { throw e }; return cleanResult.isEmpty ? text : cleanResult
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        lastAction = action
        if let e = errorToThrow { throw e }; return applyResult
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add TextEnhancer protocol and EditorAction`

### Task 4.2: `PromptLibrary`

**Files:**
- Create: `SpeechEditor/Enhancement/PromptLibrary.swift`
- Test: `SpeechEditorTests/PromptLibraryTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("PromptLibrary")
struct PromptLibraryTests {
    @Test("clean prompt injects vocabulary and text")
    func cleanPrompt() {
        let p = PromptLibrary.clean(text: "helo", vocabulary: ["Xcode"])
        #expect(p.contains("helo"))
        #expect(p.contains("Xcode"))
    }
    @Test("each action yields a distinct instruction")
    func actionPrompts() {
        let prompts = EditorAction.allCases.map { PromptLibrary.action($0, text: "x") }
        #expect(Set(prompts).count == EditorAction.allCases.count)
        #expect(prompts.allSatisfy { $0.contains("x") })
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
enum PromptLibrary {
    static func clean(text: String, vocabulary: [String]) -> String {
        let vocab = vocabulary.isEmpty ? "" :
            "\nKnown proper nouns to spell correctly: \(vocabulary.joined(separator: ", "))."
        return """
        You clean up dictated speech. Fix filler words, punctuation, and capitalization. \
        Do NOT add new content or change meaning. Return only the cleaned text.\(vocab)

        Text: \(text)
        """
    }

    static func action(_ action: EditorAction, text: String) -> String {
        let instruction: String
        switch action {
        case .rewrite:     instruction = "Rewrite the text to be clearer and more concise, preserving meaning."
        case .summarize:   instruction = "Summarize the text in a few sentences."
        case .changeTone:  instruction = "Rewrite the text in a professional, friendly tone."
        case .translate:   instruction = "Translate the text to Spanish."
        case .fixGrammar:  instruction = "Fix grammar and spelling only; keep wording otherwise identical."
        }
        return "\(instruction) Return only the result.\n\nText: \(text)"
    }
}
```

> Note: `translate`/`changeTone` targets are hardcoded for MVP. Making target language/tone user-configurable is a Phase 9 enhancement.

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add PromptLibrary`

### Task 4.3: `OllamaEnhancer` with injected HTTP client (TDD via fake transport)

**Files:**
- Create: `SpeechEditor/Enhancement/OllamaEnhancer.swift`
- Test: `SpeechEditorTests/OllamaEnhancerTests.swift`

- [ ] **Step 1: Failing test** — inject a transport closure so no real network is needed

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("OllamaEnhancer")
struct OllamaEnhancerTests {
    @Test("parses Ollama response and sends the model")
    func cleans() async throws {
        var sentBody: Data?
        let enhancer = OllamaEnhancer(model: "qwen2.5:7b-instruct") { request in
            sentBody = request.httpBody
            let json = #"{"response":"Hello, world."}"#.data(using: .utf8)!
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let out = try await enhancer.clean("helo wrld", vocabulary: [])
        #expect(out == "Hello, world.")
        let bodyString = String(data: sentBody!, encoding: .utf8)!
        #expect(bodyString.contains("qwen2.5:7b-instruct"))
    }

    @Test("throws enhancementFailed on non-200")
    func httpError() async {
        let enhancer = OllamaEnhancer(model: "m") { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: AppError.self) {
            _ = try await enhancer.clean("x", vocabulary: [])
        }
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation

final class OllamaEnhancer: TextEnhancer {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let model: String
    private let baseURL: URL
    private let transport: Transport

    init(model: String,
         baseURL: URL = URL(string: "http://localhost:11434")!,
         transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.model = model; self.baseURL = baseURL; self.transport = transport
    }

    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        try await generate(PromptLibrary.clean(text: text, vocabulary: vocabulary))
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        try await generate(PromptLibrary.action(action, text: text))
    }

    private func generate(_ prompt: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "prompt": prompt, "stream": false
        ])
        let (data, response) = try await transport(req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.enhancementFailed("Ollama HTTP error")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = obj?["response"] as? String else {
            throw AppError.enhancementFailed("bad Ollama response")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run — PASS (2 tests).**
- [ ] **Step 5: Commit** `feat: add OllamaEnhancer with injectable transport`

### Task 4.4: `OpenAIEnhancer` fallback (same transport pattern)

**Files:**
- Create: `SpeechEditor/Enhancement/OpenAIEnhancer.swift`
- Test: `SpeechEditorTests/OpenAIEnhancerTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("OpenAIEnhancer")
struct OpenAIEnhancerTests {
    @Test("parses chat completion and sets auth header")
    func cleans() async throws {
        var authHeader: String?
        let e = OpenAIEnhancer(apiKey: "sk-test", model: "gpt-4o-mini") { req in
            authHeader = req.value(forHTTPHeaderField: "Authorization")
            let json = #"{"choices":[{"message":{"content":"Hello."}}]}"#.data(using: .utf8)!
            return (json, HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        #expect(try await e.clean("helo", vocabulary: []) == "Hello.")
        #expect(authHeader == "Bearer sk-test")
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** (mirror OllamaEnhancer; chat/completions endpoint, parse `choices[0].message.content`)

```swift
import Foundation

final class OpenAIEnhancer: TextEnhancer {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let apiKey: String
    private let model: String
    private let transport: Transport

    init(apiKey: String, model: String,
         transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.apiKey = apiKey; self.model = model; self.transport = transport
    }

    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        try await chat(PromptLibrary.clean(text: text, vocabulary: vocabulary))
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        try await chat(PromptLibrary.action(action, text: text))
    }

    private func chat(_ prompt: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [["role": "user", "content": prompt]]
        ])
        let (data, response) = try await transport(req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.enhancementFailed("OpenAI HTTP error")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = obj?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else {
            throw AppError.enhancementFailed("bad OpenAI response")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add OpenAIEnhancer fallback`

---

## Phase 5 — Output layer

### Task 5.1: `OutputSink` protocol + `FakeOutputSink`

**Files:**
- Create: `SpeechEditor/Output/OutputSink.swift`
- Create: `SpeechEditorTests/Fakes/FakeOutputSink.swift`
- Test: `SpeechEditorTests/OutputSinkContractTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("OutputSink contract")
struct OutputSinkContractTests {
    @Test("records delivered text")
    func delivers() throws {
        let sink = FakeOutputSink()
        try sink.deliver("hello")
        #expect(sink.delivered == ["hello"])
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
// OutputSink.swift
protocol OutputSink { func deliver(_ text: String) throws }
```

```swift
// FakeOutputSink.swift
@testable import SpeechEditor
final class FakeOutputSink: OutputSink {
    private(set) var delivered: [String] = []
    var errorToThrow: Error?
    func deliver(_ text: String) throws {
        if let e = errorToThrow { throw e }
        delivered.append(text)
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add OutputSink protocol`

### Task 5.2: `CursorPasteSink` — clipboard save/paste/restore (TDD the clipboard logic)

**Files:**
- Create: `SpeechEditor/Output/CursorPasteSink.swift`
- Test: `SpeechEditorTests/CursorPasteSinkTests.swift`

> The Cmd+V keystroke uses CGEvent (untestable in unit context), but the clipboard save→set→restore logic IS testable by injecting a pasteboard abstraction and a no-op keystroke closure.

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

final class SpyPasteboard: PasteboardWriting {
    var contents: String?
    func string() -> String? { contents }
    func setString(_ s: String) { contents = s }
}

@Suite("CursorPasteSink")
struct CursorPasteSinkTests {
    @Test("sets text, triggers paste, then restores prior clipboard")
    func restores() throws {
        let pb = SpyPasteboard(); pb.contents = "original"
        var pastedWhileSet: String?
        let sink = CursorPasteSink(pasteboard: pb, paste: { pastedWhileSet = pb.string() })
        try sink.deliver("new text")
        #expect(pastedWhileSet == "new text")   // text was on clipboard at paste time
        #expect(pb.contents == "original")      // restored afterward
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import AppKit

protocol PasteboardWriting {
    func string() -> String?
    func setString(_ s: String)
}

struct SystemPasteboard: PasteboardWriting {
    func string() -> String? { NSPasteboard.general.string(forType: .string) }
    func setString(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

final class CursorPasteSink: OutputSink {
    private let pasteboard: PasteboardWriting
    private let paste: () -> Void

    init(pasteboard: PasteboardWriting = SystemPasteboard(),
         paste: @escaping () -> Void = CursorPasteSink.pressCmdV) {
        self.pasteboard = pasteboard
        self.paste = paste
    }

    func deliver(_ text: String) throws {
        let saved = pasteboard.string()
        pasteboard.setString(text)
        paste()
        // restore after a short delay so the paste consumes the new value first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let saved { self.pasteboard.setString(saved) }
        }
    }

    static func pressCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
```

> Note: the test injects a synchronous `paste` and checks restore via the test's own ordering; in production the async restore runs after paste. The test asserts the value present at paste time and that the final stored value is the original.

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add CursorPasteSink with clipboard save/restore`

---

## Phase 6 — Hotkey + pipeline orchestration

### Task 6.1: `HotkeyManager` — hold ⌃ Right-Control state machine

**Files:**
- Create: `SpeechEditor/Pipeline/HotkeyManager.swift`
- Test: `SpeechEditorTests/HotkeyManagerTests.swift`

> The global event monitor (CGEvent tap) is untestable in units, but the **press/release state machine** is. Extract a pure `HotkeyStateMachine` and test it; the manager wires the real tap to it.

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("HotkeyStateMachine")
struct HotkeyStateMachineTests {
    @Test("hold then release fires start then stop exactly once")
    func holdRelease() {
        var events: [String] = []
        let sm = HotkeyStateMachine(onStart: { events.append("start") },
                                    onStop: { events.append("stop") })
        sm.keyChanged(isControlDown: true)
        sm.keyChanged(isControlDown: true)  // repeat key-down must not re-fire start
        sm.keyChanged(isControlDown: false)
        #expect(events == ["start", "stop"])
    }

    @Test("release without prior press does nothing")
    func releaseOnly() {
        var events: [String] = []
        let sm = HotkeyStateMachine(onStart: { events.append("start") },
                                    onStop: { events.append("stop") })
        sm.keyChanged(isControlDown: false)
        #expect(events.isEmpty)
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement state machine + manager**

```swift
import AppKit

final class HotkeyStateMachine {
    private var isRecording = false
    private let onStart: () -> Void
    private let onStop: () -> Void
    init(onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        self.onStart = onStart; self.onStop = onStop
    }
    func keyChanged(isControlDown: Bool) {
        if isControlDown, !isRecording { isRecording = true; onStart() }
        else if !isControlDown, isRecording { isRecording = false; onStop() }
    }
}

/// Wires a global modifier-flags monitor for the Right-Control key to the state machine.
final class HotkeyManager {
    private let machine: HotkeyStateMachine
    private var monitor: Any?
    // Right Control hardware keycode
    private let rightControlKeyCode: UInt16 = 0x3E

    init(onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        machine = HotkeyStateMachine(onStart: onStart, onStop: onStop)
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            // Right Control specifically (device-independent flag .control + keyCode)
            let isRightControl = event.keyCode == self.rightControlKeyCode
            guard isRightControl else { return }
            let down = event.modifierFlags.contains(.control)
            self.machine.keyChanged(isControlDown: down)
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
```

- [ ] **Step 4: Run — PASS (2 tests).**
- [ ] **Step 5: Commit** `feat: add HotkeyManager with Right-Control state machine`

### Task 6.2: `DictationController` — orchestrate the pipeline

**Files:**
- Create: `SpeechEditor/Pipeline/DictationController.swift`
- Test: `SpeechEditorTests/DictationControllerTests.swift`

- [ ] **Step 1: Failing test (full pipeline with fakes)**

```swift
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
        capture.bufferToReturn = AudioBuffer(samples: [0.1], sampleRate: 16000) // ~0s
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
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** (depends on `EditorStore` from Task 7.1 — implement that first if executing strictly in order; the plan orders Phase 7's store before this in execution. See note.)

```swift
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
            try sink.deliver(final)
            store.add(Transcript(id: UUID(), createdAt: Date(), rawText: raw, enhancedText: enhanced))
        } catch {
            Log.pipeline.error("pipeline failed: \(error)")
        }
    }
}
```

> **Execution ordering note:** `DictationController` depends on `EditorStore`. When executing, implement **Task 7.1 (EditorStore) before Task 6.2**. The plan documents them in pipeline order for readability; the executor should follow the dependency. (Subagent-driven execution will surface this as a missing symbol and the reviewer reorders.)

- [ ] **Step 4: Run — PASS (4 tests).**
- [ ] **Step 5: Commit** `feat: add DictationController orchestrating the pipeline`

---

## Phase 7 — Editor (the enhancement)

### Task 7.1: `EditorStore` — transcripts, history, export

**Files:**
- Create: `SpeechEditor/Editor/EditorStore.swift`
- Test: `SpeechEditorTests/EditorStoreTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("EditorStore")
struct EditorStoreTests {
    @MainActor
    @Test("add appends and sets current text")
    func add() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        #expect(s.transcripts.count == 1)
        #expect(s.currentText == "A.")
    }

    @MainActor
    @Test("applying an edit pushes history and updates current")
    func history() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        s.replaceCurrent(with: "A summary.")
        #expect(s.currentText == "A summary.")
        s.undo()
        #expect(s.currentText == "A.")
    }

    @MainActor
    @Test("export produces text with all transcripts")
    func export() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), rawText: "one", enhancedText: nil))
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 60), rawText: "two", enhancedText: nil))
        let md = s.exportMarkdown()
        #expect(md.contains("one"))
        #expect(md.contains("two"))
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class EditorStore {
    private(set) var transcripts: [Transcript] = []
    var currentText: String = ""
    private var history: [String] = []

    func add(_ t: Transcript) {
        transcripts.append(t)
        pushHistory()
        currentText = t.displayText
    }

    func replaceCurrent(with text: String) {
        pushHistory()
        currentText = text
    }

    func undo() {
        guard let last = history.popLast() else { return }
        currentText = last
    }

    private func pushHistory() { history.append(currentText) }

    func exportMarkdown() -> String {
        let fmt = ISO8601DateFormatter()
        return transcripts.map { "### \(fmt.string(from: $0.createdAt))\n\n\($0.displayText)" }
            .joined(separator: "\n\n")
    }
}
```

- [ ] **Step 4: Run — PASS (3 tests).**
- [ ] **Step 5: Commit** `feat: add EditorStore with history and markdown export`

### Task 7.2: `EditorWindow` + `EditorToolbar` (SwiftUI; build-verified + light UITest)

**Files:**
- Create: `SpeechEditor/Editor/EditorWindow.swift`
- Create: `SpeechEditor/Editor/EditorToolbar.swift`

- [ ] **Step 1: Implement editor view bound to `EditorStore`**

```swift
import SwiftUI

struct EditorWindow: View {
    @Bindable var store: EditorStore
    let enhancer: TextEnhancer
    let vocabulary: [String]
    @State private var busyAction: EditorAction?

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(busyAction: busyAction) { action in
                Task { await run(action) }
            } onUndo: { store.undo() } onExport: { export() }
            Divider()
            TextEditor(text: $store.currentText)
                .font(.body)
                .padding(8)
                .accessibilityIdentifier("editorTextView")
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    private func run(_ action: EditorAction) async {
        busyAction = action
        defer { busyAction = nil }
        if let result = try? await enhancer.apply(action, to: store.currentText) {
            store.replaceCurrent(with: result)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcript.md"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportMarkdown().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
```

```swift
// EditorToolbar.swift
import SwiftUI

struct EditorToolbar: View {
    let busyAction: EditorAction?
    let onAction: (EditorAction) -> Void
    let onUndo: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EditorAction.allCases, id: \.self) { action in
                Button(action.title) { onAction(action) }
                    .disabled(busyAction != nil)
                    .accessibilityIdentifier("action_\(action.title)")
            }
            Spacer()
            Button("Undo", action: onUndo).accessibilityIdentifier("undoButton")
            Button("Export", action: onExport).accessibilityIdentifier("exportButton")
            if busyAction != nil { ProgressView().controlSize(.small) }
        }
        .padding(8)
    }
}
```

- [ ] **Step 2: Build only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3: Commit** `feat: add Editor window and toolbar`

### Task 7.3: Editor smoke UITest

**Files:**
- Create: `SpeechEditorUITests/EditorSmokeUITests.swift`

> Requires the app to expose a way to open the editor and seed text. Add a launch argument `-uiTestSeedEditor` that, when present, opens the editor window with a fixed transcript (wired in Phase 8 AppContainer).

- [ ] **Step 1: Write UITest**

```swift
import XCTest

final class EditorSmokeUITests: XCTestCase {
    func testEditorOpensAndShowsSeededText() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeedEditor"]
        app.launch()
        let editor = app.textViews["editorTextView"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportButton"].exists)
    }
}
```

- [ ] **Step 2: Run after Phase 8 wiring** (this test is expected RED until Task 8.3 seeds the editor; mark it `XCTSkip` if running before then).

Run: `xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' -only-testing:SpeechEditorUITests 2>&1 | xcbeautify`

- [ ] **Step 3: Commit** `test: add editor smoke UITest`

---

## Phase 8 — App shell: menu bar, HUD, settings, onboarding, wiring

### Task 8.1: `SettingsStore` (UserDefaults persistence)

**Files:**
- Create: `SpeechEditor/Settings/SettingsStore.swift`
- Test: `SpeechEditorTests/SettingsStoreTests.swift`

- [ ] **Step 1: Failing test (inject a UserDefaults suite)**

```swift
import Testing
import Foundation
@testable import SpeechEditor

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test("persists and reloads settings")
    func persists() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        var s = store.settings
        s.enhancementEnabled = false
        store.settings = s
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings.enhancementEnabled == false)
    }

    @Test("returns defaults when nothing stored")
    func defaultsWhenEmpty() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "empty-\(UUID().uuidString)")!)
        #expect(store.settings == .default)
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

@Observable
final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "appSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            _settings = decoded
        } else {
            _settings = .default
        }
    }

    var settings: AppSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
        }
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add SettingsStore`

### Task 8.2: `PermissionsService` (mic + accessibility checks)

**Files:**
- Create: `SpeechEditor/Onboarding/PermissionsService.swift`
- Test: `SpeechEditorTests/PermissionsServiceTests.swift`

> The OS calls are wrapped behind injectable closures so the decision logic is tested without prompting.

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import SpeechEditor

@Suite("PermissionsService")
struct PermissionsServiceTests {
    @Test("not ready when either permission missing")
    func notReady() {
        #expect(PermissionsService(micGranted: { false }, axTrusted: { true }).isReady == false)
        #expect(PermissionsService(micGranted: { true },  axTrusted: { false }).isReady == false)
        #expect(PermissionsService(micGranted: { true },  axTrusted: { true }).isReady == true)
    }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```swift
import AVFoundation
import ApplicationServices

final class PermissionsService {
    private let micGranted: () -> Bool
    private let axTrusted: () -> Bool

    init(micGranted: @escaping () -> Bool = {
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
         },
         axTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.micGranted = micGranted; self.axTrusted = axTrusted
    }

    var isReady: Bool { micGranted() && axTrusted() }

    func requestMic() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }
    func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** `feat: add PermissionsService`

### Task 8.3: `AppContainer` composition root + wire everything

**Files:**
- Create: `SpeechEditor/App/AppContainer.swift`
- Create: `SpeechEditor/HUD/HUDController.swift`
- Create: `SpeechEditor/HUD/MiniRecorderHUD.swift`
- Create: `SpeechEditor/Onboarding/OnboardingView.swift`
- Create: `SpeechEditor/Settings/SettingsView.swift`
- Modify: `SpeechEditor/App/SpeechEditorApp.swift`
- Modify: `SpeechEditor/App/AppDelegate.swift` (create)

- [ ] **Step 1: Implement `AppContainer`** — builds concrete impls from settings, owns controller/store/hotkeys, handles the `-uiTestSeedEditor` flag

```swift
import SwiftUI

@MainActor
final class AppContainer {
    let settingsStore = SettingsStore()
    let editorStore = EditorStore()
    let permissions = PermissionsService()
    let modelManager = ModelManager()
    private(set) var dictation: DictationController!
    private(set) var hotkeys: HotkeyManager!
    let hud = HUDController()

    private var vocabulary: [String] { [] } // wired to a VocabularyStore in a later iteration

    init() {
        buildPipeline()
        if CommandLine.arguments.contains("-uiTestSeedEditor") {
            editorStore.add(Transcript(id: UUID(), createdAt: Date(),
                                       rawText: "seeded", enhancedText: "Seeded transcript."))
        }
    }

    private func makeEnhancer() -> TextEnhancer {
        let s = settingsStore.settings
        switch s.aiProvider {
        case .ollama: return OllamaEnhancer(model: s.ollamaModel)
        case .openai:
            let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
            return OpenAIEnhancer(apiKey: key, model: s.openAIModel)
        }
    }

    private func buildPipeline() {
        let s = settingsStore.settings
        let engine = WhisperEngine(modelURL: modelManager.fileURL(for: s.modelName))
        dictation = DictationController(
            capture: AVAudioCaptureService(), engine: engine, enhancer: makeEnhancer(),
            sink: CursorPasteSink(), vocabulary: vocabulary, settings: s, store: editorStore)
        hotkeys = HotkeyManager(
            onStart: { [weak self] in self?.hud.show(); self?.dictation.startRecording() },
            onStop:  { [weak self] in self?.hud.hide(); Task { await self?.dictation.stopRecordingAndProcess() } })
        hotkeys.start()
    }

    func enhancerForEditor() -> TextEnhancer { makeEnhancer() }
}
```

- [ ] **Step 2: Implement `HUDController` + `MiniRecorderHUD`** (floating NSPanel with a pulsing mic)

```swift
// HUDController.swift
import AppKit
import SwiftUI

@MainActor
final class HUDController {
    private var panel: NSPanel?
    func show() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 120, height: 48),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: MiniRecorderHUD())
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - 60, y: f.minY + 80))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }
    func hide() { panel?.orderOut(nil); panel = nil }
}
```

```swift
// MiniRecorderHUD.swift
import SwiftUI

struct MiniRecorderHUD: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 10, height: 10).opacity(pulse ? 0.3 : 1)
            Text("Recording…").font(.caption).bold()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true } }
    }
}
```

- [ ] **Step 3: Implement `SettingsView` + `OnboardingView`** (bind to stores; model download button; provider picker; enhancement toggle)

```swift
// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    let modelManager: ModelManager
    @State private var downloading = false

    var body: some View {
        Form {
            Toggle("Enable AI cleanup", isOn: $settingsStore.settings.enhancementEnabled)
            Picker("AI provider", selection: $settingsStore.settings.aiProvider) {
                ForEach(AIProvider.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Transcription model", selection: $settingsStore.settings.modelName) {
                ForEach(ModelManager.catalog, id: \.stem) { Text($0.displayName).tag($0.stem) }
            }
            Button(downloading ? "Downloading…" : "Download selected model") {
                downloadSelected()
            }.disabled(downloading)
        }
        .padding(20).frame(width: 420)
    }

    private func downloadSelected() {
        guard let model = ModelManager.catalog.first(where: { $0.stem == settingsStore.settings.modelName }) else { return }
        downloading = true
        Task {
            try? await modelManager.download(model) { _ in }
            downloading = false
        }
    }
}
```

```swift
// OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    let permissions: PermissionsService
    var onDone: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Speech Editor").font(.title2).bold()
            Text("Hold the Right-Control key to dictate anywhere.")
            Button("Grant Microphone Access") { Task { _ = await permissions.requestMic() } }
            Button("Grant Accessibility Access") { permissions.promptAccessibility() }
            Button("Done", action: onDone).keyboardShortcut(.defaultAction)
        }.padding(30).frame(width: 420)
    }
}
```

- [ ] **Step 4: Wire `SpeechEditorApp` + `AppDelegate` to the container**

```swift
// SpeechEditorApp.swift
import SwiftUI

@main
struct SpeechEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra("Speech Editor", systemImage: "mic.fill") {
            Button("Open Editor") { openEditor() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            SettingsView(settingsStore: container.settingsStore, modelManager: container.modelManager)
        }
        Window("Speech Editor", id: "editor") {
            EditorWindow(store: container.editorStore,
                         enhancer: container.enhancerForEditor(),
                         vocabulary: [])
        }
    }

    private func openEditor() {
        NSApp.activate(ignoringOtherApps: true)
        if let url = URL(string: "speecheditor://editor") { _ = url } // placeholder; use openWindow in real impl
    }
}
```

```swift
// AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar agent
    }
}
```

> Note: `openEditor()` uses a placeholder; replace with SwiftUI's `@Environment(\.openWindow)` `openWindow(id: "editor")` wired from a small wrapper view. The UITest in Task 7.3 drives the seeded window via launch arg, which opens automatically when seeded.

- [ ] **Step 5: Generate, build, run the seeded UITest**

Run: `xcodegen generate && xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' -only-testing:SpeechEditorUITests 2>&1 | xcbeautify`
Expected: editor smoke UITest passes.

- [ ] **Step 6: Commit** `feat: wire app shell — container, HUD, settings, onboarding`

---

## Phase 9 — Integration, manual verification, polish

### Task 9.1: Full unit suite green + manual end-to-end check

- [ ] **Step 1: Run the entire unit suite**

Run: `xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' -only-testing:SpeechEditorTests 2>&1 | xcbeautify`
Expected: all suites pass.

- [ ] **Step 2: Manual E2E checklist** (document results in `docs/MANUAL_QA.md`)
  - Download the `ggml-small.en` model from Settings → completes.
  - Grant mic + Accessibility.
  - Open TextEdit, hold ⌃ Right-Control, say "hello world", release → cleaned text pastes at cursor, prior clipboard restored.
  - Open Editor → the transcript appears; run Summarize / Rewrite (Ollama running) → text updates; Undo reverts; Export writes a `.md`.
  - Confirm ⌥ Option does nothing (no collision with ai-voice-dictation).

- [ ] **Step 3: Commit** `docs: add manual QA checklist with results`

### Task 9.2: `BUILDING.md` + `README.md` + license

**Files:**
- Create: `BUILDING.md`, `README.md`, `LICENSE`

- [ ] **Step 1: Write `BUILDING.md`** (xcodegen install, whisper dependency path that worked, model download, Ollama setup, required permissions).
- [ ] **Step 2: Write `README.md`** (what it is, the ⌃ Right-Control hotkey, enhancement over VoiceInk, screenshots placeholder).
- [ ] **Step 3: Add `LICENSE`** — GPLv3 text (per spec §9).
- [ ] **Step 4: Commit** `docs: add README, BUILDING, and GPLv3 license`

### Task 9.3 (optional polish, post-MVP-friendly): progress-reporting model download + configurable translate/tone

- [ ] **Step 1:** Replace `ModelManager.download` with a `URLSessionDownloadDelegate` that reports fractional progress to the Settings UI.
- [ ] **Step 2:** Add `targetLanguage` / `tone` to `AppSettings`; thread into `PromptLibrary.action`. Update `PromptLibraryTests` accordingly.
- [ ] **Step 3:** Commit each independently.

---

## Self-Review (run against the spec)

**1. Spec coverage:**
- §3 menu-bar + HUD → Task 8.3. Push-to-talk pipeline → Phases 2–6. Local whisper.cpp → Phase 3. Vocabulary biasing → passed as `initial_prompt` (3.4) and into prompts (4.2); a dedicated VocabularyStore UI is noted as a later iteration in `AppContainer` (acceptable: model + plumbing exist, the management UI is a thin add).
- §4 enhancements: clean architecture → protocol layers Phases 2–7; Editor-as-product → Phase 7; pluggable transcription → 3.1; pluggable AI → 4.1/4.3/4.4; distinct hotkey → 6.1.
- §5 every layer/folder has a task. §6 data flow → DictationController test (6.2) asserts the exact path. §7 error handling: audioTooShort, enhancement-failure-still-delivers-raw, missing model, permissions → 6.2 tests, AppError, PermissionsService. §8 testing → Swift Testing throughout + XCUITest (7.3). §9 stack → project.yml (0.1) + 3.3. §10 scope — all "in" items have tasks; "deferred" items are explicitly absent. §11 assumptions → Ollama default with graceful degrade (enhancement failure → raw text, 6.2), model selection (8.3), dev-signed/no-sandbox entitlements (0.1).

**2. Placeholder scan:** The two `// placeholder` notes (openEditor window routing, vocabulary store) are flagged with the concrete real-impl instruction inline, not left as bare TODOs. No "TBD/implement later" steps remain.

**3. Type consistency:** `transcribe(_:vocabulary:)`, `clean(_:vocabulary:)`, `apply(_:to:)`, `deliver(_:)`, `EditorStore.add/replaceCurrent/undo/exportMarkdown`, `AudioBuffer.isTooShort(minSeconds:)`, `HotkeyStateMachine.keyChanged(isControlDown:)` are used identically across all tasks that reference them. `AppSettings` fields (`enhancementEnabled`, `aiProvider`, `modelName`, `ollamaModel`, `openAIModel`) match between 1.4, 8.1, and 8.3.

**One known execution-order dependency:** Task 6.2 (`DictationController`) needs `EditorStore` (Task 7.1). Implement 7.1 before 6.2. Flagged inline in 6.2.
