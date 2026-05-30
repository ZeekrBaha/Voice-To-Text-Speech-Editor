import SwiftUI

struct EditorToolbar: View {
    let busyAction: EditorAction?
    let canUndo: Bool
    let canRedo: Bool
    let onAction: (EditorAction) -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onCopy: () -> Void
    let onExport: (ExportFormat) -> Void

    private var primary: [EditorAction] { EditorAction.allCases.filter(\.isPrimary) }
    private var more: [EditorAction] { EditorAction.allCases.filter { !$0.isPrimary } }

    var body: some View {
        HStack(spacing: 6) {
            // Primary actions: icon buttons with tooltips + ⌘1…⌘N shortcuts. Icon-only so
            // labels never truncate.
            ForEach(Array(primary.enumerated()), id: \.element) { index, action in
                Button { onAction(action) } label: { Image(systemName: action.systemImage) }
                    .help(action.title)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .disabled(busyAction != nil)
                    .accessibilityIdentifier("action_\(action.title)")
            }

            Menu {
                ForEach(more, id: \.self) { action in
                    Button { onAction(action) } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .help("More actions")
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(busyAction != nil)
                .accessibilityIdentifier("moreActions")

            Spacer()

            Button { onUndo() } label: { Image(systemName: "arrow.uturn.backward") }
                .help("Undo").keyboardShortcut("z", modifiers: .command)
                .disabled(!canUndo).accessibilityIdentifier("undoButton")
            Button { onRedo() } label: { Image(systemName: "arrow.uturn.forward") }
                .help("Redo").keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!canRedo).accessibilityIdentifier("redoButton")
            Button { onCopy() } label: { Image(systemName: "doc.on.doc") }
                .help("Copy all").keyboardShortcut("c", modifiers: [.command, .shift])
                .accessibilityIdentifier("copyButton")

            Menu {
                ForEach(ExportFormat.allCases) { fmt in
                    Button(fmt.label) { onExport(fmt) }
                }
            } label: { Image(systemName: "square.and.arrow.up") }
                .help("Export…")
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityIdentifier("exportButton")

            if busyAction != nil { ProgressView().controlSize(.small) }
        }
        .padding(8)
    }
}
