// Copyright (c) 2026 jk9576. All rights reserved.
// Halite: Deterministic Lattice Boltzmann Fluid / Gas Automaton (D2Q9)
// Licensed under the MIT License.

const std = @import("std");

pub const WIDTH: usize = 160;
pub const HEIGHT: usize = 80;
pub const NUM_CELLS: usize = WIDTH * HEIGHT;

// Q16.16 fixed-point math helpers
pub const Q: i32 = 65536; // 1.0 in q16.16

pub inline fn qMul(a: i32, b: i32) i32 {
    const p = @as(i64, a) * @as(i64, b);
    return @truncate(p >> 16);
}

pub inline fn qDiv(a: i32, b: i32) i32 {
    if (b == 0) return 0;
    const p = @as(i64, a) << 16;
    return @truncate(@divTrunc(p, b));
}

// D2Q9 lattice velocity vectors: (x, y)
pub const CX = [9]i8{ 0, 1, 0, -1, 0, 1, -1, -1, 1 };
pub const CY = [9]i8{ 0, 0, 1, 0, -1, 1, 1, -1, -1 };

// Opposite direction indices for bounce-back
pub const OPPOSITE = [9]u4{ 0, 3, 4, 1, 2, 7, 8, 5, 6 };

// D2Q9 weights in Q16.16:
// w0 = 4/9 (~0.44444) -> 29127
// w1..4 = 1/9 (~0.11111) -> 7282
// w5..8 = 1/36 (~0.02778) -> 1820
pub const W = [9]i32{ 29127, 7282, 7282, 7282, 7282, 1820, 1820, 1820, 1820 };

pub const Grid = struct {
    f: [NUM_CELLS][9]i32,
    f_next: [NUM_CELLS][9]i32,
    solid: [NUM_CELLS]bool,
    rgba: [NUM_CELLS * 4]u8,
    tau_q16: i32, // Relaxation time, default 1.0 (Q) or 1.2

    pub fn init() Grid {
        var grid: Grid = undefined;
        grid.reset();
        return grid;
    }

    pub fn reset(self: *Grid) void {
        self.tau_q16 = Q + (Q / 5); // 1.2
        @memset(&self.solid, false);
        @memset(&self.rgba, 0);

        // Initial horizontal stream velocity: u_x = 0.08 (~5243 in q16.16), u_y = 0
        const ux_init: i32 = 5243;
        for (0..NUM_CELLS) |idx| {
            for (0..9) |i| {
                const ci_dot_u = @as(i32, CX[i]) * ux_init;
                const eq = qMul(W[i], Q + 3 * ci_dot_u);
                self.f[idx][i] = eq;
                self.f_next[idx][i] = eq;
            }
        }

        // Set default cylinder obstacle at (40, 40)
        self.setCircleObstacle(40, 40, 10, true);
    }

    pub fn setCircleObstacle(self: *Grid, cx: i32, cy: i32, radius: i32, is_solid: bool) void {
        var y: i32 = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: i32 = 0;
            while (x < WIDTH) : (x += 1) {
                const dx = x - cx;
                const dy = y - cy;
                if (dx * dx + dy * dy <= radius * radius) {
                    self.solid[@as(usize, @intCast(y * @as(i32, WIDTH) + x))] = is_solid;
                }
            }
        }
    }

    pub fn setObstacleCell(self: *Grid, x: usize, y: usize, is_solid: bool) void {
        if (x < WIDTH and y < HEIGHT) {
            self.solid[y * WIDTH + x] = is_solid;
        }
    }

    pub fn step(self: *Grid) void {
        // Stream and bounce-back
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < WIDTH) : (x += 1) {
                const curr_idx = y * WIDTH + x;

                if (self.solid[curr_idx]) {
                    continue;
                }

                for (0..9) |i| {
                    const nx = @as(i32, @intCast(x)) + CX[i];
                    const ny = @as(i32, @intCast(y)) + CY[i];

                    if (nx < 0 or nx >= WIDTH or ny < 0 or ny >= HEIGHT) {
                        // Wall bounce
                        self.f_next[curr_idx][OPPOSITE[i]] = self.f[curr_idx][i];
                    } else {
                        const n_idx = @as(usize, @intCast(ny * @as(i32, WIDTH) + nx));
                        if (self.solid[n_idx]) {
                            // Solid bounce-back
                            self.f_next[curr_idx][OPPOSITE[i]] = self.f[curr_idx][i];
                        } else {
                            self.f_next[n_idx][i] = self.f[curr_idx][i];
                        }
                    }
                }
            }
        }

        // Inlet boundary (left column): enforce constant inflow
        const ux_inlet: i32 = 5243; // 0.08
        for (0..HEIGHT) |iy| {
            const idx = iy * WIDTH;
            if (!self.solid[idx]) {
                for (0..9) |i| {
                    const ci_dot_u = @as(i32, CX[i]) * ux_inlet;
                    self.f_next[idx][i] = qMul(W[i], Q + 3 * ci_dot_u);
                }
            }
        }

        // Collision and equilibrium relaxation (BGK)
        const omega = qDiv(Q, self.tau_q16); // 1 / tau

        for (0..NUM_CELLS) |idx| {
            if (self.solid[idx]) continue;

            var rho: i32 = 0;
            var ux: i32 = 0;
            var uy: i32 = 0;

            for (0..9) |i| {
                const fi = self.f_next[idx][i];
                rho += fi;
                ux += fi * CX[i];
                uy += fi * CY[i];
            }

            if (rho > 0) {
                ux = qDiv(ux, rho);
                uy = qDiv(uy, rho);
            }

            const u_sq = qMul(ux, ux) + qMul(uy, uy);

            for (0..9) |i| {
                const ci_u = @as(i32, CX[i]) * ux + @as(i32, CY[i]) * uy;
                const eq = qMul(W[i], rho + 3 * ci_u + @divTrunc(9 * qMul(ci_u, ci_u), 2) - @divTrunc(3 * u_sq, 2));
                self.f[idx][i] = self.f_next[idx][i] - qMul(omega, self.f_next[idx][i] - eq);
            }
        }
    }

    /// Renders current fluid state into RGBA linear buffer for Canvas ImageData.
    pub fn renderToRgba(self: *Grid) void {
        for (0..NUM_CELLS) |idx| {
            const pixel_offset = idx * 4;

            if (self.solid[idx]) {
                // Obstacle: cybernetic dark gray/slate
                self.rgba[pixel_offset + 0] = 30;
                self.rgba[pixel_offset + 1] = 35;
                self.rgba[pixel_offset + 2] = 45;
                self.rgba[pixel_offset + 3] = 255;
                continue;
            }

            var ux: i32 = 0;
            var uy: i32 = 0;
            for (0..9) |i| {
                const fi = self.f[idx][i];
                ux += fi * CX[i];
                uy += fi * CY[i];
            }

            // Compute speed squared
            const speed = @abs(ux) + @abs(uy);
            const val: u8 = @truncate(@min(255, @divTrunc(speed, 32)));

            // Cybernetic neon fluid color map (cyan/blue/magenta)
            self.rgba[pixel_offset + 0] = @truncate(@min(255, @as(usize, val) * 2)); // Red/Magenta
            self.rgba[pixel_offset + 1] = @truncate(@min(255, 100 + @as(usize, val))); // Green/Cyan
            self.rgba[pixel_offset + 2] = 220; // Deep Blue
            self.rgba[pixel_offset + 3] = 255; // Alpha
        }
    }
};
