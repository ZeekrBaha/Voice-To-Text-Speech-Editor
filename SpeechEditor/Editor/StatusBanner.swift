import SwiftUI

/// Dismissible banner shown at the top of the Editor for the current StatusCenter message.
struct StatusBanner: View {
    let message: StatusMessage
    let onDismiss: () -> Void

    private var tint: Color {
        switch message.severity {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    private var icon: String {
        switch message.severity {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(message.text).font(.callout).lineLimit(2)
            Spacer()
            Button { onDismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("statusDismiss")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12))
        .accessibilityIdentifier("statusBanner")
    }
}
