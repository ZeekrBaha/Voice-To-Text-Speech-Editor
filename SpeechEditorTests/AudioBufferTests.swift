import Testing
@testable import SpeechEditor

@Suite("AudioBuffer")
struct AudioBufferTests {
    @Test("durationSeconds derives from sample count and rate")
    func duration() {
        let buf = AudioBuffer(samples: Array(repeating: 0, count: 16000), sampleRate: 16000)
        #expect(buf.durationSeconds == 1.0)
    }

    @Test("isTooShort below threshold")
    func tooShort() {
        let buf = AudioBuffer(samples: Array(repeating: 0, count: 1600), sampleRate: 16000)
        #expect(buf.isTooShort(minSeconds: 0.3) == true)   // 0.1s < 0.3s
        #expect(AudioBuffer(samples: [], sampleRate: 16000).isTooShort(minSeconds: 0.3) == true)
    }
}
