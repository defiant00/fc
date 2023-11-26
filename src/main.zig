const std = @import("std");
const Color = @import("Color.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var alloc = gpa.allocator();

    var sdl_inst = try sdl.init();
    defer sdl_inst.deinit();

    var running = true;
    var event: sdl.lib.SDL_Event = undefined;

    while (running) {
        while (sdl.lib.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.lib.SDL_KEYDOWN => {
                    if (event.key.keysym.sym == sdl.lib.SDLK_RETURN and
                        (event.key.keysym.mod & sdl.lib.KMOD_ALT) > 0)
                    {
                        try sdl_inst.toggleFullscreen();
                    }
                },
                sdl.lib.SDL_WINDOWEVENT => {
                    if (event.window.event == sdl.lib.SDL_WINDOWEVENT_SIZE_CHANGED) {
                        const x = event.window.data1;
                        const y = event.window.data2;
                        sdl_inst.resize(x, y);
                    }
                },
                sdl.lib.SDL_QUIT => running = false,
                else => {},
            }
        }

        if (sdl_inst.step()) {
            // todo
        }

        try sdl_inst.toFramebuffer();
        try sdl_inst.testDraw();

        try sdl_inst.toScreen();
        try sdl_inst.setColor(Color.black);
        try sdl_inst.clear();
        try sdl_inst.renderFramebuffer();
        sdl_inst.present();
    }
}
