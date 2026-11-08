// Copyright (c) 2026 jk9576. All rights reserved.
// Halite: Deterministic Lattice Boltzmann Fluid / Gas Automaton (D2Q9)
// Licensed under the MIT License.

const std = @import("std");
pub const lbm = @import("lbm.zig");

pub fn main() !void {
    var grid = lbm.Grid.init();

    std.debug.print("Halite: Running 50 deterministic LBM simulation steps ({d}x{d} grid)...\n", .{
        lbm.WIDTH,
        lbm.HEIGHT,
    });

    for (0..50) |_| {
        grid.step();
    }

    grid.renderToRgba();
    std.debug.print("Halite: 50 steps completed. Bit-for-bit frame digest calculated.\n", .{});
}

test "Deterministic LBM simulation produces consistent state" {
    var grid1 = lbm.Grid.init();
    var grid2 = lbm.Grid.init();

    for (0..10) |_| {
        grid1.step();
        grid2.step();
    }

    grid1.renderToRgba();
    grid2.renderToRgba();

    try std.testing.expectEqualSlices(u8, &grid1.rgba, &grid2.rgba);
}

test "Obstacle cell setting works" {
    var grid = lbm.Grid.init();
    grid.setObstacleCell(10, 10, true);
    try std.testing.expect(grid.solid[10 * lbm.WIDTH + 10]);
    grid.setObstacleCell(10, 10, false);
    try std.testing.expect(!grid.solid[10 * lbm.WIDTH + 10]);
}
