import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        Form {
            Toggle("Enable AI cleanup", isOn: $settingsStore.settings.enhancementEnabled)
            Picker("AI provider", selection: $settingsStore.settings.aiProvider) {
                ForEach(AIProvider.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
