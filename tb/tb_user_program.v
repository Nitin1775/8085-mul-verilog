// ============================================================================
// tb_user_program.v - RUN YOUR OWN PROGRAM on the 8085 soft core
//
// This is NOT a test. There are no PASS/FAIL checks here. This testbench
// is the processor's front panel: YOU write a program below, the testbench
// loads it into the (blank) memory, the CPU runs it, and the register
// dump at the end is yours to verify by hand.
//
// HOW TO USE:
//   1. Edit the USER PROGRAM section below: one byte per line, with the
//      assembly as a comment so you can read it back.
//   2. Run the simulation. The CPU starts at 0000h and runs your program.
//   3. Read the register dump at the end and compare it with what you
//      calculated by hand. If they match, your program ran correctly.
//
// Quick opcode reminder (this core's subset):
//   MVI r,d8 : 00RRR110  (B=06 C=0E D=16 E=1E H=26 L=2E A=3E) + data byte
//   MOV r1,r2: 01DDDSSS  (e.g. MOV A,B = 78)
//   ADD r: 80+r   ADC r: 88+r   SUB r: 90+r   ANA r: A0+r
//   XRA r: A8+r   ORA r: B0+r   CMP r: B8+r
//     (r code: B=0 C=1 D=2 E=3 H=4 L=5 A=7)
//   ADI d8: C6 + data byte
//   INR r: 00RRR100   DCR r: 00RRR101
//   LXI B: 01   LXI D: 11   LXI H: 21   (+ low byte, then high byte)
//   JMP: C3   JNZ: C2   JZ: CA   (+ low byte, then high byte)
//   MUL8: 08   MUL16: 28   NOP: 00   HLT: 76
//
// Run with Icarus:
//   iverilog -o user.vvp rtl/cpu_8085.v rtl/alu.v rtl/mul_unit.v \
//       rtl/regfile.v rtl/memory.v tb/tb_user_program.v
//   vvp user.vvp
// Run in Vivado: add this file as a simulation source, set it as the
// simulation top, and run behavioral simulation.
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module tb_user_program;

    reg  clk;
    reg  reset;
    wire [15:0] mem_addr;
    wire [7:0]  mem_din;
    wire        mem_rd;
    wire        halted;

    // ---- device under test ----
    cpu_8085 dut (
        .clk(clk), .reset(reset),
        .mem_addr(mem_addr), .mem_din(mem_din), .mem_rd(mem_rd),
        .halted(halted)
    );

    memory imem (
        .addr(mem_addr), .rd(mem_rd), .dout(mem_din),
        .din(8'h00), .wr(1'b0), .clk(clk)
    );

    // ---- 100 MHz clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- cycle counter ----
    integer cycles;
    initial cycles = 0;
    always @(posedge clk) cycles = cycles + 1;

    // ---- register dump: the result YOU verify by hand ----
    task dump_regs;
        input [8*40:1] label;
        begin
            $display("========== %0s ==========", label);
            $display("  PC=%h  IR=%h", dut.pc, dut.ir);
            $display("  A=%h  B=%h  C=%h  D=%h  E=%h  H=%h  L=%h",
                     dut.u_rf.a, dut.u_rf.b, dut.u_rf.c, dut.u_rf.d,
                     dut.u_rf.e, dut.u_rf.h, dut.u_rf.l);
            $display("  BC=%h  DE=%h  HL=%h",
                     dut.u_rf.pair_bc, dut.u_rf.pair_de, dut.u_rf.pair_hl);
            $display("  Flags: Z=%b  S=%b  P=%b  CY=%b  AC=%b",
                     dut.u_rf.fz, dut.u_rf.fs, dut.u_rf.fp,
                     dut.u_rf.fcy, dut.u_rf.fac);
            $display("========================================");
        end
    endtask

    // ---- main sequence ----
    initial begin
        // ================================================================
        //  USER PROGRAM: EDIT HERE
        //  Write YOUR program below, one byte per line, with the assembly
        //  as a comment. The CPU starts at 0000h and runs it top to bottom.
        //  End your program with HLT (76h), or the CPU will slide through
        //  NOPs and the watchdog below will stop it.
        //
        //  Default example (already filled in - replace it with yours):
        //    MVI A,A2h / MVI B,10h / MUL8 / HLT
        //    -> HL should be 0A20h (A2h x 10h = 162 x 16 = 2592 = 0A20h)
        // ================================================================
        // The #1 lets memory's own zeroing initial block finish first.
        #1;
        imem.mem[16'h0000] = 8'h3E; imem.mem[16'h0001] = 8'hA2; // MVI A,A2h
        imem.mem[16'h0002] = 8'h06; imem.mem[16'h0003] = 8'h10; // MVI B,10h
        imem.mem[16'h0004] = 8'h08;                            // MUL8 -> HL = A*B
        imem.mem[16'h0005] = 8'h76;                            // HLT
        // ================================================================
        //  END OF USER PROGRAM
        // ================================================================

        // hold reset for a few clocks, then let the CPU run your program
        reset = 1'b1;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        $display("");
        $display("Running your program from 0000h ...");

        // wait until your program halts, then show the result
        wait (halted == 1'b1);
        repeat (2) @(posedge clk);
        $display("CPU halted after %0d clock cycles.", cycles);
        dump_regs("FINAL REGISTERS - CHECK THESE BY HAND");
        $display("Compare the registers above with your hand calculation.");
        $display("If they match, your program ran correctly.");
        $finish;
    end

    // ---- watchdog: never hang forever if HLT is missing ----
    initial begin
        #1000000;   // 100,000 cycles - far more than any short program needs
        $display("TIMEOUT: CPU did not halt after 100000 cycles.");
        $display("Did you forget HLT (76h) at the end of your program?");
        dump_regs("REGISTERS AT TIMEOUT");
        $finish;
    end

endmodule
