const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});
    const libz_dep = b.dependency("libz", .{
        .target = target,
        .optimize = optimize,
    });
    const elfutils_dep = b.dependency("elfutils", .{
        .target = target,
        .optimize = optimize,
    });

    const libbpf = b.addStaticLibrary(.{
        .name = "bpf",
        .target = target,
        .optimize = optimize,
    });

    const cflags = [_][]const u8{
        "-D_LARGEFILE64_SOURCE",
        "-D_FILE_OFFSET_BITS=64",
    };
    libbpf.linkLibC();
    libbpf.addCSourceFiles(.{
        .dependency = upstream,
        .files = &.{
            "src/bpf.c",
            "src/btf.c",
            "src/libbpf_errno.c",
            "src/netlink.c",
            "src/nlattr.c",
            "src/str_error.c",
            "src/libbpf_probes.c",
            "src/bpf_prog_linfo.c",
            "src/btf_dump.c",
            "src/hashmap.c",
            "src/ringbuf.c",
            "src/strset.c",
            "src/linker.c",
            "src/gen_loader.c",
            "src/relo_core.c",
            "src/usdt.c",
            "src/zip.c",
            "src/elf.c",
        },
        .flags = &cflags,
    });
    libbpf.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include",
    } });
    libbpf.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include/uapi",
    } });
    libbpf.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "src",
    } });
    libbpf.linkLibrary(libz_dep.artifact("z"));
    libbpf.linkLibrary(elfutils_dep.artifact("elf"));

    // Pass by -Dzig_wa
    const need_to_patch = if (b.option(bool, "zig_wa", "Workaround for BTF info generated by Zig")) |v| v else false;
    const libbpf_c: std.Build.LazyPath = blk: {
        if (need_to_patch) {
            const patch_cmd = b.addSystemCommand(&.{ "patch", "-p1", "-o" });
            const patched_file = patch_cmd.addOutputFileArg("libbpf_patched.c");
            patch_cmd.setStdIn(.{ .lazy_path = .{ .path = "0001-temporary-WA-for-invalid-BTF-info-generated-by-Zig.patch" } });
            patch_cmd.setCwd(.{ .dependency = .{ .dependency = upstream, .sub_path = "" } });
            patch_cmd.expectExitCode(0);
            libbpf.step.dependOn(&patch_cmd.step);
            break :blk patched_file;
        } else break :blk .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "src/libbpf.c",
        } };
    };
    libbpf.addCSourceFile(.{
        .file = libbpf_c,
        .flags = &cflags,
    });

    libbpf.installHeadersDirectoryOptions(.{
        .source_dir = upstream.path("src"),
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{
            "bpf.h",
            "libbpf.h",
            "btf.h",
            "libbpf_common.h",
            "libbpf_legacy.h",
            "bpf_helpers.h",
            "bpf_helper_defs.h",
            "bpf_tracing.h",
            "bpf_endian.h",
            "bpf_core_read.h",
            "skel_internal.h",
            "libbpf_version.h",
            "usdt.bpf.h",
        },
    });
    b.installArtifact(libbpf);
}