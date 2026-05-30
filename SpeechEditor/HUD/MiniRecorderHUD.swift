import SwiftUI

struct MiniRecorderHUD: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 10, height: 10).opacity(pulse ? 0.3 : 1)
            Text("Recording…").font(.caption).bold()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true } }
    }
}

/// Transient message HUD used by HUDController.flash (e.g. a dictation error).
struct StatusFlashHUD: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.caption).bold().lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
