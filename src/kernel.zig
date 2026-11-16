const std = @import("std");
const common = @import("common.zig");
pub const panic = common.panic;
const shell = @embedFile("shell.bin");
const user = @import("user.zig");

const kernel_base = @extern([*]u8, .{ .name = "__kernel_base" });
const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

export fn kernelMain() noreturn {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);

    common.printf("\n\nHello {s}\n", .{"Kernel!"});

    writeCsr("stvec", @intFromPtr(&kernelEntry));
    // asm volatile ("unimp");

    idle_proc = createProcess(&.{});
    current_proc = idle_proc;
    _ = createProcess(shell);
    yield();

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
    const scause_ecall = 8;
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const user_pc = readCsr("sepc");

    switch (scause) {
        scause_ecall => {
            handleSyscall(tf);
            writeCsr("sepc", user_pc + 4);
        },
        else => {
            std.debug.panic("Unexpected trap scause={x}, stval={x}, user_pc={x}", .{
                scause, stval, user_pc,
            });
        },
    }
}

fn handleSyscall(f: *TrapFrame) void {
    const syscall: user.Syscall = @fromBackingInt(@intCast(f.a0));
    switch (syscall) {
        .putchar => common.printByte(@intCast(f.a1)),
        .getchar => while (true) {
            const ret = common.sbiCall(0, 0, 0, 0, 0, 0, 0, 2);
            if (ret.err >= 0) {
                f.a0 = @intCast(ret.err);
                break;
            }
            yield();
        },
        .exit => {
            common.printf("[kernel] Process {} exited with code {}\n", .{
                current_proc.pid,
                f.a1,
            });

            current_proc.state = .exited;
            yield();
        },
    }
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

    const result = ram[used_mem..][0..(used_mem + alloc_size)];
    used_mem += alloc_size;

    @memset(result, 0);

    return result;
}

const user_base = 0x1000000;
const Process = struct {
    pid: usize = 0,
    state: enum { unused, runnable, exited } = .unused,
    sp: *usize = undefined,
    page_table: [*]PageEntry = undefined,
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

export fn userEntry() callconv(.naked) void {
    const sstatus_spie: u32 = 1 << 5;
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (user_base),
          [sstatus] "r" (sstatus_spie),
    );
}

fn createProcess(image: []const u8) *Process {
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
    sp[0] = @intFromPtr(&userEntry);

    std.debug.assert(sp.len == 13);

    for (sp[1..]) |*reg| {
        reg.* = 0;
    }

    p.page_table = @ptrCast(@alignCast(allocPages(1)));

    const pages_count = @divFloor((@intFromPtr(free_ram_end) - @intFromPtr(kernel_base)), page_size);
    const pages: [*][page_size]u8 = @ptrCast(kernel_base);

    for (pages[0..pages_count]) |*paddr| {
        const flags: PageEntry = .{
            .read = true,
            .write = true,
            .execute = true,
            .user = false,
            .valid = false,
        };

        mapPage(p.page_table, @intFromPtr(paddr), @intFromPtr(paddr), flags);
    }

    var off: usize = 0;
    while (off < image.len) : (off += page_size) {
        const page = allocPages(1);
        const remaining = image.len - off;
        const copy_size = if (page_size <= remaining) page_size else remaining;
        @memcpy(page[0..copy_size], image[off..][0..copy_size]);
        mapPage(p.page_table, user_base + off, @intFromPtr(page.ptr), .{
            .read = true,
            .write = true,
            .execute = true,
            .user = true,
        });
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

    const satp = Satp.fromPageTableAddr(next.page_table);
    const satp_u32: u32 = @bitCast(satp);
    asm volatile (
        \\sfence.vma
        \\csrw satp, %[satp]
        \\sfence.vma
        \\csrw sscratch, %[sscratch]
        :
        : [satp] "r" (satp_u32),
          [sscratch] "r" (next.stack[next.stack.len..].ptr),
    );

    const prev = current_proc;
    current_proc = next;
    switchContext(&prev.sp, &next.sp);
}

// Virtual memory

const Satp = packed struct {
    reserved: u31,
    sv32: bool,

    fn fromPageTableAddr(pta: [*]PageEntry) Satp {
        return .{
            .reserved = @intCast(@intFromPtr(pta) >> 12),
            .sv32 = true,
        };
    }
};

const Vpn = packed struct(u32) {
    offset: u12,
    zero: u10,
    one: u10,
};

const PageEntry = packed struct(u32) {
    valid: bool = false,
    read: bool,
    write: bool,
    execute: bool,
    user: bool,
    other_flags: u5 = 0,
    ppn: u22 = 0,
};

fn mapPage(
    table1: [*]PageEntry,
    vaddr: usize,
    paddr: usize,
    flags: PageEntry,
) void {
    if (vaddr % page_size != 0) {
        std.debug.panic("unaliged vaddr: {}", .{vaddr});
    }

    if (paddr % page_size != 0) {
        std.debug.panic("unaliged paddr: {}", .{paddr});
    }

    const vpn: Vpn = @bitCast(vaddr);

    if (!table1[vpn.one].valid) {
        var pt_paddr: PageEntry = @bitCast(@intFromPtr(allocPages(1).ptr));
        pt_paddr.valid = true;
        pt_paddr.ppn >>= 2;
        table1[vpn.one] = pt_paddr;
    }

    const table0u32: u32 = @intCast(table1[vpn.one].ppn);
    const table0: [*]PageEntry = @ptrFromInt(table0u32 << 12);

    const paddr_as_pe: PageEntry = @bitCast((paddr / page_size) << 10);
    var new_pe = flags;
    new_pe.ppn = paddr_as_pe.ppn;
    new_pe.valid = true;

    table0[vpn.zero] = new_pe;
}
