import Foundation

struct AudioBuffer: Equatable {
    let samples: [Float]   // mono PCM, normalized -1...1
    let sampleRate: Int

    var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }
    func isTooShort(minSeconds: Double) -> Bool { durationSeconds < minSeconds }
}

protocol AudioCapturing: AnyObject {
    func start() throws
    func stop() -> AudioBuffer
}
