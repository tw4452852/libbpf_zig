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
        .root = upstream.path(""),
        .files = &.{
            "src/bpf.c",
            "src/btf.c",
            "src/libbpf.c",
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
            "src/features.c",
            "src/btf_iter.c",
            "src/btf_relocate.c",
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

    libbpf.installHeadersDirectory(upstream.path("src"), "", .{
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
    libbpf.installHeadersDirectory(upstream.path("include/uapi/linux"), "linux", .{
        .include_extensions = &.{
            "bpf.h",
            "bpf_common.h",
            "btf.h",
        },
    });
    b.installArtifact(libbpf);
}
