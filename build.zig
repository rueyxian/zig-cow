const std = @import("std");
const fmt = std.fmt;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_cow = b.addModule("cow", .{ .source_file = .{ .path = "src/root.zig" } });

    {
        const step_test = b.step("test", "Run unit tests");
        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = "src/root.zig" },
            .target = target,
            .optimize = optimize,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        step_test.dependOn(&run_unit_tests.step);
    }

    for ([_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "ex1", .path = "src/examples/ex1.zig" },
        .{ .name = "ex2", .path = "src/examples/ex2.zig" },
        // .{ .name = "threaded", .path = "src/examples/threaded.zig" },
    }) |opt| {
        const step_run = blk: {
            const name = try fmt.allocPrint(b.allocator, "example_{s}", .{opt.name});
            const desciption = try fmt.allocPrint(b.allocator, "Run example `{s}`", .{opt.path});
            break :blk b.step(name, desciption);
        };

        const exe = b.addExecutable(.{
            .name = opt.name,
            .root_source_file = .{ .path = opt.path },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("cow", mod_cow);

        const run_exe = b.addRunArtifact(exe);
        step_run.dependOn(&run_exe.step);
    }
}
