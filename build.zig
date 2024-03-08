const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const play_exe = b.addExecutable(.{
        .name = "play",
        .root_source_file = .{ .path = "src/play/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const build_exe = b.addExecutable(.{
        .name = "build",
        .root_source_file = .{ .path = "src/build/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const shared = b.addModule("shared", .{
        .root_source_file = .{ .path = "src/shared/shared.zig" },
    });

    play_exe.root_module.addImport("shared", shared);
    build_exe.root_module.addImport("shared", shared);

    // SDL2
    const sdl_path = "C:\\libs\\SDL2-2.30.1\\";
    play_exe.addIncludePath(.{ .path = sdl_path ++ "include" });
    build_exe.addIncludePath(.{ .path = sdl_path ++ "include" });
    play_exe.addLibraryPath(.{ .path = sdl_path ++ "lib\\x64" });
    build_exe.addLibraryPath(.{ .path = sdl_path ++ "lib\\x64" });
    play_exe.linkSystemLibrary("SDL2");
    build_exe.linkSystemLibrary("SDL2");
    play_exe.linkLibC();
    build_exe.linkLibC();

    b.installArtifact(play_exe);
    b.installArtifact(build_exe);
    b.installBinFile(sdl_path ++ "lib\\x64\\SDL2.dll", "SDL2.dll");

    const play_cmd = b.addRunArtifact(play_exe);
    const build_cmd = b.addRunArtifact(build_exe);

    play_cmd.step.dependOn(b.getInstallStep());
    build_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        play_cmd.addArgs(args);
        build_cmd.addArgs(args);
    }

    const play_step = b.step("play", "play fantasy console");
    const build_step = b.step("build", "build game");
    play_step.dependOn(&play_cmd.step);
    build_step.dependOn(&build_cmd.step);
}
