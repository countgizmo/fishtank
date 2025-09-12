const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "fishtank",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });


    b.installDirectory(.{
        .source_dir = b.path("resources"),
        .install_dir = .prefix,
        .install_subdir = "resources",
    });

    exe.root_module.addIncludePath(b.path("libs/raylib/src"));
    exe.root_module.linkLibrary(raylib_dep.artifact("raylib"));

    b.installArtifact(exe);
}
