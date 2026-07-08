import Foundation

/// Detects song skips and silence gaps in live system audio.
/// Tuned conservatively — false positives keep the neural pipeline stuck warming up.
final class AudioDiscontinuityDetector {
    private var smoothedRMS: Float = 0
    private var silenceFrames = 0
    private var lastTriggerPosition: UInt64 = 0
    private var lastLeft: Float = 0
    private var lastRight: Float = 0
    private var hasLastSample = false

    private let silenceRMSThreshold: Float = 0.002
    private let activeRMSThreshold: Float = 0.015
    private let hardSampleJumpThreshold: Float = 0.65
    private let silenceFrameThreshold: Int
    private let minRetriggerSamples: UInt64

    init(sampleRate: Double, silenceMilliseconds: Double = 150, minRetriggerSeconds: Double = 2.5) {
        silenceFrameThreshold = max(1, Int(sampleRate * silenceMilliseconds / 1000))
        minRetriggerSamples = UInt64(sampleRate * minRetriggerSeconds)
    }

    func reset() {
        smoothedRMS = 0
        silenceFrames = 0
        lastTriggerPosition = 0
        lastLeft = 0
        lastRight = 0
        hasLastSample = false
    }

    func evaluate(
        left: UnsafePointer<Float>,
        right: UnsafePointer<Float>,
        frameCount: Int,
        absolutePosition: UInt64
    ) -> Bool {
        guard frameCount > 0 else { return false }

        var triggered = false

        if hasLastSample {
            let jump = max(abs(left[0] - lastLeft), abs(right[0] - lastRight))
            if jump >= hardSampleJumpThreshold {
                triggered = true
            }
        }

        var sum: Float = 0
        for frame in 0..<frameCount {
            sum += left[frame] * left[frame] + right[frame] * right[frame]
        }
        let rms = sqrt(sum / Float(frameCount * 2))

        if rms < silenceRMSThreshold {
            silenceFrames += frameCount
            smoothedRMS = smoothedRMS * 0.9
            lastLeft = left[frameCount - 1]
            lastRight = right[frameCount - 1]
            hasLastSample = true
            return registerTrigger(triggered, at: absolutePosition)
        }

        if !triggered,
           silenceFrames >= silenceFrameThreshold,
           rms >= activeRMSThreshold {
            triggered = true
        }

        silenceFrames = 0
        smoothedRMS = smoothedRMS * 0.92 + rms * 0.08
        lastLeft = left[frameCount - 1]
        lastRight = right[frameCount - 1]
        hasLastSample = true

        return registerTrigger(triggered, at: absolutePosition)
    }

    private func registerTrigger(_ triggered: Bool, at absolutePosition: UInt64) -> Bool {
        guard triggered else { return false }
        guard absolutePosition >= lastTriggerPosition + minRetriggerSamples else { return false }
        lastTriggerPosition = absolutePosition
        return true
    }
}
