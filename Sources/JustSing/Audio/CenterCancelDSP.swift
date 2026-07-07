import Foundation

final class CenterCancelDSP {
    let targetIntensity: RealtimeParameter
    let makeupGainDecibels: RealtimeParameter
    let rampDurationMilliseconds: RealtimeParameter

    private var appliedIntensity: Float = 0

    init(targetIntensity: Float, makeupGainDecibels: Float, rampDurationMilliseconds: Float) {
        self.targetIntensity = RealtimeParameter(targetIntensity)
        self.makeupGainDecibels = RealtimeParameter(makeupGainDecibels)
        self.rampDurationMilliseconds = RealtimeParameter(rampDurationMilliseconds)
    }

    func reset() {
        appliedIntensity = 0
    }

    func process(
        inputLeft: UnsafePointer<Float>,
        inputRight: UnsafePointer<Float>,
        outputLeft: UnsafeMutablePointer<Float>,
        outputRight: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        guard frameCount > 0 else { return }

        let target = clamp(targetIntensity.load(), 0, 1)
        let rampMilliseconds = clamp(rampDurationMilliseconds.load(), 30, 80)
        let rampFrames = max(1, Int(sampleRate * Double(rampMilliseconds) / 1000.0))
        let makeupLinear = decibelsToLinear(clamp(makeupGainDecibels.load(), 0, 12))

        for frame in 0..<frameCount {
            if appliedIntensity != target {
                let delta = target - appliedIntensity
                let step = min(abs(delta), 1.0 / Float(rampFrames))
                appliedIntensity += delta.sign == .minus ? -step : step
            }

            let left = inputLeft[frame]
            let right = inputRight[frame]
            let intensity = appliedIntensity
            let diff = left - right
            let dry = 1 - intensity

            var outLeft = left * dry + diff * intensity
            var outRight = right * dry + diff * intensity

            let loudnessComp = 1 + (makeupLinear - 1) * intensity
            outLeft *= loudnessComp
            outRight *= loudnessComp

            outputLeft[frame] = outLeft
            outputRight[frame] = outRight
        }
    }

    private func decibelsToLinear(_ decibels: Float) -> Float {
        pow(10, decibels / 20)
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
