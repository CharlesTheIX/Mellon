const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const pg_dep = b.dependency("pg", .{ .target = target, .optimize = optimize });
    const raylib_dep = b.dependency("raylib_zig", .{ .target = target, .optimize = optimize });

    const pg = pg_dep.module("pg");
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");
    const mod = b.addModule("mellon", .{
        .target = target,
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "pg", .module = pg },
            .{ .name = "raylib", .module = raylib },
        },
    });

    const exe = b.addExecutable(.{
        .name = "mellon",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
            .imports = &.{.{ .name = "mellon", .module = mod }},
        }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("pg", pg);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
