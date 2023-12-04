const std = @import("std");
const Color = @import("shared").Color;

pub const lib = @cImport({
    @cInclude("SDL.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 2) {
        std.debug.print("Converting {s}\n", .{args[1]});

        const img = lib.SDL_LoadBMP(args[1]) orelse {
            lib.SDL_Log("Unable to load image: %s", lib.SDL_GetError());
            return error.SDLError;
        };

        const path_parts = [_][]const u8{ args[1], ".g16" };
        const out_path = try std.mem.concat(alloc, u8, &path_parts);
        const out_file = try std.fs.cwd().createFile(out_path, .{});
        defer out_file.close();

        var comp = try std.compress.deflate.compressor(
            alloc,
            out_file.writer(),
            .{ .level = .best_compression },
        );
        defer comp.deinit();

        if (lib.SDL_LockSurface(img) != 0) {
            lib.SDL_Log("Unable to lock surface: %s", lib.SDL_GetError());
            return error.SDLError;
        }

        var writer = comp.writer();
        try writer.writeInt(u16, @intCast(img.*.w), .little);
        try writer.writeInt(u16, @intCast(img.*.h), .little);

        if (@divTrunc(img.*.pitch, img.*.w) != 4) {
            lib.SDL_Log("Input file must be 32 bit color.");
            return error.InvalidInputFormat;
        }

        const count: usize = @intCast(img.*.w * img.*.h);
        const pixels: [*]u32 = @ptrCast(@alignCast(img.*.pixels));
        var r: u8 = 0;
        var g: u8 = 0;
        var b: u8 = 0;
        var a: u8 = 0;
        for (0..count) |i| {
            lib.SDL_GetRGBA(pixels[i], img.*.format, &r, &g, &b, &a);
            const uc = Color.to5551(r, g, b, a);
            try writer.writeInt(u16, uc, .little);
        }

        try comp.close();

        lib.SDL_UnlockSurface(img);
        lib.SDL_FreeSurface(img);

        std.debug.print("  Done\n", .{});
    }
}
