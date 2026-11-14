const std = @import("std");
const common = @import("common.zig");
pub const panic = common.panic;

const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

export fn kernelMain() noreturn {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);

    common.printf("\n\nHello {s}\n", .{"Kernel!"});

    const paddr0 = allocPages(2);
    const paddr1 = allocPages(1);
    common.printf("alloc_pages test0: paddr0={*} ({})\n", .{ paddr0.ptr, paddr0.len });
    common.printf("alloc_pages test1: paddr1={*} ({})\n", .{ paddr1.ptr, paddr1.len });

    writeCsr("stvec", @intFromPtr(&kernelEntry));
    // asm volatile ("unimp");

    idle_proc = createProcess(undefined);
    _ = createProcess(&processA);
    _ = createProcess(&processB);
    current_proc = idle_proc;
    yield();
    panic("switched to idle process", null, null);

    while (true) asm volatile ("wfi");
}

export fn boot() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\la sp, __stack_top
        \\j kernelMain
    );
}

export fn kernelEntry() align(4) callconv(.naked) void {
    asm volatile (
        \\csrrw sp, sscratch, sp
        \\
        \\addi sp, sp, -4 * 31
        \\sw ra, 4 * 0(sp)
        \\sw gp, 4 * 1(sp)
        \\sw tp, 4 * 2(sp)
        \\sw t0, 4 * 3(sp)
        \\sw t1, 4 * 4(sp)
        \\sw t2, 4 * 5(sp)
        \\sw t3, 4 * 6(sp)
        \\sw t4, 4 * 7(sp)
        \\sw t5, 4 * 8(sp)
        \\sw t6, 4 * 9(sp)
        \\sw a0, 4 * 10(sp)
        \\sw a1, 4 * 11(sp)
        \\sw a2, 4 * 12(sp)
        \\sw a3, 4 * 13(sp)
        \\sw a4, 4 * 14(sp)
        \\sw a5, 4 * 15(sp)
        \\sw a6, 4 * 16(sp)
        \\sw a7, 4 * 17(sp)
        \\sw s0, 4 * 18(sp)
        \\sw s1, 4 * 19(sp)
        \\sw s2, 4 * 20(sp)
        \\sw s3, 4 * 21(sp)
        \\sw s4, 4 * 22(sp)
        \\sw s5, 4 * 23(sp)
        \\sw s6, 4 * 24(sp)
        \\sw s7, 4 * 25(sp)
        \\sw s8, 4 * 26(sp)
        \\sw s9, 4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)
        \\
        \\addi a0, sp, 4 * 31
        \\sw a0, -4(a0)
        \\
        // Retrieve and save the sp at the time of exception.
        \\csrr a0, sscratch
        \\sw a0,  4 * 30(sp)
        // Reset the kernel stack.
        \\addi a0, sp, 4 * 31
        \\csrw sscratch, a0
        \\
        \\mv a0, sp
        \\call handleTrap
        \\
        \\lw ra, 4 * 0(sp)
        \\lw gp, 4 * 1(sp)
        \\lw tp, 4 * 2(sp)
        \\lw t0, 4 * 3(sp)
        \\lw t1, 4 * 4(sp)
        \\lw t2, 4 * 5(sp)
        \\lw t3, 4 * 6(sp)
        \\lw t4, 4 * 7(sp)
        \\lw t5, 4 * 8(sp)
        \\lw t6, 4 * 9(sp)
        \\lw a0, 4 * 10(sp)
        \\lw a1, 4 * 11(sp)
        \\lw a2, 4 * 12(sp)
        \\lw a3, 4 * 13(sp)
        \\lw a4, 4 * 14(sp)
        \\lw a5, 4 * 15(sp)
        \\lw a6, 4 * 16(sp)
        \\lw a7, 4 * 17(sp)
        \\lw s0, 4 * 18(sp)
        \\lw s1, 4 * 19(sp)
        \\lw s2, 4 * 20(sp)
        \\lw s3, 4 * 21(sp)
        \\lw s4, 4 * 22(sp)
        \\lw s5, 4 * 23(sp)
        \\lw s6, 4 * 24(sp)
        \\lw s7, 4 * 25(sp)
        \\lw s8, 4 * 26(sp)
        \\lw s9, 4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp, 4 * 30(sp)
        \\sret
    );
}

const TrapFrame = extern struct {
    ra: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s0: usize,
    s1: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    sp: usize,
};

export fn handleTrap(tf: *TrapFrame) void {
    _ = tf;
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const user_pc = readCsr("sepc");

    std.debug.panic("Unexpected trap scause={x}, stval={x}, user_pc={x}", .{
        scause, stval, user_pc,
    });
}

fn readCsr(comptime reg: []const u8) usize {
    return asm ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> usize),
    );
}

fn writeCsr(comptime reg: []const u8, val: usize) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (val),
    );
}

const page_size = 4096;
const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });

var used_mem: usize = 0;
fn allocPages(pages: u32) []u8 {
    const ram = free_ram[0 .. @intFromPtr(free_ram_end) - @intFromPtr(free_ram)];
    const alloc_size = pages * page_size;

    if (used_mem + alloc_size > ram.len) {
        @panic("out of memory");
    }

    const result = ram[used_mem..(used_mem + alloc_size)];
    used_mem += alloc_size;

    @memset(result, 0);

    return result;
}

const Process = struct {
    pid: usize = 0,
    state: enum { unused, runnable } = .unused,
    sp: *usize = undefined,
    stack: [8192]u8 align(4) = undefined,
};
const procs_max = 8;
var procs: [procs_max]Process = @splat(Process{});

noinline fn switchContext(prev_sp: **usize, next_sp: **usize) align(4) callconv(.c) void {
    asm volatile (
        \\addi sp, sp, -13 * 4
        \\sw ra,  0  * 4(sp)
        \\sw s0,  1  * 4(sp)
        \\sw s1,  2  * 4(sp)
        \\sw s2,  3  * 4(sp)
        \\sw s3,  4  * 4(sp)
        \\sw s4,  5  * 4(sp)
        \\sw s5,  6  * 4(sp)
        \\sw s6,  7  * 4(sp)
        \\sw s7,  8  * 4(sp)
        \\sw s8,  9  * 4(sp)
        \\sw s9,  10 * 4(sp)
        \\sw s10, 11 * 4(sp)
        \\sw s11, 12 * 4(sp)
        \\
        \\sw sp, (%[prev_sp])
        \\lw sp, (%[next_sp])
        \\
        \\lw ra,  0  * 4(sp)
        \\lw s0,  1  * 4(sp)
        \\lw s1,  2  * 4(sp)
        \\lw s2,  3  * 4(sp)
        \\lw s3,  4  * 4(sp)
        \\lw s4,  5  * 4(sp)
        \\lw s5,  6  * 4(sp)
        \\lw s6,  7  * 4(sp)
        \\lw s7,  8  * 4(sp)
        \\lw s8,  9  * 4(sp)
        \\lw s9,  10 * 4(sp)
        \\lw s10, 11 * 4(sp)
        \\lw s11, 12 * 4(sp)
        \\addi sp, sp, 13 * 4
        \\ret
        :
        : [prev_sp] "r" (prev_sp),
          [next_sp] "r" (next_sp),
    );
}

fn createProcess(pc: *const anyopaque) *Process {
    const p = for (&procs, 0..) |*p, i| {
        if (p.state == .unused) {
            p.pid = i;
            break p;
        }
    } else @panic("no free process slots");

    const regs: []usize = blk: {
        const ptr: [*]usize = @ptrCast(@alignCast(&p.stack));
        break :blk ptr[0 .. p.stack.len / @sizeOf(usize)];
    };

    const sp = regs[regs.len - 13 ..];
    sp[0] = @intFromPtr(pc);

    std.debug.assert(sp.len == 13);

    for (sp[1..]) |*reg| {
        reg.* = 0;
    }

    p.sp = &sp.ptr[0];
    p.state = .runnable;
    return p;
}

fn delay() void {
    for (0..3_000_000_000) |_| asm volatile ("nop");
}

export fn processA() void {
    common.printf("starting process A\n\n", .{});
    while (true) {
        common.printf("A", .{});
        yield();
        delay();
    }
}

export fn processB() void {
    common.printf("starting process B\n\n", .{});
    while (true) {
        common.printf("B", .{});
        yield();
        delay();
    }
}

var current_proc: *Process = undefined;
var idle_proc: *Process = undefined;

noinline fn yield() void {
    const start_idx = (current_proc.pid + 1) % procs.len;
    const next = for (procs[start_idx..]) |*p| {
        if (p.state == .runnable and p.pid > 0) {
            break p;
        }
    } else for (procs[0..start_idx]) |*p| {
        if (p.state == .runnable and p.pid > 0) {
            break p;
        }
    } else idle_proc;

    if (next == current_proc) return;

    asm volatile (
        \\csrw sscratch, %[sscratch]
        :
        : [sscratch] "r" (@intFromPtr(&next.stack) + next.stack.len),
    );

    const prev = current_proc;
    current_proc = next;
    switchContext(&prev.sp, &next.sp);
}
