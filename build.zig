const std = @import("std");

pub fn build(b: *std.Build) !void {
    const Linkage = std.Build.Step.Compile.Linkage;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(Linkage, "linkage", "The linking mode for libraries") orelse .static;
    const exe_name = "icupkg";

    const exe = std.Build.Step.Compile.create(b, .{
        .name = exe_name,
        .kind = .exe,
        .target = target,
        .optimize = optimize,
    });

    const common = b.dependency("common", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    const icuuc = common.artifact("icuuc");

    const internationalization = b.dependency("internationalization", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    const icui18n = internationalization.artifact("icui18n");

    const toolutil = b.dependency("toolutil", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    const icutu = toolutil.artifact("icutu");

    // TODO: To be continued when ICUDT can be compiled. This tool depends on ICUDT.

    // HACK This is an ugly hack
    const icuuc_root = common.builder.pathFromRoot("cpp");
    const icui18n_root = internationalization.builder.pathFromRoot("cpp");
    const icutu_root = toolutil.builder.pathFromRoot("cpp");

    exe.linkLibCpp();
    exe.linkLibrary(icuuc);
    exe.installLibraryHeaders(icuuc);
    exe.linkLibrary(icui18n);
    exe.installLibraryHeaders(icui18n);
    exe.linkLibrary(icutu);
    exe.installLibraryHeaders(icutu);

    addSourceFiles(b, exe, &.{ "-fno-exceptions", "-Icpp", "-I", icuuc_root, "-I", icui18n_root, "-I", icutu_root }) catch @panic("OOM");
    b.installArtifact(exe);
}

fn addSourceFiles(b: *std.Build, artifact: *std.Build.Step.Compile, flags: []const []const u8) !void {
    var files = std.ArrayList([]const u8).init(b.allocator);
    var sources_txt = try std.fs.cwd().openFile(b.pathFromRoot("cpp/sources.txt"), .{});
    var reader = sources_txt.reader();
    var buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |l| {
        const line = std.mem.trim(u8, l, " \t\r\n");
        try files.append(b.pathJoin(&.{ "cpp", line }));
    }

    artifact.addCSourceFiles(files.items, flags);
}
