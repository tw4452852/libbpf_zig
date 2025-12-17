const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});
    const libz_dep = b.dependency("libz", .{
        .target = target,
        .optimize = optimize,
    });
    const libelf_dep = b.dependency("libelf", .{
        .target = target,
        .optimize = optimize,
    });

    const libbpf = b.addLibrary(.{
        .name = "bpf",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = .off, // offsetofend macro in libbpf will trigger ubsan...
        }),
        .linkage = .static,
    });

    const cflags = [_][]const u8{
        "-D_LARGEFILE64_SOURCE",
        "-D_FILE_OFFSET_BITS=64",
    };
    libbpf.root_module.addCSourceFiles(.{
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
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include",
    } });
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include/uapi",
    } });
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "src",
    } });
    libbpf.root_module.linkLibrary(libz_dep.artifact("z"));
    libbpf.root_module.linkLibrary(libelf_dep.artifact("elf"));

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

    // testing
    const prog = b.addObject(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.bpf.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .bpfel,
                .os_tag = .freestanding,
            }),
            .optimize = .ReleaseFast, // some assertions in debug mode are blocked by bpf verifier
            .strip = false, // Otherwise BTF sections will be stripped
        }),
    });

    const options = b.addOptions();
    options.addOptionPath("path", prog.getEmittedBin());
    const exe_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe_test.root_module.addOptions("@bpf_prog", options);
    exe_test.root_module.linkLibrary(libbpf);

    const test_step = b.step("test", "Build and run all unit tests");
    exe_test.setExecCmd(&.{ "sudo", null });
    const run_unit_test = b.addRunArtifact(exe_test);
    test_step.dependOn(&run_unit_test.step);
}
