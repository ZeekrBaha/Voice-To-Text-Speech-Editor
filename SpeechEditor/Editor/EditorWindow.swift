import SwiftUI

struct EditorWindow: View {
    @Bindable var store: EditorStore
    let enhancer: TextEnhancer
    let vocabulary: [String]
    let status: StatusCenter
    @State private var busyAction: EditorAction?

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(busyAction: busyAction) { action in
                Task { await run(action) }
            } onUndo: { store.undo() } onExport: { export() }
            Divider()
            if let message = status.current {
                StatusBanner(message: message) { status.clear() }
                Divider()
            }
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
        do {
            let result = try await enhancer.apply(action, to: store.currentText)
            store.replaceCurrent(with: result)
        } catch {
            status.post((error as? AppError) ?? .enhancementFailed(error.localizedDescription))
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcript.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportMarkdown().write(to: url, atomically: true, encoding: .utf8)
            status.post("Exported to \(url.lastPathComponent).", severity: .success)
        } catch {
            status.post("Export failed: \(error.localizedDescription)", severity: .error)
        }
    }
}
