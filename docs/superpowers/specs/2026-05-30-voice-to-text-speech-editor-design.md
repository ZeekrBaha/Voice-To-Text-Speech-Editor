# Voice to Text Speech Editor — Design Spec

**Date:** 2026-05-30
**Status:** Approved (design v2)
**Author:** Baha (with Claude Code)

---

## 1. Summary

A native macOS menu-bar app for local, privacy-first push-to-talk dictation —
inspired structurally by [VoiceInk](https://github.com/sadiuysal/VoiceInk) but
with a cleaner layered architecture and the **Editor as a first-class product**
rather than a paste step.

Hold **⌃ Right-Control**, speak, release → audio is transcribed locally by
whisper.cpp, cleaned by an AI pass, and pasted at the cursor. Transcripts also
flow into a dedicated **Editor window** with AI actions (rewrite, summarize,
change tone, translate, fix grammar), per-paragraph re-record, edit history, and
export.

This project is **independent** from the existing `ai-voice-dictation` (Python)
project and uses a **different hotkey** (⌃ Right-Control vs. ⌥ Option) so the two
never collide.

## 2. Goals / Non-Goals

### Goals
- Local-first, offline-by-default dictation with high accuracy (whisper.cpp).
- A real editing surface, not just paste-at-cursor.
- Clean, protocol-seamed architecture where engines and AI providers are swappable.
- Testable units (TDD with Swift Testing).

### Non-Goals (MVP)
- Power-Mode context awareness (app/URL-based auto settings).
- Voice-assistant chat mode.
- Cloud or Parakeet transcription engines (protocol seams ready; impls deferred).
- iOS / cross-platform. macOS 14+ only.

## 3. What we keep from VoiceInk (structural bones)
- Menu-bar app + mini recorder HUD.
- Push-to-talk global hotkey → record → local transcribe → AI cleanup → paste at cursor.
- Local-first transcription (whisper.cpp), offline by default.
- Personal vocabulary biasing.

## 4. Where we enhance
1. **Clean layered architecture** (vs. VoiceInk's flat top-level files). Feature-modular,
   protocol-based seams so each layer is swappable and independently testable.
2. **The Editor is the product.** Dictate into it, then run AI actions; per-paragraph
   re-record; edit history; export (md / txt / rtf).
3. **Pluggable transcription** behind one protocol (whisper.cpp now; cloud/Parakeet later).
4. **Pluggable AI enhancer** (local Ollama default, OpenAI fallback; streaming into editor).
5. **Distinct hotkey** (hold ⌃ Right-Control).

## 5. Architecture

```
HotkeyManager ──hold──▶ CaptureService ──audio──▶ TranscriptionEngine (protocol)
                                                          │ text
                                                          ▼
                                                 EnhancementService (protocol)
                                                    │              │
                                          paste at cursor    EditorStore ──▶ EditorWindow
                                          (OutputSink)                         (AI actions, history, export)
```

### Layers (each = protocol + concrete impl + tests)

| Layer            | Responsibility                                              | Key protocol(s)        |
|------------------|-------------------------------------------------------------|------------------------|
| `App/`           | `@main`, lifecycle, menu-bar + window wiring                | —                      |
| `Capture/`       | AVFoundation 16 kHz audio capture; start/stop               | `AudioCapturing`       |
| `Transcription/` | whisper.cpp bridge, model download/load, transcribe         | `TranscriptionEngine`  |
| `Enhancement/`   | AI cleanup + editor actions (rewrite/summarize/tone/etc.)   | `TextEnhancer`         |
| `Output/`        | Clipboard save/paste/restore, cursor paste                  | `OutputSink`           |
| `Editor/`        | Editor window, AI action UI, history, export                | `EditorStore`          |
| `Settings/`      | Hotkey, model, AI provider, vocabulary config               | —                      |
| `Models/`        | `Transcript`, `Settings`, `VocabularyEntry`                 | —                      |
| `Shared/`        | Logging, errors, utilities                                  | —                      |

### Core protocols (sketch)

```swift
protocol AudioCapturing {
    func start() throws
    func stop() -> AudioBuffer            // 16 kHz PCM
}

protocol TranscriptionEngine {
    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String
}

protocol TextEnhancer {
    func clean(_ text: String, vocabulary: [String]) async throws -> String
    func apply(_ action: EditorAction, to text: String) async throws -> String  // streaming variant in Editor
}

protocol OutputSink {
    func deliver(_ text: String) throws   // paste-at-cursor impl saves/restores clipboard
}
```

## 6. Data flow (happy path)
1. User holds ⌃ Right-Control. `HotkeyManager` detects key-down → `CaptureService.start()`.
2. User releases. `CaptureService.stop()` returns a 16 kHz buffer.
3. `TranscriptionEngine.transcribe(buffer, vocabulary)` → raw text (whisper.cpp).
4. `TextEnhancer.clean(text, vocabulary)` → cleaned text (Ollama default).
5. Cleaned text is `deliver()`-ed to the cursor (OutputSink) **and** appended to `EditorStore`.
6. Editor window (if open) shows the new transcript; user can run AI actions, re-record a
   paragraph, view history, or export.

## 7. Error handling
- Validate at boundaries: empty/short audio → no-op with HUD hint, not a crash.
- Transcription/AI failures surface a non-blocking HUD/notification; raw transcript is
  still delivered/stored so the user never loses words (AI cleanup is best-effort).
- Missing model on first run → guided download flow; transcription disabled until ready.
- Microphone / Accessibility permission missing → onboarding prompt with deep link to
  System Settings.
- Clipboard paste restores the user's prior clipboard contents even on failure.

## 8. Testing strategy
- **Swift Testing** units: `TextEnhancer` (cleanup + actions, mocked provider),
  `EditorStore` (append/history/export), vocabulary biasing, hotkey state machine,
  clipboard save/restore logic.
- Fakes for `AudioCapturing`, `TranscriptionEngine`, `TextEnhancer`, `OutputSink` so the
  pipeline is testable without real audio or models.
- **XCUITest** smoke: open Editor window, type, run one AI action (mocked), export.
- TDD: tests first per the project workflow.

## 9. Tech stack
- Swift, SwiftUI + AppKit, macOS 14+.
- SPM packages: `KeyboardShortcuts`, `LaunchAtLogin`, `Sparkle`, `Zip`.
- Transcription: whisper.cpp.
- AI enhancer: local Ollama default (e.g. an instruct model), OpenAI fallback.
- License: GPLv3 (consistent with VoiceInk lineage).

## 10. MVP scope checklist
**In:** push-to-talk dictation; whisper.cpp transcription + model download UI; AI cleanup
pass; paste-at-cursor; Editor window with AI actions + history + export; vocabulary biasing;
menu bar + mini recorder HUD; Settings.

**Deferred:** Power-Mode context awareness; voice-assistant chat; cloud/Parakeet engines;
MediaRemoteAdapter media control.

## 11. Open questions / assumptions
- **Assumption:** Ollama is installed locally for the AI enhancer; if absent, app degrades
  gracefully to "raw transcript only" + a setup hint (OpenAI key optional).
- **Assumption:** whisper.cpp model is user-selectable (e.g. base / small / large-v3-turbo);
  default to a small model for fast first-run, with download UI for larger ones.
- **Assumption:** App is distributed as a developer-signed `.app` (not App Store) given
  Accessibility + global hotkey requirements.

## Addendum (2026-05-30): Transcription engine

whisper.cpp could not be integrated as an SPM source dependency on the Xcode 26.5
toolchain — its package surfaced unsafe build flags / `systemLibrary` setup, and the
tags we tried lacked a usable `Package.swift`, so SPM refused it. To keep the MVP
unblocked, transcription ships on Apple's on-device Speech framework
(`AppleSpeechEngine`) behind the unchanged `TranscriptionEngine` protocol. Because
that seam is narrow, whisper remains addable later via a vendored `.xcframework`
without disturbing the rest of the pipeline; `ModelManager` is retained for that path.
