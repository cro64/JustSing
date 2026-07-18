import CAtomics
import Foundation

enum NeuralPipelineState: Equatable {
    case idle
    case warmingUp
    case ready
    case error(String)
}

final class NeuralSeparationPipeline {
    private let model: AudioSeparationModel
    private let sampleRate: Double
    private let windowSamples: Int
    private let hopSamples: Int
    private let delaySamples: Int

    private let inputBuffer: RollingStereoBuffer
    private let outputBuffer: RollingStereoBuffer
    private let delayLine: StereoDelayLine
    private let stitcher: HopSpliceStitcher
    private let discontinuityDetector: AudioDiscontinuityDetector
    let mixDSP: NeuralMixDSP

    private let inferenceQueue = DispatchQueue(label: "com.minusone.neural-inference", qos: .utility)
    private var inferenceWorkItem: DispatchWorkItem?
    private var isInferenceRunning = false
    private let nextInferenceEnd: UnsafeMutablePointer<mo_atomic_uint64_t>
    private let pipelineEpoch: UnsafeMutablePointer<mo_atomic_uint64_t>
    private let outputPrimedEpoch: UnsafeMutablePointer<mo_atomic_uint64_t>
    private let latestOutputEnd: UnsafeMutablePointer<mo_atomic_uint64_t>
    private var inferenceEpoch: UInt64 = 0
    private var hasPrimedOutput = false
    private var pipelineState: NeuralPipelineState = .idle
    private var stateChangeHandler: ((NeuralPipelineState) -> Void)?
    private var flushGraceUntilPosition: UInt64 = 0

    private let scratchInstrumentalLeft: UnsafeMutablePointer<Float>
    private let scratchInstrumentalRight: UnsafeMutablePointer<Float>
    private let scratchDelayedLeft: UnsafeMutablePointer<Float>
    private let scratchDelayedRight: UnsafeMutablePointer<Float>
    private let windowLeft: UnsafeMutablePointer<Float>
    private let windowRight: UnsafeMutablePointer<Float>
    private let maxFramesPerCallback: Int

    init(
        model: AudioSeparationModel,
        sampleRate: Double,
        windowSeconds: Double = 6.0,
        hopSeconds: Double = 1.5,
        makeupGainDecibels: Float,
        rampDurationMilliseconds: Float,
        maxFramesPerCallback: Int = 8_192
    ) {
        self.model = model
        self.sampleRate = sampleRate
        self.maxFramesPerCallback = maxFramesPerCallback

        windowSamples = max(1, Int(sampleRate * windowSeconds))
        hopSamples = max(1, Int(sampleRate * hopSeconds))
        delaySamples = windowSamples

        let bufferCapacity = windowSamples * 4
        inputBuffer = RollingStereoBuffer(capacitySamples: bufferCapacity)
        outputBuffer = RollingStereoBuffer(capacitySamples: bufferCapacity)
        delayLine = StereoDelayLine(requiredDelaySamples: delaySamples, headroomSamples: maxFramesPerCallback)
        stitcher = HopSpliceStitcher(windowLength: windowSamples, hopLength: hopSamples, sampleRate: sampleRate)
        discontinuityDetector = AudioDiscontinuityDetector(sampleRate: sampleRate)
        mixDSP = NeuralMixDSP(makeupGainDecibels: makeupGainDecibels, rampDurationMilliseconds: rampDurationMilliseconds)

        nextInferenceEnd = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        pipelineEpoch = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        outputPrimedEpoch = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        latestOutputEnd = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        mo_atomic_uint64_init(nextInferenceEnd, 0)
        mo_atomic_uint64_init(pipelineEpoch, 0)
        mo_atomic_uint64_init(outputPrimedEpoch, 0)
        mo_atomic_uint64_init(latestOutputEnd, 0)

        scratchInstrumentalLeft = UnsafeMutablePointer<Float>.allocate(capacity: maxFramesPerCallback)
        scratchInstrumentalRight = UnsafeMutablePointer<Float>.allocate(capacity: maxFramesPerCallback)
        scratchDelayedLeft = UnsafeMutablePointer<Float>.allocate(capacity: maxFramesPerCallback)
        scratchDelayedRight = UnsafeMutablePointer<Float>.allocate(capacity: maxFramesPerCallback)
        scratchInstrumentalLeft.initialize(repeating: 0, count: maxFramesPerCallback)
        scratchInstrumentalRight.initialize(repeating: 0, count: maxFramesPerCallback)
        scratchDelayedLeft.initialize(repeating: 0, count: maxFramesPerCallback)
        scratchDelayedRight.initialize(repeating: 0, count: maxFramesPerCallback)

        windowLeft = UnsafeMutablePointer<Float>.allocate(capacity: windowSamples)
        windowRight = UnsafeMutablePointer<Float>.allocate(capacity: windowSamples)
        windowLeft.initialize(repeating: 0, count: windowSamples)
        windowRight.initialize(repeating: 0, count: windowSamples)
    }

    deinit {
        stopInference()
        nextInferenceEnd.deallocate()
        pipelineEpoch.deallocate()
        outputPrimedEpoch.deallocate()
        latestOutputEnd.deallocate()
        scratchInstrumentalLeft.deinitialize(count: maxFramesPerCallback)
        scratchInstrumentalRight.deinitialize(count: maxFramesPerCallback)
        scratchDelayedLeft.deinitialize(count: maxFramesPerCallback)
        scratchDelayedRight.deinitialize(count: maxFramesPerCallback)
        scratchInstrumentalLeft.deallocate()
        scratchInstrumentalRight.deallocate()
        scratchDelayedLeft.deallocate()
        scratchDelayedRight.deallocate()
        windowLeft.deinitialize(count: windowSamples)
        windowRight.deinitialize(count: windowSamples)
        windowLeft.deallocate()
        windowRight.deallocate()
    }

    func setStateChangeHandler(_ handler: @escaping (NeuralPipelineState) -> Void) {
        stateChangeHandler = handler
        handler(pipelineState)
    }

    var state: NeuralPipelineState {
        pipelineState
    }

    var playbackDelaySeconds: Double {
        Double(delaySamples) / sampleRate
    }

    func start() {
        reset()
        setState(.warmingUp)
        startInferenceLoop()
        AppLogger.shared.info(
            "Neural pipeline started: window=\(windowSamples) hop=\(hopSamples) delay=\(delaySamples) model=\(model.name)"
        )
    }

    func stop() {
        stopInference()
        reset()
        setState(.idle)
    }

    func reset() {
        inputBuffer.reset()
        outputBuffer.clearSamples()
        delayLine.reset()
        mixDSP.reset()
        discontinuityDetector.reset()
        hasPrimedOutput = false
        mo_atomic_uint64_store(outputPrimedEpoch, 0)
        mo_atomic_uint64_store(latestOutputEnd, 0)
        mo_atomic_uint64_store(nextInferenceEnd, UInt64(windowSamples))
        mo_atomic_uint64_store(pipelineEpoch, mo_atomic_uint64_load(pipelineEpoch) + 1)
        inferenceEpoch = mo_atomic_uint64_load(pipelineEpoch)
    }

    func process(
        inputLeft: UnsafePointer<Float>,
        inputRight: UnsafePointer<Float>,
        outputLeft: UnsafeMutablePointer<Float>,
        outputRight: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        guard frameCount > 0, frameCount <= maxFramesPerCallback else { return }

        inputBuffer.write(left: inputLeft, right: inputRight, frameCount: frameCount)

        let writePosition = inputBuffer.writePosition
        if discontinuityDetector.evaluate(
            left: inputLeft,
            right: inputRight,
            frameCount: frameCount,
            absolutePosition: writePosition
        ), writePosition >= flushGraceUntilPosition {
            flushAfterDiscontinuity(at: writePosition)
        }

        updateWarmupState(writePosition: writePosition)

        let reductionActive = mixDSP.targetIntensity.load() > 0.001

        delayLine.process(
            inputLeft: inputLeft,
            inputRight: inputRight,
            outputLeft: scratchDelayedLeft,
            outputRight: scratchDelayedRight,
            frameCount: frameCount,
            delaySamples: delaySamples
        )

        guard delayLine.isDelayReady(delaySamples: delaySamples) else {
            outputLeft.update(from: inputLeft, count: frameCount)
            outputRight.update(from: inputRight, count: frameCount)
            return
        }

        let playbackLead = UInt64(frameCount) + UInt64(delaySamples)
        let playbackStart = writePosition >= playbackLead ? writePosition - playbackLead : 0
        let playbackEnd = playbackStart + UInt64(frameCount)
        let outputIsPrimed = mo_atomic_uint64_load(outputPrimedEpoch) == mo_atomic_uint64_load(pipelineEpoch)
        let outputCoversPlayback = playbackEnd <= mo_atomic_uint64_load(latestOutputEnd)
        let canMix = reductionActive
            && writePosition >= playbackLead + UInt64(windowSamples)
            && outputIsPrimed
            && outputCoversPlayback

        guard canMix else {
            outputLeft.update(from: scratchDelayedLeft, count: frameCount)
            outputRight.update(from: scratchDelayedRight, count: frameCount)
            return
        }

        outputBuffer.read(
            atAbsolutePosition: playbackStart,
            left: scratchInstrumentalLeft,
            right: scratchInstrumentalRight,
            frameCount: frameCount
        )

        mixDSP.process(
            rawLeft: scratchDelayedLeft,
            rawRight: scratchDelayedRight,
            instrumentalLeft: scratchInstrumentalLeft,
            instrumentalRight: scratchInstrumentalRight,
            outputLeft: outputLeft,
            outputRight: outputRight,
            frameCount: frameCount,
            sampleRate: sampleRate
        )
    }

    private func flushAfterDiscontinuity(at writePosition: UInt64) {
        resyncPlayback(at: writePosition)
        AppLogger.shared.info("Neural pipeline flushed after audio discontinuity at sample \(writePosition)")
    }

    private func resyncPlayback(at writePosition: UInt64) {
        outputBuffer.clearSamples()
        delayLine.reset()
        hasPrimedOutput = false
        mo_atomic_uint64_store(outputPrimedEpoch, 0)
        mo_atomic_uint64_store(latestOutputEnd, 0)
        mo_atomic_uint64_store(nextInferenceEnd, writePosition + UInt64(windowSamples))
        mo_atomic_uint64_store(pipelineEpoch, mo_atomic_uint64_load(pipelineEpoch) + 1)
        flushGraceUntilPosition = writePosition + UInt64(sampleRate * 3)
        setState(.warmingUp)
    }

    private func tryMarkReady(writePosition: UInt64) {
        guard case .warmingUp = pipelineState else { return }
        let outputIsPrimed = mo_atomic_uint64_load(outputPrimedEpoch) == mo_atomic_uint64_load(pipelineEpoch)
        let enoughBuffered = writePosition >= UInt64(delaySamples + windowSamples)
        if outputIsPrimed, enoughBuffered {
            setState(.ready)
        }
    }

    private func updateWarmupState(writePosition: UInt64) {
        tryMarkReady(writePosition: writePosition)
    }

    private func markOutputWritten(through endPosition: UInt64) {
        let current = mo_atomic_uint64_load(latestOutputEnd)
        if endPosition > current {
            mo_atomic_uint64_store(latestOutputEnd, endPosition)
        }
    }

    private func setState(_ newState: NeuralPipelineState) {
        guard pipelineState != newState else { return }
        pipelineState = newState
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stateChangeHandler?(self.pipelineState)
        }
    }

    private func startInferenceLoop() {
        guard !isInferenceRunning else { return }
        isInferenceRunning = true

        let work = DispatchWorkItem { [weak self] in
            self?.inferenceLoop()
        }
        inferenceWorkItem = work
        inferenceQueue.async(execute: work)
    }

    private func stopInference() {
        inferenceWorkItem?.cancel()
        inferenceWorkItem = nil
        isInferenceRunning = false
    }

    private func syncInferenceEpochIfNeeded() {
        let epoch = mo_atomic_uint64_load(pipelineEpoch)
        guard epoch != inferenceEpoch else { return }
        inferenceEpoch = epoch
        hasPrimedOutput = false
    }

    private func inferenceLoop() {
        while isInferenceRunning, !(inferenceWorkItem?.isCancelled ?? true) {
            syncInferenceEpochIfNeeded()

            let writePosition = inputBuffer.writePosition
            let inferenceEnd = mo_atomic_uint64_load(nextInferenceEnd)

            if shouldThrottleInference(writePosition: writePosition) {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }

            guard writePosition >= inferenceEnd else {
                let samplesRemaining = inferenceEnd - writePosition
                let sleepSeconds = min(0.1, max(0.01, Double(samplesRemaining) / sampleRate))
                Thread.sleep(forTimeInterval: sleepSeconds)
                continue
            }

            inputBuffer.copyWindow(
                endingBefore: inferenceEnd,
                length: windowSamples,
                intoLeft: windowLeft,
                intoRight: windowRight
            )

            let epochAtStart = mo_atomic_uint64_load(pipelineEpoch)

            do {
                let result = try model.separate(
                    left: windowLeft,
                    right: windowRight,
                    frameCount: windowSamples,
                    sampleRate: sampleRate
                )

                guard epochAtStart == mo_atomic_uint64_load(pipelineEpoch) else { continue }

                let instrumentalLeft = result.instrumentalLeft
                let instrumentalRight = result.instrumentalRight

                if !hasPrimedOutput {
                    guard inferenceEnd >= UInt64(windowSamples) else { continue }
                    let startPosition = inferenceEnd - UInt64(windowSamples)
                    instrumentalLeft.withUnsafeBufferPointer { leftPtr in
                        instrumentalRight.withUnsafeBufferPointer { rightPtr in
                            stitcher.writeInitialWindow(
                                left: leftPtr.baseAddress!,
                                right: rightPtr.baseAddress!,
                                atAbsolutePosition: startPosition,
                                into: outputBuffer
                            )
                        }
                    }
                    hasPrimedOutput = true
                    mo_atomic_uint64_store(outputPrimedEpoch, mo_atomic_uint64_load(pipelineEpoch))
                    markOutputWritten(through: startPosition + UInt64(windowSamples))
                    tryMarkReady(writePosition: inputBuffer.writePosition)
                } else {
                    let hopStartIndex = windowSamples - hopSamples
                    let hopStartPosition = inferenceEnd - UInt64(hopSamples)
                    instrumentalLeft.withUnsafeBufferPointer { leftPtr in
                        instrumentalRight.withUnsafeBufferPointer { rightPtr in
                            stitcher.writeHopTail(
                                left: leftPtr.baseAddress!.advanced(by: hopStartIndex),
                                right: rightPtr.baseAddress!.advanced(by: hopStartIndex),
                                atAbsolutePosition: hopStartPosition,
                                into: outputBuffer
                            )
                        }
                    }
                    markOutputWritten(through: hopStartPosition + UInt64(hopSamples))
                }

                mo_atomic_uint64_store(nextInferenceEnd, inferenceEnd + UInt64(hopSamples))
            } catch {
                AppLogger.shared.error("Neural inference failed: \(error.localizedDescription)")
                setState(.error(error.localizedDescription))
                isInferenceRunning = false
                return
            }
        }
    }

    /// When reduction is off, instrumental output is not played — keep the buffer warm but don't burn CPU.
    private func shouldThrottleInference(writePosition: UInt64) -> Bool {
        guard hasPrimedOutput, mixDSP.targetIntensity.load() <= 0.001 else { return false }

        let frontier = mo_atomic_uint64_load(latestOutputEnd)
        guard writePosition > UInt64(delaySamples) else { return false }

        let playbackHead = writePosition - UInt64(delaySamples)
        return frontier >= playbackHead + UInt64(hopSamples)
    }
}
