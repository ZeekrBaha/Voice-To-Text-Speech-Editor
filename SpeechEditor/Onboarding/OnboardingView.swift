import SwiftUI

struct OnboardingView: View {
    let permissions: PermissionsService
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Speech Editor").font(.title2).bold()
            Text("Hold the Right-Control key anywhere to dictate.").foregroundStyle(.secondary)
            Button("Grant Microphone Access") { Task { _ = await permissions.requestMic() } }
            Button("Grant Speech Recognition Access") { Task { _ = await permissions.requestSpeech() } }
            Button("Grant Accessibility Access") { permissions.promptAccessibility() }
            Button("Done", action: onDone).keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 440)
    }
}
