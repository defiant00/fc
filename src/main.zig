const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;
const RENDER_TICKS_PER_FRAME = 1000 / RENDER_FPS;

const VRAM_WIDTH = 1024;
const VRAM_HEIGHT = 1024;

fn color(r: u5, g: u5, b: u5, a: u1) u16 {
    return r | (@as(u16, g) << 5) | (@as(u16, b) << 10) | (@as(u16, a) << 15);
}

fn to_u8(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to init SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Fantasy Console Test",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        RENDER_WIDTH,
        RENDER_HEIGHT,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(window, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    var vram = try alloc.alloc(u16, VRAM_WIDTH * VRAM_HEIGHT);
    defer alloc.free(vram);

    for (0..(VRAM_WIDTH * VRAM_HEIGHT)) |i| {
        const br: u5 = @intCast(i % 32);
        vram[i] = color(br, br, br, 1);
    }

    var title_buf: [32]u8 = undefined;

    main_loop: while (true) {
        const prior_ticks = sdl.SDL_GetTicks64();

        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => break :main_loop,
                else => {},
            }
        }

        if (sdl.SDL_SetRenderDrawColor(renderer, 64, 64, 64, 255) != 0) {
            sdl.SDL_Log("Unable to set render color: %s", sdl.SDL_GetError());
            return error.SDLError;
        }
        if (sdl.SDL_RenderClear(renderer) != 0) {
            sdl.SDL_Log("Unable to clear render: %s", sdl.SDL_GetError());
            return error.SDLError;
        }
        sdl.SDL_RenderPresent(renderer);

        // run at a fixed 60 fps
        const elapsed_ticks: u32 = @intCast(sdl.SDL_GetTicks64() - prior_ticks);

        _ = try std.fmt.bufPrint(&title_buf, "Target: {d} Actual: {d}\x00", .{ RENDER_TICKS_PER_FRAME, elapsed_ticks });
        sdl.SDL_SetWindowTitle(window, &title_buf);

        if (elapsed_ticks < RENDER_TICKS_PER_FRAME) {
            sdl.SDL_Delay(RENDER_TICKS_PER_FRAME - elapsed_ticks);
        }
    }
}
