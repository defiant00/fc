const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const Self = @This();

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;
const RENDER_TICKS_PER_FRAME = 1000 / RENDER_FPS;

const FRAMEBUFFER_WIDTH = 512;
const FRAMEBUFFER_HEIGHT = 1024;

window: ?*sdl.SDL_Window,
renderer: ?*sdl.SDL_Renderer,
framebuffer: ?*sdl.SDL_Texture,
ticks_start: u64,

pub fn init() !Self {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to init SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }

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

    const renderer = sdl.SDL_CreateRenderer(window, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const framebuffer = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_ARGB8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        FRAMEBUFFER_WIDTH,
        FRAMEBUFFER_HEIGHT,
    ) orelse {
        sdl.SDL_Log("Unable to create texture: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    return .{
        .window = window,
        .renderer = renderer,
        .framebuffer = framebuffer,
        .ticks_start = 0,
    };
}

pub fn deinit(self: Self) void {
    if (self.framebuffer) |framebuffer| sdl.SDL_DestroyTexture(framebuffer);
    if (self.renderer) |renderer| sdl.SDL_DestroyRenderer(renderer);
    if (self.window) |window| sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

fn toByte(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

fn toColor(r: u5, g: u5, b: u5, a: u1) u16 {
    return r | (@as(u16, g) << 5) | (@as(u16, b) << 10) | (@as(u16, a) << 15);
}

pub fn setColor(self: Self, r: u5, g: u5, b: u5, a: u1) !void {
    const alpha: u8 = if (a > 0) 0xff else 0;
    if (sdl.SDL_SetRenderDrawColor(self.renderer, toByte(r), toByte(g), toByte(b), alpha) != 0) {
        sdl.SDL_Log("Unable to set render color: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn clear(self: Self) !void {
    if (sdl.SDL_RenderClear(self.renderer) != 0) {
        sdl.SDL_Log("Unable to clear render: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn renderFramebuffer(self: Self) !void {
    if (sdl.SDL_RenderCopy(self.renderer, self.framebuffer, null, null) != 0) {
        sdl.SDL_Log("Unable to render framebuffer: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn present(self: Self) void {
    sdl.SDL_RenderPresent(self.renderer);
}

pub fn frameStart(self: *Self) void {
    self.ticks_start = sdl.SDL_GetTicks64();
}

pub fn frameEnd(self: Self) void {
    const elapsed_ticks: u32 = @intCast(sdl.SDL_GetTicks64() - self.ticks_start);
    if (elapsed_ticks < RENDER_TICKS_PER_FRAME) {
        sdl.SDL_Delay(RENDER_TICKS_PER_FRAME - elapsed_ticks);
    }
}

pub fn frameEndPrintTiming(self: Self) !void {
    const elapsed_ticks: u32 = @intCast(sdl.SDL_GetTicks64() - self.ticks_start);

    var buf: [32]u8 = undefined;
    _ = try std.fmt.bufPrint(&buf, "Target: {d} Actual: {d}\x00", .{
        RENDER_TICKS_PER_FRAME,
        elapsed_ticks,
    });
    sdl.SDL_SetWindowTitle(self.window, &buf);

    if (elapsed_ticks < RENDER_TICKS_PER_FRAME) {
        sdl.SDL_Delay(RENDER_TICKS_PER_FRAME - elapsed_ticks);
    }
}

pub fn toFramebuffer(self: Self) !void {
    if (sdl.SDL_SetRenderTarget(self.renderer, self.framebuffer) != 0) {
        sdl.SDL_Log("Unable to set render target to vram: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn toScreen(self: Self) !void {
    if (sdl.SDL_SetRenderTarget(self.renderer, null) != 0) {
        sdl.SDL_Log("Unable to set render target to window: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn testDraw(self: Self) !void {
    try self.setColor(10, 3, 25, 1);
    _ = sdl.SDL_RenderFillRect(self.renderer, &sdl.SDL_Rect{ .x = 30, .y = 200, .w = 60, .h = 240 });
}
