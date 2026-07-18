#include "CAtomics.h"
#include <stdatomic.h>
#include <string.h>

static uint32_t mo_float_to_bits(float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static float mo_bits_to_float(uint32_t bits) {
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

void mo_atomic_float_init(mo_atomic_float_t *atomic, float value) {
    atomic_init(&atomic->bits, mo_float_to_bits(value));
}

void mo_atomic_float_store(mo_atomic_float_t *atomic, float value) {
    atomic_store_explicit(&atomic->bits, mo_float_to_bits(value), memory_order_relaxed);
}

float mo_atomic_float_load(mo_atomic_float_t *atomic) {
    return mo_bits_to_float(atomic_load_explicit(&atomic->bits, memory_order_relaxed));
}

void mo_atomic_uint64_init(mo_atomic_uint64_t *atomic, uint64_t value) {
    atomic_init(&atomic->value, value);
}

void mo_atomic_uint64_store(mo_atomic_uint64_t *atomic, uint64_t value) {
    atomic_store_explicit(&atomic->value, value, memory_order_release);
}

uint64_t mo_atomic_uint64_load(mo_atomic_uint64_t *atomic) {
    return atomic_load_explicit(&atomic->value, memory_order_acquire);
}
