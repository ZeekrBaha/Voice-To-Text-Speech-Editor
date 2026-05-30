# Voice to Text Speech Editor

A native macOS menu-bar dictation app with a first-class **Editor** — not just a
paste step. Inspired structurally by [VoiceInk](https://github.com/sadiuysal/VoiceInk),
but built on a clean, protocol-seamed architecture where the transcription engine
and AI provider are swappable behind narrow protocols.

It runs as a menu-bar agent (`LSUIElement` / `.accessory`). Hold a global hotkey,
speak, release — your words are transcribed on-device, optionally cleaned up by an
AI pass, pasted at the cursor, and collected in a dedicated Editor window for
further editing.

## The hotkey

**Hold ⌃ Right-Control to dictate.** Recording runs only while the key is held;
releasing it ends the capture. This is intentionally distinct from the separate
`ai-voice-dictation` project's **⌥ Option** hotkey, so the two never collide.

## How it works

1. **Capture** — holding ⌃ Right-Control starts microphone capture.
2. **Transcribe** — audio is transcribed on-device by `AppleSpeechEngine`
   (Apple's Speech framework), behind the `TranscriptionEngine` protocol.
3. **AI cleanup (optional)** — the raw transcript is passed through an AI
   enhancer (local Ollama by default, OpenAI as an alternative) to tidy
   punctuation and phrasing. This is best-effort: if AI is unavailable, the raw
   transcript is still delivered, so you never lose words.
4. **Deliver** — the cleaned text is pasted at the cursor (the prior clipboard
   contents are saved and restored) **and** appended into the Editor.

## The Editor

Open the Editor from the menu. Dictated transcripts land here, and you can run AI
actions on the text:

- **Rewrite** — clearer and more concise, preserving meaning.
- **Summarize** — condense to a few sentences.
- **Change Tone** — rewrite in a professional, friendly tone.
- **Translate** — translate the text (to Spanish).
- **Fix Grammar** — fix grammar and spelling only, keeping wording otherwise.

The Editor keeps an **undo history** so any AI action can be reverted, and
supports **Markdown export** to a `.md` file.

## Requirements

- macOS 14 or later.
- Xcode (to build — there is no prebuilt binary in this repo).
- **Optional:** [Ollama](https://ollama.com) running locally for AI cleanup
  (default model `qwen2.5:7b-instruct`).
- **Optional:** an `OPENAI_API_KEY` environment variable to use OpenAI instead of
  Ollama for the AI pass.

On first run the app needs **Microphone**, **Speech Recognition**, and
**Accessibility** permissions (Accessibility is required for the global hotkey and
paste-at-cursor). Grant them via the "Request Permissions" menu item or in System
Settings.

See [BUILDING.md](BUILDING.md) for build and run steps, and
[MANUAL_QA.md](MANUAL_QA.md) for the manual end-to-end checklist.

## Implementation notes

The original plan was to use **whisper.cpp** for local transcription. On the
current toolchain it could not be integrated as a Swift Package Manager source
dependency (unsafe build flags / `systemLibrary` setup / missing `Package.swift`
across the tags we tried). Rather than block the MVP, transcription ships on
**Apple's on-device Speech framework** behind the unchanged `TranscriptionEngine`
protocol. Because that seam is narrow, whisper.cpp can be added later via a
vendored `.xcframework` without touching the rest of the pipeline — the
`ModelManager` type is already present for that path.

## License

GPLv3. See [LICENSE](LICENSE).
