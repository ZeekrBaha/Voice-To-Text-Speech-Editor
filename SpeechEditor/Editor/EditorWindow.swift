import SwiftUI

struct EditorWindow: View {
    @Bindable var store: EditorStore
    let enhancer: TextEnhancer
    let vocabulary: [String]
    let status: StatusCenter
    /// Display name of the active AI provider, shown in the footer strip.
    let providerName: String
    @State private var busyAction: EditorAction?
    @State private var search = ""

    private var wordCount: Int {
        store.currentText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        HSplitView {
            historySidebar
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
            editorPane
                .frame(minWidth: 460)
        }
        .frame(minWidth: 720, minHeight: 420)
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            EditorToolbar(
                busyAction: busyAction,
                canUndo: store.canUndo,
                canRedo: store.canRedo,
                onAction: { action in Task { await run(action) } },
                onUndo: { store.undo() },
                onRedo: { store.redo() },
                onCopy: copyAll,
                onExport: export)
            Divider()
            if let message = status.current {
                StatusBanner(message: message) { status.clear() }
                Divider()
            }
            TextEditor(text: $store.currentText)
                .font(.body)
                .padding(8)
                .accessibilityIdentifier("editorTextView")
            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack {
            Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
            Spacer()
            Text("AI: \(providerName)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .accessibilityIdentifier("editorFooter")
    }

    private var historySidebar: some View {
        VStack(spacing: 0) {
            TextField("Search history", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .accessibilityIdentifier("historySearch")
            Divider()
            List(store.search(search)) { transcript in
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transcript.displayText).lineLimit(2).font(.callout)
                        Text(transcript.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { store.delete(transcript) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Delete transcript")
                }
                .contentShape(Rectangle())
                .onTapGesture { store.restore(transcript) }
            }
            .listStyle(.sidebar)
        }
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

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.currentText, forType: .string)
        status.post("Copied to clipboard.", severity: .success)
    }

    private func export(_ format: ExportFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcript.\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportText(format, to: url)
            status.post("Exported to \(url.lastPathComponent).", severity: .success)
        } catch {
            status.post("Export failed: \(error.localizedDescription)", severity: .error)
        }
    }
}
