const std = @import("std");
const Color = @import("Color.zig");
pub const lib = @cImport({
    @cInclude("SDL.h");
});

const Self = @This();

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;

const FRAMEBUFFER_WIDTH = 512;
const FRAMEBUFFER_HEIGHT = 1024;

window: ?*lib.SDL_Window,
renderer: ?*lib.SDL_Renderer,
framebuffer: ?*lib.SDL_Texture,
frame: u64,
fullscreen: bool,
screen_rect: lib.SDL_Rect,

pub fn init() !Self {
    if (lib.SDL_Init(lib.SDL_INIT_VIDEO) != 0) {
        lib.SDL_Log("Unable to init SDL: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    const window = lib.SDL_CreateWindow(
        "Fantasy Console Test",
        lib.SDL_WINDOWPOS_CENTERED,
        lib.SDL_WINDOWPOS_CENTERED,
        RENDER_WIDTH,
        RENDER_HEIGHT,
        lib.SDL_WINDOW_RESIZABLE,
    ) orelse {
        lib.SDL_Log("Unable to create window: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const renderer = lib.SDL_CreateRenderer(window, -1, lib.SDL_RENDERER_PRESENTVSYNC) orelse {
        lib.SDL_Log("Unable to create renderer: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const framebuffer = lib.SDL_CreateTexture(
        renderer,
        lib.SDL_PIXELFORMAT_ARGB8888,
        lib.SDL_TEXTUREACCESS_TARGET,
        FRAMEBUFFER_WIDTH,
        FRAMEBUFFER_HEIGHT,
    ) orelse {
        lib.SDL_Log("Unable to create texture: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    return .{
        .window = window,
        .renderer = renderer,
        .framebuffer = framebuffer,
        .frame = getFrame(),
        .fullscreen = false,
        .screen_rect = lib.SDL_Rect{ .x = 0, .y = 0, .w = RENDER_WIDTH, .h = RENDER_HEIGHT },
    };
}

pub fn deinit(self: Self) void {
    if (self.framebuffer) |framebuffer| lib.SDL_DestroyTexture(framebuffer);
    if (self.renderer) |renderer| lib.SDL_DestroyRenderer(renderer);
    if (self.window) |window| lib.SDL_DestroyWindow(window);
    lib.SDL_Quit();
}

fn getFrame() u64 {
    return lib.SDL_GetTicks64() * RENDER_FPS / 1000;
}

pub fn clear(self: Self) !void {
    if (lib.SDL_RenderClear(self.renderer) != 0) {
        lib.SDL_Log("Unable to clear render: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn present(self: Self) void {
    lib.SDL_RenderPresent(self.renderer);
}

pub fn renderFramebuffer(self: Self) !void {
    if (lib.SDL_RenderCopy(
        self.renderer,
        self.framebuffer,
        &lib.SDL_Rect{ .x = 0, .y = 0, .w = RENDER_WIDTH, .h = RENDER_HEIGHT },
        &self.screen_rect,
    ) != 0) {
        lib.SDL_Log("Unable to render framebuffer: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn resize(self: *Self, x: i32, y: i32) void {
    const fx: f64 = @floatFromInt(x);
    const fy: f64 = @floatFromInt(y);
    const scale = @min(fx / RENDER_WIDTH, fy / RENDER_HEIGHT);

    self.screen_rect.x = @intFromFloat((fx - (scale * RENDER_WIDTH)) / 2);
    self.screen_rect.y = @intFromFloat((fy - (scale * RENDER_HEIGHT)) / 2);

    self.screen_rect.w = @intFromFloat(scale * RENDER_WIDTH);
    self.screen_rect.h = @intFromFloat(scale * RENDER_HEIGHT);
}

pub fn setColor(self: Self, c: Color) !void {
    if (lib.SDL_SetRenderDrawColor(self.renderer, c.r, c.g, c.b, c.a) != 0) {
        lib.SDL_Log("Unable to set color: %s", lib.SDL_GetError());
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

pub fn testDraw(self: Self) !void {
    try self.setColor(Color.from555(7, 7, 7));
    try self.clear();

    try self.setColor(Color.pico8[12]);
    _ = lib.SDL_RenderDrawRect(self.renderer, &lib.SDL_Rect{ .x = 1, .y = 1, .w = 256, .h = 128 });
    try self.setColor(Color.pico8[8]);
    _ = lib.SDL_RenderDrawRect(self.renderer, &lib.SDL_Rect{ .x = 0, .y = 0, .w = 512, .h = 256 });

    for (0..16) |i| {
        try self.setColor(Color.pico8[i]);
        _ = lib.SDL_RenderFillRect(self.renderer, &lib.SDL_Rect{
            .x = @intCast((i % 4) * 32 + 260),
            .y = @intCast((i / 4) * 32 + 4),
            .w = 32,
            .h = 32,
        });
    }
}

pub fn toFramebuffer(self: Self) !void {
    if (lib.SDL_SetRenderTarget(self.renderer, self.framebuffer) != 0) {
        lib.SDL_Log("Unable to set render target to framebuffer: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn toScreen(self: Self) !void {
    if (lib.SDL_SetRenderTarget(self.renderer, null) != 0) {
        lib.SDL_Log("Unable to set render target to window: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn toggleFullscreen(self: *Self) !void {
    self.fullscreen = !self.fullscreen;
    if (lib.SDL_SetWindowFullscreen(
        self.window,
        if (self.fullscreen) lib.SDL_WINDOW_FULLSCREEN_DESKTOP else 0,
    ) != 0) {
        lib.SDL_Log("Unable to toggle fullscreen: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}
