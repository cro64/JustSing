import CAtomics
import Foundation

final class StereoRingBuffer {
    private let capacity: Int
    private let mask: Int
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let writeIndex: UnsafeMutablePointer<mo_atomic_uint64_t>
    private let readIndex: UnsafeMutablePointer<mo_atomic_uint64_t>

    init(capacityPowerOfTwo: Int) {
        precondition(capacityPowerOfTwo > 0 && capacityPowerOfTwo & (capacityPowerOfTwo - 1) == 0)
        capacity = capacityPowerOfTwo
        mask = capacityPowerOfTwo - 1
        left = UnsafeMutablePointer<Float>.allocate(capacity: capacityPowerOfTwo)
        right = UnsafeMutablePointer<Float>.allocate(capacity: capacityPowerOfTwo)
        left.initialize(repeating: 0, count: capacityPowerOfTwo)
        right.initialize(repeating: 0, count: capacityPowerOfTwo)
        writeIndex = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        readIndex = UnsafeMutablePointer<mo_atomic_uint64_t>.allocate(capacity: 1)
        mo_atomic_uint64_init(writeIndex, 0)
        mo_atomic_uint64_init(readIndex, 0)
    }

    deinit {
        left.deinitialize(count: capacity)
        right.deinitialize(count: capacity)
        left.deallocate()
        right.deallocate()
        writeIndex.deallocate()
        readIndex.deallocate()
    }

    func reset() {
        mo_atomic_uint64_store(writeIndex, 0)
        mo_atomic_uint64_store(readIndex, 0)
    }

    func write(
        left inputLeft: UnsafePointer<Float>,
        right inputRight: UnsafePointer<Float>,
        frameCount: Int
    ) {
        var write = mo_atomic_uint64_load(writeIndex)
        var read = mo_atomic_uint64_load(readIndex)

        for frame in 0..<frameCount {
            if Int(write - read) >= capacity {
                read += 1
                mo_atomic_uint64_store(readIndex, read)
            }

            let slot = Int(write) & mask
            left[slot] = inputLeft[frame]
            right[slot] = inputRight[frame]
            write += 1
        }

        mo_atomic_uint64_store(writeIndex, write)
    }

    func read(
        left outputLeft: UnsafeMutablePointer<Float>,
        right outputRight: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let write = mo_atomic_uint64_load(writeIndex)
        var read = mo_atomic_uint64_load(readIndex)

        for frame in 0..<frameCount {
            if read < write {
                let slot = Int(read) & mask
                outputLeft[frame] = left[slot]
                outputRight[frame] = right[slot]
                read += 1
            } else {
                outputLeft[frame] = 0
                outputRight[frame] = 0
            }
        }

        mo_atomic_uint64_store(readIndex, read)
    }
}
