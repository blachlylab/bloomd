BLOOM'd
=======
A Dlang bloom filter implementation using SIMD and murmurhash3 32-bit

## Installation

Currently requires LDC >=1.10
Depending on architecture uses SSE2/3/4 or AVX/AVX2 instructions to perform hashing.

```
"dflags":["-mcpu=native"]
```
Add this to the dub.json in order to get the best optimizations.