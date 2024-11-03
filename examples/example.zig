const std = @import("std");
const neander = @import("neander");

// This sample program emulates a Neander machine that computes successive addition every second for all eternity.
// memoryDump() and registerDump() will produce very verbose output of the machine's state every cycle.
// ----
// Este programa de exemplo emula uma máquina Neander que computa adição sucessiva cada segundo por toda eternidade.
// memoryDump() e registerDump() vão produzir saída prolixa do estado da máquina cada ciclo.
pub fn main() !void {
    const Log = std.log.scoped(.main);

    // the Context struct is the main data structure housing a Neander machine.
    // it contains two objects itself, a struct housing registers and static functions (the CPU) and an array of 256 signed bytes (the memory).
    // the CPU's static functions expect a Context struct containing memory and itself for hopefully obvious reasons.
    // no values are needed for intialization, all registers and the memory are initialized to 0.
    var context = neander.Context{};

    // here we write some instructions and data directly into the context's memory.
    // this set of instructions will increment the value stored in 0x00 by 1 indefinitely.
    const instruction = neander.CPU.Instruction;
    context.mem[0x00] = instruction.LDA;
    context.mem[0x01] = 0x08;
    context.mem[0x02] = instruction.ADD;
    context.mem[0x03] = 0x09;
    context.mem[0x04] = instruction.STA;
    context.mem[0x05] = 0x08;
    context.mem[0x06] = instruction.JMP;
    context.mem[0x07] = 0x00;

    context.mem[0x08] = 0;
    context.mem[0x09] = 1;

    // a memory dump before the start of execution for completion's sake.
    neander.memoryDump(&context.mem, Log);

    // here the execution begins.
    Log.info("execution begins.", .{});
    while (true) {
        // some Zig timing stuff so the loop only repeats once every second (aka 1e+9 nanoseconds).
        // you can adjust the clock_speed value here if you wish.
        const clock_speed: u64 = 1e+9;
        const clock_start = try std.time.Instant.now();

        // cycle() is the static function that will iterate a context over one instruction cycle. this is how we "run" the processor.
        // it will load the next instruction, increment the program counter, then execute the instruction. all of it.
        // the function returns an error if the processor must stop executing, the return value determining why.
        // this includes when the processor hits a HLT instruction.
        // the CPU will never produce an error in this example (hopefully), but if it did, it would be a good idea to exit the loop.
        neander.CPU.cycle(&context) catch break;

        // we dump the registers and the memory of the context every cycle.
        neander.registerDump(&context.cpu, Log);
        neander.memoryDump(&context.mem, Log);

        // we store how long the entire ordeal took.
        const clock_time = std.time.Instant.since(
            try std.time.Instant.now(),
            clock_start,
        );
        Log.info("cycle loop done in {} nanoseconds", .{clock_time});

        // then we make sure we let a second go by before executing again.
        if (clock_time > clock_speed) {
            Log.warn("cycle loop took longer than defined clock speed", .{});
        } else {
            std.time.sleep(clock_speed - clock_time);
        }
        // now from the top!
    }
}
