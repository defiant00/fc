const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const Self = @This();

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;

const FRAMEBUFFER_WIDTH = 512;
const FRAMEBUFFER_HEIGHT = 1024;

window: ?*sdl.SDL_Window,
renderer: ?*sdl.SDL_Renderer,
framebuffer: ?*sdl.SDL_Texture,
frame: u64,

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

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_PRESENTVSYNC) orelse {
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
        .frame = getFrame(),
    };
}

pub fn deinit(self: Self) void {
    if (self.framebuffer) |framebuffer| sdl.SDL_DestroyTexture(framebuffer);
    if (self.renderer) |renderer| sdl.SDL_DestroyRenderer(renderer);
    if (self.window) |window| sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

fn getFrame() u64 {
    return sdl.SDL_GetTicks64() * RENDER_FPS / 1000;
}

fn toByte(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

fn toColor(r: u5, g: u5, b: u5, a: u1) u16 {
    return r | (@as(u16, g) << 5) | (@as(u16, b) << 10) | (@as(u16, a) << 15);
}

pub fn clear(self: Self) !void {
    if (sdl.SDL_RenderClear(self.renderer) != 0) {
        sdl.SDL_Log("Unable to clear render: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn step(self: *Self) bool {
    const cur_frame = getFrame();
    const frame_diff = cur_frame - self.frame;
    if (frame_diff == 1) {
        self.frame = cur_frame;
        return true;
    }
    if (frame_diff > 1) {
        self.frame = cur_frame - 2;
        return true;
    }
    return false;
}

pub fn present(self: Self) void {
    sdl.SDL_RenderPresent(self.renderer);
}

pub fn renderFramebuffer(self: Self) !void {
    if (sdl.SDL_RenderCopy(self.renderer, self.framebuffer, null, null) != 0) {
        sdl.SDL_Log("Unable to render framebuffer: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn setColor(self: Self, r: u5, g: u5, b: u5, a: u1) !void {
    const alpha: u8 = if (a > 0) 0xff else 0;
    if (sdl.SDL_SetRenderDrawColor(self.renderer, toByte(r), toByte(g), toByte(b), alpha) != 0) {
        sdl.SDL_Log("Unable to set color: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn testDraw(self: Self) !void {
    try self.setColor(10, 3, 25, 1);
    _ = sdl.SDL_RenderFillRect(self.renderer, &sdl.SDL_Rect{ .x = 30, .y = 200, .w = 60, .h = 240 });
}

pub fn toFramebuffer(self: Self) !void {
    if (sdl.SDL_SetRenderTarget(self.renderer, self.framebuffer) != 0) {
        sdl.SDL_Log("Unable to set render target to framebuffer: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

pub fn toScreen(self: Self) !void {
    if (sdl.SDL_SetRenderTarget(self.renderer, null) != 0) {
        sdl.SDL_Log("Unable to set render target to window: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}
