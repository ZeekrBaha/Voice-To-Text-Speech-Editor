import Foundation
import Speech
import AVFoundation

/// Concrete TranscriptionEngine backed by Apple's on-device Speech framework.
/// Build-verified only; real recognition requires Speech authorization (handled by PermissionsService).
final class AppleSpeechEngine: TranscriptionEngine {
    private let locale: Locale

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    func transcribe(_ audio: AudioBuffer, vocabulary: [String]) async throws -> String {
        guard !audio.samples.isEmpty else { return "" }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw AppError.transcriptionFailed("Speech recognizer is unavailable for \(locale.identifier).")
        }

        // Rebuild an AVAudioPCMBuffer (mono Float32) from the captured samples.
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: Double(audio.sampleRate),
                                         channels: 1, interleaved: false),
              let pcm = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(audio.samples.count)) else {
            throw AppError.transcriptionFailed("Could not construct audio buffer.")
        }
        pcm.frameLength = AVAudioFrameCount(audio.samples.count)
        if let channel = pcm.floatChannelData {
            audio.samples.withUnsafeBufferPointer { src in
                if let base = src.baseAddress {
                    channel[0].update(from: base, count: audio.samples.count)
                }
            }
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        // Prefer on-device when supported; otherwise fall back so recognition still works.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false
        if !vocabulary.isEmpty { request.contextualStrings = vocabulary }
        request.append(pcm)
        request.endAudio()

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let resumeOnce: (Result<String, Error>) -> Void = { outcome in
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: outcome)
            }
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    resumeOnce(.failure(AppError.transcriptionFailed(error.localizedDescription)))
                    return
                }
                guard let result else { return }
                if result.isFinal {
                    resumeOnce(.success(result.bestTranscription.formattedString))
                }
            }
        }
    }
}
