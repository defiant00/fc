const std = @import("std");
const shared = @import("shared");
const Color = shared.Color;

pub const lib = @cImport({
    @cInclude("SDL.h");
});

pub const BlendMode = enum {
    add,
    alpha,
    average,
    multiply,
    none,
};

const Self = @This();

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
pixel_perfect: bool,
screen_rect: lib.SDL_Rect,
screen_scale: f32,
blend_modes: [3]BlendMode,

pub fn init(alloc: std.mem.Allocator) !Self {
    // VRAM
    var gr_buffer = std.io.fixedBufferStream(shared.graphics);
    var dec = try std.compress.deflate.decompressor(alloc, gr_buffer.reader(), null);
    var dec_r = dec.reader();
    const w: usize = try dec_r.readInt(u16, .little);
    const h: usize = try dec_r.readInt(u16, .little);

    const vram_surf = lib.SDL_CreateRGBSurface(
        0,
        VRAM_WIDTH,
        VRAM_HEIGHT * 2,
        32,
        0xff,
        0xff00,
        0xff0000,
        0xff000000,
    ) orelse {
        lib.SDL_Log("Unable to create surface: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    if (lib.SDL_LockSurface(vram_surf) != 0) {
        lib.SDL_Log("Unable to lock surface: %s", lib.SDL_GetError());
        return error.SDLError;
    }
    const pixels: [*]u32 = @ptrCast(@alignCast(vram_surf.*.pixels));
    for (0..h) |hi| {
        for (0..w) |wi| {
            const uc = try dec_r.readInt(u16, .little);
            const color = Color.from16(uc);
            pixels[VRAM_WIDTH * VRAM_HEIGHT + hi * VRAM_WIDTH + wi] = lib.SDL_MapRGBA(
                vram_surf.*.format,
                color.r,
                color.g,
                color.b,
                color.a,
            );
        }
    }
    lib.SDL_UnlockSurface(vram_surf);

    if (dec.close()) |e| return e;
    dec.deinit();

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

    const vram = lib.SDL_CreateTextureFromSurface(renderer, vram_surf) orelse {
        lib.SDL_Log("Unable to create vram: %s", lib.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    lib.SDL_FreeSurface(vram_surf);

    return .{
        .window = window,
        .renderer = renderer,
        .framebuffer = framebuffer,
        .vram = vram,
        .frame = getFrame(),
        .fullscreen = false,
        .pixel_perfect = false,
        .screen_rect = lib.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = RENDER_WIDTH,
            .h = RENDER_HEIGHT,
        },
        .screen_scale = 1,
        .blend_modes = [_]BlendMode{ .none, .none, .none },
    };
}

pub fn deinit(self: Self) void {
    if (self.vram) |vram| lib.SDL_DestroyTexture(vram);
    if (self.framebuffer) |framebuffer| lib.SDL_DestroyTexture(framebuffer);
    if (self.renderer) |renderer| lib.SDL_DestroyRenderer(renderer);
    if (self.window) |window| lib.SDL_DestroyWindow(window);
    lib.SDL_Quit();
}

fn getBufferColor(buffer: []const u8, index: usize) !Color {
    if (index + 1 >= buffer.len) return error.InvalidColorFormat;
    const c: u16 = buffer[index] | (@as(u16, buffer[index + 1]) << 8);
    return Color.from16(c);
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

pub fn fillRect(self: Self, rect: lib.SDL_Rect) !void {
    if (lib.SDL_RenderFillRect(self.renderer, &rect) != 0) {
        lib.SDL_Log("Unable to fill rectangle: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn present(self: Self) void {
    lib.SDL_RenderPresent(self.renderer);
}

pub fn print(self: Self, x: u16, y: u16, text: []const u8) !void {
    var draw_bg = false;

    var src = lib.SDL_Rect{ .x = 0, .y = VRAM_HEIGHT, .w = 3, .h = 7 };
    var dest = lib.SDL_Rect{ .x = x, .y = y, .w = 3, .h = 7 };
    var bg = lib.SDL_Rect{ .x = x, .y = y, .w = 4, .h = 7 };
    {
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const c = text[i];
            switch (c) {
                1 => {
                    // set foreground color
                    const fc = try getBufferColor(text, i + 1);
                    try self.tint(fc);
                    i += 2;
                },
                2 => {
                    // set background color
                    const bc = try getBufferColor(text, i + 1);
                    try self.setColor(bc);
                    draw_bg = true;
                    i += 2;
                },
                3 => {
                    // set both colors
                    const fc = try getBufferColor(text, i + 1);
                    const bc = try getBufferColor(text, i + 3);
                    try self.tint(fc);
                    try self.setColor(bc);
                    draw_bg = true;
                    i += 4;
                },
                4 => {
                    // reset foreground color
                    try self.tint(Color.white);
                },
                5 => {
                    // reset background color (disable background)
                    draw_bg = false;
                },
                6 => {
                    // reset both colors
                    try self.tint(Color.white);
                    draw_bg = false;
                },
                ' ' => {
                    dest.x += 4;
                    bg.w = 4;
                    if (draw_bg) try fillRect(self, bg);
                },
                '\t' => {
                    dest.x += 8;
                    bg.w = 8;
                    if (draw_bg) try fillRect(self, bg);
                },
                '\r' => dest.x = x,
                '\n' => {
                    dest.x = x;
                    dest.y += 8;
                },
                else => {
                    if (c > ' ' and c < 127) {
                        src.x = (@as(c_int, c) - ' ') * 4;
                        src.w = 3;
                    } else if (c >= 127 and c < 138) {
                        src.x = 380 + (@as(c_int, c) - 127) * 8;
                        src.w = 7;
                    } else {
                        src.x = 0;
                        src.w = 3;
                    }
                    dest.w = src.w;
                    bg.w = src.w + 1;
                    if (draw_bg) try fillRect(self, bg);

                    if (lib.SDL_RenderCopy(
                        self.renderer,
                        self.vram,
                        &src,
                        &dest,
                    ) != 0) {
                        lib.SDL_Log("Unable to render text: %s", lib.SDL_GetError());
                        return error.SDLError;
                    }
                    dest.x += src.w + 1;
                },
            }
            bg.x = dest.x;
            bg.y = dest.y;
        }
    }
}

pub fn renderFramebuffer(self: Self) !void {
    var rect = lib.SDL_Rect{ .x = 0, .y = 0, .w = RENDER_WIDTH, .h = RENDER_HEIGHT };

    // draw layer 0
    try self.setBlendMode(.none);
    if (lib.SDL_RenderCopy(self.renderer, self.framebuffer, &rect, &self.screen_rect) != 0) {
        lib.SDL_Log("Unable to render framebuffer: %s", lib.SDL_GetError());
        return error.SDLError;
    }

    // draw layers 1-3
    for (0..3) |i| {
        rect.y += RENDER_HEIGHT;
        if (self.blend_modes[i] != .none) {
            try self.setBlendMode(self.blend_modes[i]);
            if (lib.SDL_RenderCopy(self.renderer, self.framebuffer, &rect, &self.screen_rect) != 0) {
                lib.SDL_Log("Unable to render framebuffer: %s", lib.SDL_GetError());
                return error.SDLError;
            }
        }
    }
}

pub fn resize(self: *Self, x: i32, y: i32) void {
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    self.screen_scale = @min(fx / RENDER_WIDTH, fy / RENDER_HEIGHT);
    if (self.pixel_perfect and self.screen_scale > 1) {
        self.screen_scale = @floor(self.screen_scale);
    }

    self.screen_rect.x = @intFromFloat((fx - (self.screen_scale * RENDER_WIDTH)) / 2);
    self.screen_rect.y = @intFromFloat((fy - (self.screen_scale * RENDER_HEIGHT)) / 2);

    self.screen_rect.w = @intFromFloat(self.screen_scale * RENDER_WIDTH);
    self.screen_rect.h = @intFromFloat(self.screen_scale * RENDER_HEIGHT);
}

fn setBlendMode(self: Self, mode: BlendMode) !void {
    const alpha: u8 = if (mode == .average) 0x7f else 0xff;
    const sdl_mode: c_uint = switch (mode) {
        .add => lib.SDL_BLENDMODE_ADD,
        .multiply => lib.SDL_BLENDMODE_MUL,
        .none => lib.SDL_BLENDMODE_NONE,
        else => lib.SDL_BLENDMODE_BLEND,
    };
    if (lib.SDL_SetTextureAlphaMod(self.framebuffer, alpha) != 0) {
        lib.SDL_Log("Unable to set framebuffer alpha: %s", lib.SDL_GetError());
        return error.SDLError;
    }
    if (lib.SDL_SetTextureBlendMode(self.framebuffer, sdl_mode) != 0) {
        lib.SDL_Log("Unable to set framebuffer blend mode: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn setColor(self: Self, c: Color) !void {
    if (lib.SDL_SetRenderDrawColor(self.renderer, c.r, c.g, c.b, c.a) != 0) {
        lib.SDL_Log("Unable to set color: %s", lib.SDL_GetError());
        return error.SDLError;
    }
}

pub fn step(self: *Self) bool {
    const cur_frame = getFrame();
    if (self.frame == cur_frame) return false;

    if (cur_frame - self.frame > 1) {
        self.frame = cur_frame - 1;
    } else {
        self.frame = cur_frame;
    }

    return true;
}

pub fn testDraw(self: *Self) !void {
    try self.tint(Color.white);

    try self.setColor(Color.transparent);
    try self.clear();

    try self.setColor(Color.pico8[8]);
    _ = lib.SDL_RenderDrawRect(self.renderer, &lib.SDL_Rect{ .x = 0, .y = 0, .w = 512, .h = 256 });

    for (0..16) |i| {
        try self.setColor(Color.pico8[i]);
        _ = lib.SDL_RenderFillRect(self.renderer, &lib.SDL_Rect{
            .x = @intCast((i % 4) * 32 + 4),
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

    try self.tint(Color.white);
    try self.print(260, 8, "\x01\x1f\xfcHEY \x02\x00\xfcYOU, \x03\x1f\x82\xff\x83MORE \x05PARTIAL \x04RESET \x03\x1f\x82\xff\x83OKAY \x06FULL");
    try self.print(260, 20, "\x06\x02\x02\x80a\x02\x04\x08b\x02\x06\x08c\x02\x08\x08d\x02\x0a\x08e\x02\x0c\x08f\x02\x0e\x08g\x02\x10\x08h\x02\x12\x08i\x02\x14\x08j\x02\x16\x08k\x02\x18\x08l\x02\x1a\x08m\x02\x1c\x08n\x02\x1e\x08o");
    try self.print(260, 32, "\x06\x01\x00\x88a\x01\x00\x90b\x01\x00\x98c\x01\x00\xa0d\x01\x00\xa8e\x01\x00\xb0f\x01\x00\xb8g\x01\x00\xc0h\x01\x00\xc8i\x01\x00\xd0j\x01\x00\xd8k\x01\x00\xe0l\x01\x00\xe8m\x01\x00\xf0n\x01\x00\xf8o");
    try self.print(260, 44, "\x06TEST(1, 2)  http://what\\ever[12] SOME{thing + 2} | or");
    try self.print(260, 56, "\x06arg@test$W//\\\\I|M 2 * 3 W[|]");

    try self.print(10, 180, "Hello, world!\nsome TEXT~ don't know...");
    try self.tint(Color.pico8[9]);
    try self.print(10, 220, "99.9% something?");
    try self.tint(Color.pico8[12]);
    try self.print(250, 180, "\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a");
    try self.tint(Color.pico8[14]);
    try self.print(250, 196, "\x7f\x7f\x80\x80\x81\x82\x87\x88\x85\x83\x84\x86\x89");

    self.blend_modes[0] = .multiply;
    try self.setColor(Color.pico8[8]);
    _ = lib.SDL_RenderFillRect(self.renderer, &lib.SDL_Rect{
        .x = 50,
        .y = 300,
        .w = 250,
        .h = 180,
    });
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

pub fn togglePixelPerfect(self: *Self) void {
    self.pixel_perfect = !self.pixel_perfect;

    var x: c_int = 0;
    var y: c_int = 0;
    lib.SDL_GetWindowSize(self.window, &x, &y);
    self.resize(x, y);
}
