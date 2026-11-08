// Copyright (c) 2026 jk9576. All rights reserved.
// Halite: Deterministic Lattice Boltzmann Fluid / Gas Automaton (D2Q9)
// Licensed under the MIT License.

pub const lbm = @import("lbm.zig");

var global_grid: lbm.Grid = undefined;
var initialized: bool = false;

pub export fn halite_init() void {
    global_grid = lbm.Grid.init();
    initialized = true;
}

pub export fn halite_reset() void {
    global_grid.reset();
}

pub export fn halite_step() void {
    if (!initialized) halite_init();
    global_grid.step();
}

pub export fn halite_render() void {
    if (!initialized) halite_init();
    global_grid.renderToRgba();
}

pub export fn halite_set_obstacle(x: u32, y: u32, is_solid: u32) void {
    if (!initialized) halite_init();
    global_grid.setObstacleCell(x, y, is_solid != 0);
}

pub export fn halite_get_rgba_ptr() [*]u8 {
    return &global_grid.rgba;
}

pub export fn halite_get_width() u32 {
    return lbm.WIDTH;
}

pub export fn halite_get_height() u32 {
    return lbm.HEIGHT;
}
