const std = @import("std");
const Color = @import("Color.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var alloc = gpa.allocator();

    // encode/decode test
    // var file = try std.fs.cwd().createFile("compressed_test.bin", .{});
    // var comp = try std.compress.deflate.compressor(
    //     alloc,
    //     file.writer(),
    //     .{ .level = .best_compression },
    // );
    // var wr = comp.writer();
    // try wr.writeAll("Hello, world!");

    // cleanup
    // try comp.close();
    // comp.deinit();
    // file.close();

    // decode
    // file = try std.fs.cwd().openFile("compressed_test.bin", .{});
    // var dec = try std.compress.deflate.decompressor(alloc, file.reader(), null);
    // var re = dec.reader();
    // var dec_val = try re.readAllAlloc(alloc, std.math.maxInt(usize));

    // std.debug.print("value: '{s}'\n", .{dec_val});

    // cleanup
    // alloc.free(dec_val);
    // if (dec.close()) |e| return e;
    // dec.deinit();
    // file.close();

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
