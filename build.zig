const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fc_exe = b.addExecutable(.{
        .name = "fc",
        .root_source_file = .{ .path = "src/fc/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const gc_exe = b.addExecutable(.{
        .name = "gc",
        .root_source_file = .{ .path = "src/gc/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const shared = b.addModule("shared", .{
        .source_file = .{ .path = "src/shared/shared.zig" },
    });

    fc_exe.addModule("shared", shared);
    gc_exe.addModule("shared", shared);

    const sdl_path = "lib/SDL2-2.28.5/";
    fc_exe.addIncludePath(.{ .path = sdl_path ++ "include" });
    fc_exe.addLibraryPath(.{ .path = sdl_path ++ "lib/x64" });
    gc_exe.addIncludePath(.{ .path = sdl_path ++ "include" });
    gc_exe.addLibraryPath(.{ .path = sdl_path ++ "lib/x64" });

    fc_exe.linkSystemLibrary("SDL2");
    fc_exe.linkLibC();

    gc_exe.linkSystemLibrary("SDL2");
    gc_exe.linkLibC();

    b.installArtifact(fc_exe);
    b.installArtifact(gc_exe);
    b.installBinFile(sdl_path ++ "lib/x64/SDL2.dll", "SDL2.dll");

    const fc_run_cmd = b.addRunArtifact(fc_exe);
    const gc_run_cmd = b.addRunArtifact(gc_exe);

    fc_run_cmd.step.dependOn(b.getInstallStep());
    gc_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        fc_run_cmd.addArgs(args);
        gc_run_cmd.addArgs(args);
    }

    const fc_run_step = b.step("run-fc", "Run fantasy console (fc)");
    const gc_run_step = b.step("run-gc", "Run graphics compiler (gc)");
    fc_run_step.dependOn(&fc_run_cmd.step);
    gc_run_step.dependOn(&gc_run_cmd.step);
}
