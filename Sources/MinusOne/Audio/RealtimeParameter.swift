import CAtomics
import Foundation

final class RealtimeParameter {
    private let storage: UnsafeMutablePointer<mo_atomic_float_t>

    init(_ value: Float) {
        storage = UnsafeMutablePointer<mo_atomic_float_t>.allocate(capacity: 1)
        mo_atomic_float_init(storage, value)
    }

    deinit {
        storage.deallocate()
    }

    func store(_ value: Float) {
        mo_atomic_float_store(storage, value)
    }

    func load() -> Float {
        mo_atomic_float_load(storage)
    }
}
