import AVFoundation
import ApplicationServices
import Speech

final class PermissionsService {
    private let micGranted: () -> Bool
    private let axTrusted: () -> Bool
    private let speechGranted: () -> Bool

    init(micGranted: @escaping () -> Bool = {
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
         },
         axTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
         speechGranted: @escaping () -> Bool = {
            SFSpeechRecognizer.authorizationStatus() == .authorized
         }) {
        self.micGranted = micGranted; self.axTrusted = axTrusted; self.speechGranted = speechGranted
    }

    var isReady: Bool { micGranted() && axTrusted() && speechGranted() }

    func requestMic() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }

    func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
