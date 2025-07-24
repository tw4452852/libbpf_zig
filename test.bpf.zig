const std = @import("std");
const trace_printk = std.os.linux.BPF.kern.helpers.trace_printk;

export const _license linksection("license") = "GPL".*;

export fn test_trace_printk() linksection("raw_tp/task_rename") c_long {
    const fmt = "%d";
    return trace_printk(fmt, fmt.len + 1, 0x123, 0, 0);
}
