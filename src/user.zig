const std = @import("std");

pub const Syscall = enum(u32) {
    putchar,
    getchar,
    exit,

    pub fn zero(s: Syscall) usize {
        const id: u32 = @backingInt(s);
        return asm volatile (
            \\ecall
            : [ret] "={a0}" (-> usize),
            : [id] "{a0}" (id),
        );
    }

    pub fn one(s: Syscall, arg: u32) usize {
        const id: u32 = @backingInt(s);
        return asm volatile (
            \\ecall
            : [ret] "={a0}" (-> usize),
            : [ud] "{a0}" (id),
              [arg] "{a1}" (arg),
        );
    }
};

fn drain(_: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    var n: usize = 0;
    for (data[0 .. data.len - 1]) |bytes| {
        for (bytes) |b| _ = Syscall.one(.putchar, b);
        n += bytes.len;
    }
    const pattern = data[data.len - 1];
    for (0..splat) |_| {
        for (pattern) |b| _ = Syscall.one(.putchar, b);
    }
    return n + pattern.len * splat;
}

var console: std.Io.Writer = .{
    .vtable = &.{ .drain = drain },
    .buffer = &.{},
};

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    console.print(fmt, args) catch unreachable;
}

pub fn readByte() u8 {
    const val = Syscall.zero(.getchar);
    return @intCast(val);
}

pub fn exit(code: usize) void {
    _ = Syscall.one(.exit, code);
}
