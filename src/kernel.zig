const std = @import("std");
const common = @import("common.zig");

extern var __bss: u8;
extern var __bss_end: u8;
extern const __stack_top: u8;

export fn kernel_main() noreturn {
    const bss_start: [*]u8 = @ptrCast(&__bss);
    const bss_len = @intFromPtr(&__bss_end) - @intFromPtr(&__bss);
    @memset(bss_start[0..bss_len], 0);

    common.printf("\n\nHello {s}\n", .{"World!"});

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
