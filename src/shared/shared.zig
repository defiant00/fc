const std = @import("std");

pub const Color = @import("Color.zig");
pub const graphics = @embedFile("graphics.g16");

pub const release = std.SemanticVersion{ .major = 2023, .minor = 12, .patch = 1 };
