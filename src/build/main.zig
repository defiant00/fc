const std = @import("std");
const Allocator = std.mem.Allocator;
const shared = @import("shared");

pub const lib = @cImport({
    @cInclude("SDL.h");
});

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "help")) {
        printUsage();
    } else if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "version")) {
        std.debug.print(
            \\release {}
            \\  build {}
            \\
        , .{
            shared.release,
            version,
        });
    } else if (args.len == 2 and std.ascii.endsWithIgnoreCase(args[1], ".bmp")) {
        try convertBitmap(alloc, args[1]);
    } else if (args.len > 1) {
        // todo - build
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn convertBitmap(alloc: Allocator, path: [:0]const u8) !void {
    std.debug.print("Converting {s}\n", .{path});

    const img = lib.SDL_LoadBMP(path) orelse {
        lib.SDL_Log("Unable to load image: %s", lib.SDL_GetError());
        return error.SDLError;
    };

    const path_parts = [_][]const u8{ path, ".g16" };
    const out_path = try std.mem.concat(alloc, u8, &path_parts);
    defer alloc.free(out_path);
    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    var comp = try std.compress.flate.compressor(
        out_file.writer(),
        .{ .level = .best },
    );

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
        const uc = shared.Color.to5551(r, g, b, a);
        try writer.writeInt(u16, uc, .little);
    }

    lib.SDL_UnlockSurface(img);
    lib.SDL_FreeSurface(img);

    try comp.finish();

    std.debug.print("  Done\n", .{});
}

fn printUsage() void {
    std.debug.print(
        \\Usage: build [command]
        \\
        \\Commands:
        \\  [files]    Build specified files
        \\
        \\  help       Print this help and exit
        \\  version    Print versions and exit
        \\
    , .{});
}
