import Foundation

/// Live-streaming stitcher: commits only the newest hop-sized tail per window,
/// with a short crossfade at hop boundaries (not full-window Hann OLA).
final class HopSpliceStitcher {
    private let windowLength: Int
    private let hopLength: Int
    private let crossfadeLength: Int

    init(windowLength: Int, hopLength: Int, crossfadeMilliseconds: Double = 20, sampleRate: Double = 48_000) {
        self.windowLength = windowLength
        self.hopLength = hopLength
        let requested = max(64, Int(sampleRate * crossfadeMilliseconds / 1000))
        crossfadeLength = min(requested, hopLength / 2)
    }

    /// First window after reset — overwrite the full analysis window.
    func writeInitialWindow(
        left: UnsafePointer<Float>,
        right: UnsafePointer<Float>,
        atAbsolutePosition startPosition: UInt64,
        into output: RollingStereoBuffer
    ) {
        output.overwrite(
            left: left,
            right: right,
            frameCount: windowLength,
            atAbsolutePosition: startPosition
        )
    }

    /// Subsequent windows — splice only the newest hop tail with a short boundary crossfade.
    func writeHopTail(
        left: UnsafePointer<Float>,
        right: UnsafePointer<Float>,
        atAbsolutePosition hopStartPosition: UInt64,
        into output: RollingStereoBuffer
    ) {
        guard crossfadeLength > 0, hopLength > crossfadeLength else {
            output.overwrite(
                left: left,
                right: right,
                frameCount: hopLength,
                atAbsolutePosition: hopStartPosition
            )
            return
        }

        output.crossfadeThenOverwrite(
            left: left,
            right: right,
            crossfadeLength: crossfadeLength,
            overwriteLength: hopLength - crossfadeLength,
            atAbsolutePosition: hopStartPosition
        )
    }
}
