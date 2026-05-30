# Building

This project uses [XcodeGen](https://github.com/yonyz/XcodeGen) to generate the
Xcode project from `project.yml`. The generated `.xcodeproj` is committed, but you
should regenerate it after pulling changes that touch `project.yml` or add/remove
source files.

## Prerequisites

- macOS 14 or later.
- Xcode (with the macOS SDK).
- XcodeGen:

  ```sh
  brew install xcodegen
  ```

`xcbeautify` is optional — it just prettifies `xcodebuild` output. If you don't
have it, run the `xcodebuild` commands below bare.

## Generate the project

```sh
xcodegen generate
```

## Build and run

Open `SpeechEditor.xcodeproj` in Xcode and run the `SpeechEditor` scheme, or build
from the command line:

```sh
xcodebuild build -scheme SpeechEditor -destination 'platform=macOS,arch=arm64'
```

## Run the tests

Unit tests (Swift Testing — 35 tests):

```sh
xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechEditorTests
```

UI tests (XCUITest):

```sh
xcodebuild test -scheme SpeechEditor -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechEditorUITests
```

The UI test (`EditorSmokeUITests`) launches the app with `-uiTestSeedEditor` and
asserts the seeded Editor appears. It self-skips in non-interactive/headless
environments where the XCUITest runner cannot enable automation mode; run it from
a normal interactive macOS session (and flip `automationAvailable` to `true` in
the test) to exercise it for real.

## Permissions on first run

The app is a menu-bar agent and needs these permissions, which you can grant via
the **Request Permissions** menu item or in **System Settings**:

- **Microphone** — to capture audio.
- **Speech Recognition** — for on-device transcription (Apple's Speech framework).
- **Accessibility** — required for the global ⌃ Right-Control hotkey and for
  paste-at-cursor.

## AI cleanup (optional)

The AI cleanup pass and the Editor's AI actions need a provider:

- **Ollama (default):** install and run Ollama, then pull the default model:

  ```sh
  ollama serve
  ollama pull qwen2.5:7b-instruct
  ```

  The app talks to Ollama at `http://localhost:11434`.

- **OpenAI (alternative):** switch the AI provider to OpenAI and set the
  `OPENAI_API_KEY` environment variable before launching.

If no provider is available, dictation still works — you just get the raw
transcript without the AI cleanup step.
