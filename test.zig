const std = @import("std");
const print = std.debug.print;
const libbpf = @cImport({
    @cInclude("libbpf.h");
});

test {
    const path = try std.testing.allocator.dupeZ(u8, @import("@bpf_prog").path);
    defer std.testing.allocator.free(path);
    const obj = libbpf.bpf_object__open(path);
    if (obj == null) {
        print("failed to open bpf object: {}\n", .{std.posix.errno(-1)});
        return error.OPEN;
    }
    defer libbpf.bpf_object__close(obj);

    const ret = libbpf.bpf_object__load(obj);
    if (ret != 0) {
        print("failed to load bpf object: {}\n", .{std.posix.errno(-1)});
        return error.LOAD;
    }
}
