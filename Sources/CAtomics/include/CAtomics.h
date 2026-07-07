#ifndef JUSTSING_CATOMICS_H
#define JUSTSING_CATOMICS_H

#include <stdint.h>

typedef struct {
    _Atomic uint32_t bits;
} js_atomic_float_t;

typedef struct {
    _Atomic uint64_t value;
} js_atomic_uint64_t;

void js_atomic_float_init(js_atomic_float_t *atomic, float value);
void js_atomic_float_store(js_atomic_float_t *atomic, float value);
float js_atomic_float_load(js_atomic_float_t *atomic);

void js_atomic_uint64_init(js_atomic_uint64_t *atomic, uint64_t value);
void js_atomic_uint64_store(js_atomic_uint64_t *atomic, uint64_t value);
uint64_t js_atomic_uint64_load(js_atomic_uint64_t *atomic);

#endif
