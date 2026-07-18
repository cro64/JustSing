import CAtomics
import Foundation

final class RealtimeParameter {
    private let storage: UnsafeMutablePointer<js_atomic_float_t>

    init(_ value: Float) {
        storage = UnsafeMutablePointer<js_atomic_float_t>.allocate(capacity: 1)
        js_atomic_float_init(storage, value)
    }

    deinit {
        storage.deallocate()
    }

    func store(_ value: Float) {
        js_atomic_float_store(storage, value)
    }

    func load() -> Float {
        js_atomic_float_load(storage)
    }
}
