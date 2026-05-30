import SwiftUI

@main
struct SpeechEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Speech Editor", systemImage: "mic.fill") {
            Button("Open Editor") { delegate.container.showEditor() }
            Button("Request Permissions") { delegate.container.requestAllPermissions() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settingsStore: delegate.container.settingsStore,
                         launchAtLogin: delegate.container.launchAtLogin)
        }
    }
}
