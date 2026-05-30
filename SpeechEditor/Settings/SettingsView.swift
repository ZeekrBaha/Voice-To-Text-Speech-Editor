import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    let launchAtLogin: LaunchAtLoginManaging
    @State private var newTerm: String = ""

    private var openAIKeyPresent: Bool {
        !(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "").isEmpty
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0); settingsStore.settings.launchAtLogin = $0 }
                ))
                Picker("Dictation hotkey (hold)", selection: $settingsStore.settings.hotkeyModifier) {
                    ForEach(HotkeyModifier.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Language", selection: $settingsStore.settings.localeIdentifier) {
                    ForEach(Self.locales) { Text($0.label).tag($0.id) }
                }
            }

            Section("AI cleanup & editing") {
                Toggle("Enable AI cleanup", isOn: $settingsStore.settings.enhancementEnabled)
                Picker("Provider", selection: $settingsStore.settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                TextField("Ollama model", text: $settingsStore.settings.ollamaModel)
                TextField("OpenAI model", text: $settingsStore.settings.openAIModel)
                LabeledContent("OpenAI API key") {
                    Label(openAIKeyPresent ? "Detected" : "Not set",
                          systemImage: openAIKeyPresent ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(openAIKeyPresent ? .green : .secondary)
                }
                TextField("Translate to", text: $settingsStore.settings.translationLanguage)
            }

            Section("Dictation output") {
                Picker("After dictation", selection: $settingsStore.settings.pasteMode) {
                    ForEach(PasteMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Stepper("Paste restore delay: \(settingsStore.settings.pasteDelayMs) ms",
                        value: $settingsStore.settings.pasteDelayMs, in: 0...500, step: 20)
            }

            Section("Vocabulary") {
                HStack {
                    TextField("Add a term (proper noun, jargon…)", text: $newTerm)
                        .onSubmit(addTerm)
                    Button("Add", action: addTerm)
                        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if settingsStore.settings.vocabulary.isEmpty {
                    Text("No terms yet — added terms are spelled correctly in transcripts.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(settingsStore.settings.vocabulary) { entry in
                        HStack {
                            Text(entry.term)
                            Spacer()
                            Button { remove(entry) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Delete \(entry.term)")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 580)
    }

    private func addTerm() {
        guard let entry = VocabularyEntry(term: newTerm) else { return }
        settingsStore.settings.vocabulary.append(entry)
        newTerm = ""
    }

    private func remove(_ entry: VocabularyEntry) {
        settingsStore.settings.vocabulary.removeAll { $0.id == entry.id }
    }

    private struct LocaleOption: Identifiable { let id: String; let label: String }
    private static let locales: [LocaleOption] = [
        .init(id: "en-US", label: "English (US)"),
        .init(id: "en-GB", label: "English (UK)"),
        .init(id: "es-ES", label: "Spanish"),
        .init(id: "fr-FR", label: "French"),
        .init(id: "de-DE", label: "German"),
        .init(id: "it-IT", label: "Italian"),
        .init(id: "pt-BR", label: "Portuguese (Brazil)"),
        .init(id: "ja-JP", label: "Japanese"),
        .init(id: "zh-CN", label: "Chinese (Simplified)"),
    ]
}
