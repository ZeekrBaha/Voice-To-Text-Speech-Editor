# Voice to Text Speech Editor — v0.2 Design (Review-Response)

**Date:** 2026-05-30
**Status:** Approved, executing
**Supersedes parts of:** `2026-05-30-voice-to-text-speech-editor-design.md` (the original MVP spec)

## Purpose

An external code review identified seven substantive gaps in the shipped MVP. This
spec defines the v0.2 work that closes them. The guiding principle is the same as
v1: a clean, protocol-seamed pipeline where each unit has one purpose and is testable
in isolation. v0.2 adds three cross-cutting units (status, persistence, expanded
settings) and deepens the editor — without rewriting the working pipeline.

## Locked decisions

1. **Transcription:** Apple Speech is the honest v1 engine. whisper.cpp does not
   integrate on the current toolchain; it remains a *future* backend reachable through
   the unchanged `TranscriptionEngine` protocol. All dead whisper UX is removed and the
   docs are corrected.
2. **Persistence:** Codable transcripts persisted as JSON in `Application Support`
   (atomic write). No database.
3. **Error surfacing:** A shared `@Observable StatusCenter` drives an in-app banner
   (Editor) and a status line (HUD). No system notifications.
4. **Delivery:** All seven areas, executed as sequential phases. Build +
   `SpeechEditorTests` must be green before each phase is committed.

## Architecture additions

```
                         ┌──────────────────┐
   pipeline / editor ───▶│   StatusCenter   │◀─── settings / permissions
   (post failures)       │ (@Observable)    │     (post failures)
                         └──────────────────┘
                                  │ banner / HUD line

   EditorStore ──▶ TranscriptStore (protocol) ──▶ JSONTranscriptStore
   (undo+redo,                                     (Application Support, atomic)
    search, autosave)                              FakeTranscriptStore (tests, temp dir)

   AppSettings (expanded) ──▶ SettingsStore ──▶ SettingsView (full surface)
        │
        ├─ locale            → AppleSpeechEngine + translation target
        ├─ hotkey modifier   → HotkeyManager (keyCode read)
        ├─ paste delay/mode  → CursorPasteSink / DictationController
        ├─ provider+models   → enhancer factory
        ├─ launchAtLogin     → SMAppService
        └─ vocabulary        → pipeline (was always [])
```

Every new I/O unit sits behind a protocol with a fake, consistent with v1.

## Phases

### Phase 1 — Honest MVP
- Delete `ModelManager`, `ModelManagerTests`, and the `modelName` field on `AppSettings`
  (+ its references in `SettingsStore.default` and `AppSettingsTests`).
- Rewrite the original spec/plan/README so Apple Speech is stated as the v1 engine and
  whisper is described only as a future seam.
- **No behavior change.** Build + tests green.

### Phase 2 — Persistence + redo
- `TranscriptStore` protocol: `load() -> [Transcript]`, `save([Transcript])`.
- `JSONTranscriptStore`: atomic JSON write to
  `~/Library/Application Support/SpeechEditor/transcripts.json`.
- `FakeTranscriptStore` (in-memory / injectable URL) for tests.
- `EditorStore`: inject a store; load on init; autosave on mutation; add **redo**;
  add `delete(_:)` and `search(_:)` (case-insensitive substring over raw+enhanced).
- Tests: persistence round-trip, redo, delete, search.

### Phase 3 — Error surfacing
- `StatusCenter` (`@Observable`): `current: StatusMessage?` with `text`, `severity`
  (`.info/.success/.error`), and a `post(...)` that auto-clears after a delay.
- Replace silent `try?` failures: `EditorWindow` (AI action, export) and
  `DictationController` (transcription failed, AI unavailable → info, paste failed,
  permission missing). Inject `StatusCenter` into the controller and editor.
- UI: dismissible banner in `EditorWindow`; one-line status in the HUD.
- Tests: each failure path posts the expected severity/text.

### Phase 4 — Paste reliability
- `CursorPasteSink`: snapshot/restore **all** pasteboard items (not just `.string`)
  via `NSPasteboardItem`; restore delay read from settings (default 120 ms).
- Add `AccessibilityChecking` seam (`isProcessTrusted`); before pasting, if not trusted,
  post a paste-failed/permission status and skip the synthetic Cmd+V (text is already
  stored, never lost).
- Tests: full-pasteboard preserve/restore via fakes; not-trusted path posts status and
  does not paste.

### Phase 5 — Settings overhaul + wiring
- Expand `AppSettings`: `localeIdentifier`, `translationLanguage`, `hotkeyModifier`
  (enum → keyCode), `pasteDelayMs`, `pasteMode` (`pasteOnly/editorOnly/both`),
  `launchAtLogin`, `vocabulary: [VocabularyEntry]`.
- `SettingsView` sections: General (launch-at-login via `SMAppService`, hotkey modifier,
  locale), AI (enhancement toggle, provider, Ollama model, OpenAI model + key-present
  indicator from env), Dictation (paste mode, paste delay), Vocabulary (add/edit/delete
  list).
- Wire: `AppContainer.vocabulary` ← settings; `AppleSpeechEngine` locale ←
  settings; `HotkeyManager` modifier ← settings; translation target ← settings.
- Tests: settings encode/decode incl. new fields with defaults; vocabulary CRUD;
  `SMAppService` wrapper behind a protocol fake.

### Phase 6 — Editor UX
- Toolbar: icon+label buttons that size to content (no truncation), `.help()` tooltips,
  keyboard shortcuts (`.keyboardShortcut`) for every action.
- Add **Redo** and **Copy** buttons; **export format** menu (.md/.txt/.rtf);
  tone & translate-language **dropdowns** feeding `PromptLibrary`.
- **History sidebar**: list of transcripts (timestamp, snippet), search field, delete,
  restore-into-editor — backed by the Phase 2 store.
- **Status/quality strip**: last dictation duration, provider used, confidence when the
  recognizer reports it.
- `PromptLibrary` presets: "Email reply", "Clean up Slack message", "Meeting notes".
- `pasteMode` honored by `DictationController` (paste-only / editor-only / both).
- Tests: PromptLibrary presets; export formats; pasteMode branching in the controller.

### Phase 7 — Integration coverage
- `EditorStore.exportText(_:format:to:)` decoupled from `NSSavePanel` (the panel calls
  it); unit-test export content per format.
- Integration test: seed text → fake enhancer applies an action → export to a temp URL
  → assert file content.
- Extend `EditorSmokeUITests` to drive one seeded editor action where automation is
  available.

## Deferred (explicitly out of scope, roadmap only)
- Building the whisper.cpp backend (toolchain-blocked).
- Streaming partial-result AI edits into the editor.
- Per-paragraph re-record.

These are documented as roadmap items in the README; they are not half-built.

## Testing strategy
Unchanged philosophy: every new unit gets a fake and Swift Testing coverage; the real
audio/permission/paste path stays manual + the new integration test. Build +
`-only-testing:SpeechEditorTests` green is the gate for every phase commit.
