#ifndef MINUSONE_CATOMICS_H
#define MINUSONE_CATOMICS_H

#include <stdint.h>

typedef struct {
    _Atomic uint32_t bits;
} mo_atomic_float_t;

typedef struct {
    _Atomic uint64_t value;
} mo_atomic_uint64_t;

void mo_atomic_float_init(mo_atomic_float_t *atomic, float value);
void mo_atomic_float_store(mo_atomic_float_t *atomic, float value);
float mo_atomic_float_load(mo_atomic_float_t *atomic);

void mo_atomic_uint64_init(mo_atomic_uint64_t *atomic, uint64_t value);
void mo_atomic_uint64_store(mo_atomic_uint64_t *atomic, uint64_t value);
uint64_t mo_atomic_uint64_load(mo_atomic_uint64_t *atomic);

#endif
