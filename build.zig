const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_add = std.Target.riscv.featureSet(&.{.m}), // rv32im
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = target,
            .optimize = .small,
            .strip = false,
        }),
    });
    kernel.entry = .disabled;
    kernel.setLinkerScript(b.path("src/kernel.ld"));
    b.installArtifact(kernel);

    const shell = b.addExecutable(.{
        .name = "shell.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/shell.zig"),
            .target = target,
            .optimize = .small,
            .strip = false,
        }),
    });
    shell.entry = .disabled;
    shell.setLinkerScript(b.path("src/user.ld"));
    b.installArtifact(shell);

    const elf2bin = b.addSystemCommand(&.{
        "llvm-objcopy",
        "--set-section-flags",
        ".bss=alloc,contents",
        "-O",
        "binary",
    });
    elf2bin.addArtifactArg(shell);
    const bin_file_name = "shell.bin";
    const bin = elf2bin.addOutputFileArg(bin_file_name);

    kernel.root_module.addAnonymousImport("shell.bin", .{
        .root_source_file = bin,
    });

    const qemu = b.addSystemCommand(&.{
        "qemu-system-riscv32",
        "-machine",
        "virt",
        "-d",
        "unimp,guest_errors,int",
        "-D",
        "qemu.log",
        "-bios",
        "default",
        "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
        "-kernel",
    });
    qemu.addArtifactArg(kernel);
    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&qemu.step);
}
