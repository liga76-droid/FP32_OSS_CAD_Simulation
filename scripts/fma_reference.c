#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fenv.h>

#pragma STDC FENV_ACCESS ON

#ifndef FMA_TEST_COUNT
#define FMA_TEST_COUNT 100000
#endif

static uint32_t rng_state = 0x6d2b79f5u;
static uint32_t next_u32(void) {
    uint32_t x = rng_state;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    rng_state = x;
    return x;
}
static float from_bits(uint32_t u) {
    float f; memcpy(&f, &u, sizeof f); return f;
}
static uint32_t to_bits(float f) {
    uint32_t u; memcpy(&u, &f, sizeof u); return u;
}
static int flags_now(void) {
    int f = fetestexcept(FE_INVALID | FE_DIVBYZERO | FE_OVERFLOW |
                         FE_UNDERFLOW | FE_INEXACT);
    return ((f & FE_INVALID)   ? 0x10 : 0) |
           ((f & FE_DIVBYZERO) ? 0x08 : 0) |
           ((f & FE_OVERFLOW)  ? 0x04 : 0) |
           ((f & FE_UNDERFLOW) ? 0x02 : 0) |
           ((f & FE_INEXACT)   ? 0x01 : 0);
}
static void emit(FILE *out, uint32_t a, uint32_t b, uint32_t z) {
    volatile float fa = from_bits(a), fb = from_bits(b), fz = from_bits(z);
    feclearexcept(FE_ALL_EXCEPT);
    volatile float fr = fmaf(fa, fb, fz);
    int flags = flags_now();
    uint32_t r = to_bits(fr);
    fprintf(out, "%08x %08x %08x %08x %02x\n", a, b, z, r, flags);
}
int main(int argc, char **argv) {
    const char *path = (argc > 1) ? argv[1] : "build/fma_vectors.hex";
    FILE *out = fopen(path, "w");
    if (!out) { perror(path); return 2; }
    if (fesetround(FE_TONEAREST) != 0) {
        fprintf(stderr, "Cannot set FE_TONEAREST\n"); return 3;
    }

    /* Directed finite, cancellation, subnormal, overflow and boundary cases. */
    static const uint32_t directed[][3] = {
        {0x3f800000,0x40000000,0x40400000}, /* 1*2+3 */
        {0x3fc00000,0x40100000,0xbf800000},
        {0x00000001,0x3f000000,0x00000000}, /* half min subnormal */
        {0x007fffff,0x3f800000,0x807ffffe},
        {0x7f7fffff,0x40000000,0x00000000},
        {0x00800000,0x3f000000,0x00000000},
        {0x3f800001,0x3f7fffff,0xbf800000}, /* cancellation */
        {0x3f800000,0x3f800000,0xbf800000}, /* exact zero */
        {0x00000000,0x3f800000,0x80000000},
        {0x7f800000,0x00000000,0x3f800000}, /* invalid */
        {0x7f800000,0x3f800000,0xff800000}, /* invalid */
        {0x7fc12345,0x3f800000,0x00000000},
        {0x7f812345,0x3f800000,0x00000000},
        {0x00800000,0x3f000000,0x80000000},
        {0x3f000000,0x3f000000,0x33800000}, /* near rounding boundary */
        {0x3f800000,0x3f800000,0x00000001}
    };
    const size_t nd = sizeof(directed)/sizeof(directed[0]);
    for (size_t i=0; i<nd; ++i) emit(out,directed[i][0],directed[i][1],directed[i][2]);

    /* Stratified random: full raw binary32 space, reproducible xorshift32. */
    for (int i=(int)nd; i<FMA_TEST_COUNT; ++i) {
        uint32_t a=next_u32(), b=next_u32(), z=next_u32();
        switch (i % 6) {
        case 0: /* Unrestricted raw bit patterns, including all classes. */
            break;
        case 1: /* Finite normals across the full exponent range. */
            a=(a & 0x807fffffu) | (((a >> 23) % 254u + 1u) << 23);
            b=(b & 0x807fffffu) | (((b >> 23) % 254u + 1u) << 23);
            z=(z & 0x807fffffu) | (((z >> 23) % 254u + 1u) << 23);
            break;
        case 2: /* Subnormal/zero operands. */
            a &= 0x807fffffu; b &= 0x807fffffu; z &= 0x807fffffu;
            break;
        case 3: /* Values adjacent to the normal/subnormal boundary. */
            a=(a & 0x807fffffu) | ((a & 1u) ? 0x00800000u : 0u);
            b=(b & 0x807fffffu) | ((b & 1u) ? 0x00800000u : 0u);
            z=(z & 0x807fffffu) | ((z & 1u) ? 0x00800000u : 0u);
            break;
        case 4: /* Mix large/small finite exponents to exercise alignment. */
            a=(a & 0x807fffffu) | (((a & 1u) ? 0xfeu : 1u) << 23);
            b=(b & 0x807fffffu) | (((b & 1u) ? 0xfdu : 2u) << 23);
            z=(z & 0x807fffffu) | (((z & 1u) ? 0x02u : 0xfdu) << 23);
            break;
        case 5: /* Explicit special-value classes, with varied signs/payloads. */
            a=(a & 0x807fffffu) | 0x7f800000u;
            b=(b & 0x807fffffu) | ((b & 1u) ? 0x7f800000u : 0x3f800000u);
            if ((z & 3u)==0) z=0x7fc00000u | (z & 0x003fffffu);
            else if ((z & 3u)==1) z=0x7f800000u;
            else z &= 0x807fffffu;
            break;
        }
        emit(out,a,b,z);
    }
    fclose(out);
    fprintf(stderr, "Generated %d fmaf reference vectors (seed=0x6d2b79f5, RNE).\n",
            FMA_TEST_COUNT);
    return 0;
}
