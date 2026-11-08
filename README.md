# Halite

Deterministic Lattice Boltzmann Fluid / Gas Automaton

A bit-packed 2D hydrodynamic simulation engine implementing the D2Q9 Lattice Boltzmann Method (LBM) with zero floating-point nondeterminism.

## Architecture

- Fixed-Point Determinism: Velocity vectors and particle distributions are discretized into fixed-point integer arithmetic (Q16.16), guaranteeing identical, bit-for-bit simulation frames across x86_64, AArch64, and WebAssembly targets.
- D2Q9 Lattice Scheme: Evaluates nine velocity directions and weights per grid cell with bounce-back boundary conditions for complex obstacle geometries.
- Direct Canvas Export: Exports raw memory slices directly into an RGBA byte buffer compatible with HTML5 Canvas `putImageData()` with minimal JavaScript glue.
- Freestanding WASM: Compiles to a 2.0 KB freestanding WebAssembly binary (`halite.wasm`) without external C runtime dependencies.

## Exported WebAssembly API

```c
void halite_init(void);
void halite_reset(void);
void halite_step(void);
void halite_render(void);
void halite_set_obstacle(uint32_t x, uint32_t y, uint32_t is_solid);
uint8_t* halite_get_rgba_ptr(void);
uint32_t halite_get_width(void);
uint32_t halite_get_height(void);
```

## Building and Testing

```bash
# Run unit tests
zig build test

# Compile native binary and freestanding WASM
zig build -Doptimize=ReleaseFast
```

## License

MIT License - Copyright (c) 2026 Jeong Hoon Kim
