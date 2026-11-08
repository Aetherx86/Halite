# Halite

결정론적 격자 볼츠만 유체 및 기체 오토마톤 (Deterministic Lattice Boltzmann Fluid / Gas Automaton)

부동 소수점 비결정론(floating-point nondeterminism)을 완전히 배제하고 D2Q9 격자 볼츠만 방법(Lattice Boltzmann Method, LBM)을 비트 패킹 정수 연산으로 구현한 2차원 유체역학 시뮬레이션 엔진입니다.

[English Documentation](README.md) • [Interactive WebAssembly Demo](https://aetherx86.github.io/halite/)

## 아키텍처

- 고정소수점 결정론: 속도 벡터와 입자 분포 함수를 Q16.16 고정소수점 정수 연산으로 이산화하여 x86_64, AArch64, WebAssembly 전 타깃에서 비트 단위로 동일한 시뮬레이션 프레임을 보장합니다.
- D2Q9 격자 스키마: 격자 셀당 9개의 속도 방향과 가중치를 계산하며, 복잡한 장애물 지오메트리를 위한 바운스백(bounce-back) 경계 조건을 제공합니다.
- 직접 캔버스 내보내기: 메모리 슬라이스를 HTML5 Canvas `putImageData()`와 직접 호환되는 RGBA 바이트 버퍼 형태로 즉시 내보내어 자바스크립트 글루 오버헤드를 최소화합니다.
- 자립형 WASM: 외부 C 런타임 의존성 없이 2.0 KB 크기의 자립형 WebAssembly 바이너리(`halite.wasm`)로 컴파일됩니다.

## 내보낸 WebAssembly API

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

## 빌드 및 테스트

```bash
# 단위 테스트 실행
zig build test

# 네이티브 바이너리 및 자립형 WASM 컴파일
zig build -Doptimize=ReleaseFast
```

## 라이선스

MIT License - Copyright (c) 2026 Jeong Hoon Kim
