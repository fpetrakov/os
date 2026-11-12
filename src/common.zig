const std = @import("std");

const SbiRet = struct {
    err: isize,
    value: isize,
};

fn sbiCall(
    arg0: isize,
    arg1: isize,
    arg2: isize,
    arg3: isize,
    arg4: isize,
    arg5: isize,
    fid: isize,
    eid: isize,
) SbiRet {
    var err: isize = undefined;
    var value: isize = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [fid] "{a6}" (fid),
          [eid] "{a7}" (eid),
        : .{ .memory = true });

    return .{ .err = err, .value = value };
}

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    writer.print("PANIC: {s}\n", .{msg}) catch {};
    while (true) asm volatile ("");
}

fn putChar(ch: u8) void {
    _ = sbiCall(ch, 0, 0, 0, 0, 0, 0, 1);
}

fn drain(_: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    var n: usize = 0;
    for (data[0 .. data.len - 1]) |bytes| {
        for (bytes) |b| putChar(b);
        n += bytes.len;
    }
    const pattern = data[data.len - 1];
    for (0..splat) |_| {
        for (pattern) |b| putChar(b);
    }
    return n + pattern.len * splat;
}

var writer: std.Io.Writer = .{
    .vtable = &.{ .drain = drain },
    .buffer = &.{},
};

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch unreachable;
}
