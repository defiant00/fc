const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;
const RENDER_TICKS_PER_FRAME = 1000 / RENDER_FPS;

fn color(r: u5, g: u5, b: u5, a: u1) u16 {
    return r | (@as(u16, g) << 5) | (@as(u16, b) << 10) | (@as(u16, a) << 15);
}

fn to_u8(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to init SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "Fantasy Console Test",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        RENDER_WIDTH,
        RENDER_HEIGHT,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, 0) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var vram = try alloc.alloc(u16, 1024 * 1024);
    defer alloc.free(vram);

    for (0..(1024 * 1024)) |i| {
        const br: u5 = @intCast(i % 32);
        vram[i] = color(br, br, br, 1);
    }

    var title_buf: [32]u8 = undefined;

    main_loop: while (true) {
        const prior_ticks = c.SDL_GetTicks64();

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :main_loop,
                else => {},
            }
        }

        if (c.SDL_SetRenderDrawColor(renderer, 64, 64, 64, 255) != 0) {
            c.SDL_Log("Unable to set render color: %s", c.SDL_GetError());
            return error.SDLError;
        }
        if (c.SDL_RenderClear(renderer) != 0) {
            c.SDL_Log("Unable to clear render: %s", c.SDL_GetError());
            return error.SDLError;
        }
        c.SDL_RenderPresent(renderer);

        // run at a fixed 60 fps
        const elapsed_ticks: u32 = @intCast(c.SDL_GetTicks64() - prior_ticks);

        _ = try std.fmt.bufPrint(&title_buf, "Target: {d} Actual: {d}\x00", .{ RENDER_TICKS_PER_FRAME, elapsed_ticks });
        c.SDL_SetWindowTitle(window, &title_buf);

        if (elapsed_ticks < RENDER_TICKS_PER_FRAME) {
            c.SDL_Delay(RENDER_TICKS_PER_FRAME - elapsed_ticks);
        }
    }
}
