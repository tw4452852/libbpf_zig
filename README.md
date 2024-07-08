# libbpf package for zig

This is [libbpf](https://github.com/libbpf/libbpf),
packaged for [Zig](https://ziglang.org/).

## How to use it

First, update your `build.zig.zon` with:

```
zig fetch --save https://github.com/tw4452852/libbpf_zig/archive/refs/tags/1.4.3.tar.gz
```

Next, add this snippet to your `build.zig` script:

```zig
const libbpf_dep = b.dependency("libbpf", .{
    .target = target,
    .optimize = optimize,
});
your_compilation.linkLibrary(libbpf_dep.artifact("bpf"));
```

This will add libbpf as a static library to `your_compilation`.
