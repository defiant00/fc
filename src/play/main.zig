const std = @import("std");
const Allocator = std.mem.Allocator;
const shared = @import("shared");
const Color = shared.Color;
const sdl = @import("sdl.zig");

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 1) {
        try play(alloc, null);
    } else if (args.len == 2) {
        if (std.ascii.eqlIgnoreCase(args[1], "help")) {
            printUsage();
        } else if (std.ascii.eqlIgnoreCase(args[1], "version")) {
            std.debug.print(
                \\release {}
                \\   play {}
                \\
            , .{
                shared.release,
                version,
            });
        } else {
            try play(alloc, args[1]);
        }
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn play(alloc: Allocator, path: ?[:0]const u8) !void {
    // todo - load from path if not null
    _ = alloc;
    _ = path;

    var sdl_inst = try sdl.init();
    defer sdl_inst.deinit();

    var running = true;
    var event: sdl.lib.SDL_Event = undefined;

    while (running) {
        while (sdl.lib.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.lib.SDL_KEYDOWN => {
                    if (event.key.keysym.mod & sdl.lib.KMOD_ALT > 0) {
                        switch (event.key.keysym.sym) {
                            sdl.lib.SDLK_RETURN => try sdl_inst.toggleFullscreen(),
                            sdl.lib.SDLK_p => sdl_inst.togglePixelPerfect(),
                            else => {},
                        }
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
            std.debug.print("_", .{});
        } else {
            std.debug.print("s", .{});
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

fn printUsage() void {
    std.debug.print(
        \\Usage: play [command]
        \\
        \\Commands:
        \\  [file]     Play specified file
        \\
        \\  help       Print this help and exit
        \\  version    Print versions and exit
        \\
    , .{});
}
