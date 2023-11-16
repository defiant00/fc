const std = @import("std");
const sdl = @import("sdl.zig");
const sdl_lib = @cImport({
    @cInclude("SDL.h");
});

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var alloc = gpa.allocator();

    var sdl_inst = try sdl.init();
    defer sdl_inst.deinit();

    var running = true;
    var event: sdl_lib.SDL_Event = undefined;

    while (running) {
        while (sdl_lib.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl_lib.SDL_QUIT => running = false,
                else => {},
            }
        }

        if (sdl_inst.step()) {
            // todo
        }

        try sdl_inst.toFramebuffer();
        try sdl_inst.setColor(7, 7, 7, 1);
        try sdl_inst.clear();

        try sdl_inst.testDraw();

        try sdl_inst.toScreen();
        try sdl_inst.setColor(0, 0, 0, 1);
        try sdl_inst.clear();

        try sdl_inst.renderFramebuffer();
        sdl_inst.present();
    }
}
