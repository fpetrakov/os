const std = @import("std");

extern var __bss: u8;
extern var __bss_end: u8;
extern const __stack_top: u8;

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

fn putChar(ch: u8) void {
    _ = sbiCall(ch, 0, 0, 0, 0, 0, 0, 1);
}

export fn kernel_main() noreturn {
    const bss_start: [*]u8 = @ptrCast(&__bss);
    const bss_len = @intFromPtr(&__bss_end) - @intFromPtr(&__bss);
    @memset(bss_start[0..bss_len], 0);

    const s = "\n\nHello World!\n";
    for (s) |ch| {
        putChar(ch);
    }

    while (true) {
        asm volatile ("wfi");
    }
}

export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, __stack_top
        \\j kernel_main
    );
}
