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

    b.installArtifact(play_exe);
    b.installArtifact(build_exe);

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
