const std = @import("std");

const test_targets = [_]std.Target.Query{
    .{}, // native
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const getopt_lib_mod = b.createModule(.{
        .root_source_file = b.path("getopt.zig"),
        .target = target,
        .optimize = optimize,
    });

    const getopt_example_exe_mod = b.createModule(.{
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "getopt",
        .root_module = getopt_lib_mod,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = getopt_example_exe_mod,
    });
    b.installArtifact(exe);

    const test_step = b.step("test", "Run tests");
    for (test_targets) |test_target| {
        const unit_tests = b.addTest(.{
            .root_module = getopt_lib_mod,
            .target = b.resolveTargetQuery(test_target),
        });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
