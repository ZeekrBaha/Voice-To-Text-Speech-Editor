@testable import SpeechEditor

final class FakeAudioCapture: AudioCapturing {
    var startCalled = false
    var bufferToReturn = AudioBuffer(samples: Array(repeating: 0.1, count: 16000), sampleRate: 16000)
    func start() throws { startCalled = true }
    func stop() -> AudioBuffer { bufferToReturn }
}
