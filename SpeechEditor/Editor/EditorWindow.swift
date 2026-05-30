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
