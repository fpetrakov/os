const std = @import("std");
const common = @import("common.zig");

const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);

    common.printf("\n\nHello {s}\n", .{"Kernel!"});
    common.panic("booted!", null, null);
    common.printf("unreachable here!\n", .{});

    while (true) asm volatile ("wfi");
}

export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, __stack_top
        \\j kernel_main
    );
}
