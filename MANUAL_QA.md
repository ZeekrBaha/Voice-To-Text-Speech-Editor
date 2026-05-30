# Manual QA checklist

Real audio capture, permissions, paste-at-cursor, and AI cleanup aren't covered by
the unit tests. This is the human-run end-to-end checklist. Run it from a normal
interactive macOS session.

## Permissions

- [ ] Grant **Microphone**, **Speech Recognition**, and **Accessibility**
      permissions (menu → **Request Permissions**, or System Settings).

## Dictation → paste at cursor

- [ ] Open **TextEdit** and click into a document.
- [ ] **Hold ⌃ Right-Control**, say "hello world", then release.
- [ ] The recording HUD is visible **while the key is held** and disappears on
      release.
- [ ] The cleaned text is **pasted at the cursor** in TextEdit.
- [ ] Your **prior clipboard contents are restored** after the paste.

## Editor

- [ ] Menu → **Open Editor**: the dictated transcript appears in the Editor.

## AI actions (Ollama running)

- [ ] With Ollama running, click **Summarize** → the text updates.
- [ ] Click **Rewrite** → the text updates.
- [ ] Click **Undo** → the change is reverted.
- [ ] Click **Export** → a `.md` file is written.

## Hotkey isolation

- [ ] Confirm **⌥ Option does nothing** in this app (no collision with the
      separate `ai-voice-dictation` project).
