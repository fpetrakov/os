const user = @import("user.zig");

const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

comptime {
    @export(&start, .{ .name = "start", .section = ".text.start" });
}

fn start() callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\call %[shell]
        :
        : [stack_top] "r" (stack_top),
          [shell] "X" (&shell),
    );
}

fn shell() void {
    user.printf("hello from shell! (press 'q' to exit the process)\n", .{});

    while (true) {
        const c = user.readByte();
        user.printf("read: '{c}'\n", .{c});

        if (c == 'q') {
            user.printf("exiting...\n", .{});
            user.exit(42);
        }
    }
}
