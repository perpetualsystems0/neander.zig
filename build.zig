const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const neander_module = b.addModule("neander", .{
        .root_source_file = b.path("src/neander.zig"),
    });

    const neander_tests = b.addTest(.{
        .root_source_file = b.path("src/neander.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("examples/example.zig"),
        .target = target,
        .optimize = optimize,
    });

    example.root_module.addImport("neander", neander_module);

    b.installArtifact(example);

    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run example Neander emulator");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run module tests");
    test_step.dependOn(&b.addRunArtifact(neander_tests).step);
}
