const std = @import("std");
const testing = std.testing;

pub const Context = struct {
    cpu: CPU = CPU{},
    mem: Memory = undefined,
};

pub const CPU = struct {
    pc: i8 = 0,
    acc: i8 = 0,
    mdr: i8 = 0,
    mar: i8 = 0,
    ir: i8 = 0,
    z: bool = false,
    n: bool = false,

    const Log = std.log.scoped(.NeanderCPU);

    pub const Error = error{
        FetchMemOverflow,
        ExecuteUnknownInstruction,
        ExecuteInstructionHLT,
    };

    pub const Instruction = struct {
        pub const NOP: i8 = @bitCast(@as(u8, 0x00));
        pub const STA: i8 = @bitCast(@as(u8, 0x10));
        pub const LDA: i8 = @bitCast(@as(u8, 0x20));
        pub const ADD: i8 = @bitCast(@as(u8, 0x30));
        pub const JMP: i8 = @bitCast(@as(u8, 0x80));
        pub const HLT: i8 = @bitCast(@as(u8, 0xf0));
    };

    pub fn reset(self: *Context) void {
        self.pc = 0;
        self.acc = 0;
        self.mdr = 0;
        self.ir = 0;
        self.z = false;
        self.n = false;
    }

    pub fn cycle(self: *Context) !void {
        try fetch(self);
        decode(self);
        try execute(self);
    }

    fn read(self: *Context) void {
        self.cpu.mdr = self.mem[@as(u8, @bitCast(self.cpu.mar))];
    }

    fn write(self: *Context) void {
        self.mem[@as(u8, @bitCast(self.cpu.mar))] = self.cpu.mdr;
    }

    fn fetch(self: *Context) !void {
        // Log.debug("fetch(): cpu.pc: 0x{x:0>2}", .{@as(u8, @bitCast(self.cpu.pc))});

        if (self.cpu.pc == self.mem.len - 1) return Error.FetchMemOverflow;

        self.cpu.mar = self.cpu.pc;
        self.cpu.pc +%= 1;
        read(self);

        // Log.debug("fetch(): cpu.mdr: 0x{x:0>2}", .{@as(u8, @bitCast(self.cpu.mdr))});
    }

    fn decode(self: *Context) void {
        self.cpu.ir = self.cpu.mdr;
        // Log.debug("decode(): cpu.ir: 0x{x:0>2}", .{@as(u8, @bitCast(self.cpu.ir))});
    }

    fn execute(self: *Context) !void {
        switch (self.cpu.ir) {
            Instruction.NOP => try instructionNOP(self),
            Instruction.STA => try instructionSTA(self),
            Instruction.LDA => try instructionLDA(self),
            Instruction.ADD => try instructionADD(self),
            Instruction.JMP => try instructionJMP(self),
            Instruction.HLT => try instructionHLT(self),
            else => return Error.ExecuteUnknownInstruction,
        }
    }

    fn instructionNOP(self: *Context) !void {
        Log.debug("instructionNOP()", .{});

        _ = self;
    }

    fn instructionSTA(self: *Context) !void {
        Log.debug("instructionSTA()", .{});

        try fetch(self);
        self.cpu.mar = self.cpu.mdr;
        self.cpu.mdr = self.cpu.acc;
        write(self);
    }

    fn instructionLDA(self: *Context) !void {
        Log.debug("instructionLDA()", .{});

        try fetch(self);
        self.cpu.mar = self.cpu.mdr;

        read(self);
        self.cpu.acc = self.cpu.mdr;

        setZ(self);
        setN(self);
    }

    fn instructionADD(self: *Context) !void {
        Log.debug("instructionADD()", .{});

        try fetch(self);
        self.cpu.mar = self.cpu.mdr;

        read(self);
        self.cpu.acc +%= self.cpu.mdr;
        setZ(self);
        setN(self);
    }

    fn instructionSUB(self: *Context) !void {
        Log.debug("instructionADD()", .{});

        try fetch(self);
        self.cpu.acc -%= self.cpu.mdr;
        setZ(self);
        setN(self);
    }

    fn instructionJMP(self: *Context) !void {
        Log.debug("instructionJMP()", .{});

        try fetch(self);
        self.cpu.pc = self.cpu.mdr;
    }

    fn instructionHLT(self: *Context) !void {
        Log.debug("instructionHLT()", .{});

        _ = self;
        return Error.ExecuteInstructionHLT;
    }

    fn setZ(self: *Context) void {
        if (self.cpu.acc == 0) self.cpu.z = true else self.cpu.z = false;
    }

    fn setN(self: *Context) void {
        if (self.cpu.acc < 0) self.cpu.n = true else self.cpu.n = false;
    }
};

const Memory = [256]i8;

// Utils
pub fn memoryDump(mem: *Memory, log_scope: type) void {
    const len = 8;
    const row_num: u8 = 256 / len;

    for (0..row_num) |i| {
        var row: [len]u8 = undefined;
        for (0..len) |j| {
            // this is a bit silly.. whatever.
            row[j] = @as(u8, @bitCast(mem[j + len * i]));
        }
        log_scope.info("[memoryDump] {x:0>2}", .{row});
    }
}

pub fn registerDump(cpu: *CPU, log_scope: type) void {
    log_scope.info("[registerDump] cpu.pc:  0x{x:0>2}", .{@as(u8, @bitCast(cpu.pc))});
    log_scope.info("[registerDump] cpu.acc: 0x{x:0>2}", .{@as(u8, @bitCast(cpu.acc))});
    log_scope.info("[registerDump] cpu.mdr: 0x{x:0>2}", .{@as(u8, @bitCast(cpu.mdr))});
    log_scope.info("[registerDump] cpu.mar: 0x{x:0>2}", .{@as(u8, @bitCast(cpu.mar))});
    log_scope.info("[registerDump] cpu.ir:  0x{x:0>2}", .{@as(u8, @bitCast(cpu.ir))});
    log_scope.info("[registerDump] cpu.z:   {}", .{cpu.z});
    log_scope.info("[registerDump] cpu.n:   {}", .{cpu.n});
}

// Tests
test "basicNoopHaltInstructionTest" {
    var neander = Context{};

    const instruction = CPU.Instruction;
    neander.mem[0] = instruction.NOP;
    neander.mem[1] = instruction.NOP;
    neander.mem[2] = instruction.NOP;
    neander.mem[3] = instruction.HLT;

    for (0..3) |_| {
        try CPU.cycle(&neander);
    }

    try testing.expectError(
        CPU.Error.ExecuteInstructionHLT,
        CPU.cycle(&neander),
    );
}

test "basicLoadStoreInstructionTest" {
    var neander = Context{};

    const instruction = CPU.Instruction;
    neander.mem[0] = instruction.LDA;
    neander.mem[1] = 0x08;
    neander.mem[2] = instruction.STA;
    neander.mem[3] = 0x09;

    neander.mem[8] = 1;
    neander.mem[9] = 0;

    for (0..2) |_| {
        try CPU.cycle(&neander);
    }

    try testing.expect(neander.mem[9] == 1);
}
