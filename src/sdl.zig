const std = @import("std");
const Color = @import("Color.zig");
pub const lib = @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_image.h");
});

const Self = @This();

const graphics = @embedFile("res/graphics.png");

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;
const RENDER_FPS = 60;

const FRAMEBUFFER_WIDTH = 512;
const FRAMEBUFFER_HEIGHT = 1024;

const VRAM_WIDTH = 1024;
const VRAM_HEIGHT = 1024;

window: ?*lib.SDL_Window,
renderer: ?*lib.SDL_Renderer,
framebuffer: ?*lib.SDL_Texture,
vram: ?*lib.SDL_Texture,
frame: u64,
fullscreen: bool,
screen_rect: lib.SDL_Rect,

pub fn init() !Self {
    // SDL
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

    // SDL Image
    if (lib.IMG_Init(lib.IMG_INIT_PNG) & lib.IMG_INIT_PNG == 0) {
        lib.SDL_Log("Unable to init SDL image: %s", lib.IMG_GetError());
        return error.SDLInitializationFailed;
    }

    const rw = lib.SDL_RWFromConstMem(graphics, graphics.len) orelse {
        lib.SDL_Log("Unable to read graphics: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const gr_surf = lib.IMG_Load_RW(rw, 1) orelse {
        lib.SDL_Log("Unable to load graphics surface: %s", lib.IMG_GetError());
        return error.SDLInitializationFailed;
    };

    // copy graphics to vram
    const vram_surf = lib.SDL_CreateRGBSurface(
        0,
        VRAM_WIDTH,
        VRAM_HEIGHT * 2,
        gr_surf.*.format.*.BitsPerPixel,
        gr_surf.*.format.*.Rmask,
        gr_surf.*.format.*.Gmask,
        gr_surf.*.format.*.Bmask,
        gr_surf.*.format.*.Amask,
    ) orelse {
        lib.SDL_Log("Unable to create surface: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    var dest_rect = lib.SDL_Rect{ .x = 0, .y = VRAM_HEIGHT, .w = VRAM_WIDTH, .h = VRAM_HEIGHT };
    if (lib.SDL_BlitSurface(
        gr_surf,
        null,
        vram_surf,
        &dest_rect,
    ) != 0) {
        lib.SDL_Log("Unable to blit graphics: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    const vram = lib.SDL_CreateTextureFromSurface(renderer, vram_surf) orelse {
        lib.SDL_Log("Unable to create vram: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    lib.SDL_FreeSurface(vram_surf);
    lib.SDL_FreeSurface(gr_surf);

    return .{
        .window = window,
        .renderer = renderer,
        .framebuffer = framebuffer,
        .vram = vram,
        .frame = getFrame(),
        .fullscreen = false,
        .screen_rect = lib.SDL_Rect{ .x = 0, .y = 0, .w = RENDER_WIDTH, .h = RENDER_HEIGHT },
    };
}

pub fn deinit(self: Self) void {
    lib.IMG_Quit();

    if (self.vram) |vram| lib.SDL_DestroyTexture(vram);
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

pub fn print(self: Self, x: u16, y: u16, text: []const u8) !void {
    // todo - background?

    var src = lib.SDL_Rect{ .x = 0, .y = VRAM_HEIGHT, .w = 8, .h = 16 };
    var dest = lib.SDL_Rect{ .x = x, .y = y, .w = 8, .h = 16 };
    for (text) |c| {
        if (c == '\n') {
            dest.x = x;
            dest.y += 16;
        } else if (c == '\t') {
            dest.x += 16;
        } else {
            src.x = (c - 32) * 8;
            if (lib.SDL_RenderCopy(
                self.renderer,
                self.vram,
                &src,
                &dest,
            ) != 0) {
                lib.SDL_Log("Unable to render text: %s", lib.SDL_GetError());
                return error.SDLError;
            }
            dest.x += 8;
        }
    }
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
    try self.tint(Color.white);

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

    if (lib.SDL_RenderCopy(
        self.renderer,
        self.vram,
        &lib.SDL_Rect{ .x = 0, .y = VRAM_HEIGHT, .w = 400, .h = 32 },
        &lib.SDL_Rect{ .x = 8, .y = 140, .w = 400, .h = 32 },
    ) != 0) {
        lib.SDL_Log("Unable to render from vram: %s", lib.SDL_GetError());
        return error.SDLError;
    }

    try self.print(100, 180, "0123,456,789\n/3 >");
    try self.tint(Color.pico8[9]);
    try self.print(100, 220, "99.9%");
}

pub fn tint(self: Self, c: Color) !void {
    if (lib.SDL_SetTextureColorMod(self.vram, c.r, c.g, c.b) != 0) {
        lib.SDL_Log("Unable to set tint color: %s", lib.SDL_GetError());
        return error.SDLError;
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
