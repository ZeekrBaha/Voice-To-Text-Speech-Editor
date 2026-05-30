import SwiftUI

struct EditorToolbar: View {
    let busyAction: EditorAction?
    let onAction: (EditorAction) -> Void
    let onUndo: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EditorAction.allCases, id: \.self) { action in
                Button(action.title) { onAction(action) }
                    .disabled(busyAction != nil)
                    .accessibilityIdentifier("action_\(action.title)")
            }
            Spacer()
            Button("Undo", action: onUndo).accessibilityIdentifier("undoButton")
            Button("Export", action: onExport).accessibilityIdentifier("exportButton")
            if busyAction != nil { ProgressView().controlSize(.small) }
        }
        .padding(8)
    }
}
