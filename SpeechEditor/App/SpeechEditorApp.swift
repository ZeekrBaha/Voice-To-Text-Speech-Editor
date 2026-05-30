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
