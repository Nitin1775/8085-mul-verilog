// ============================================================================
// tb_8085_full.v - FULL self-checking test suite for the 8085 + MUL8/MUL16 core
//
// Covers every instruction in the educational subset:
//   MVI, MOV, LXI, ADD, ADC, SUB, ADI, ANA, XRA, ORA, CMP,
//   INR, DCR, JMP, JNZ, JZ, NOP, HLT, MUL8, MUL16
//
// Every check prints PASS/FAIL to the console (Tcl console in Vivado xsim,
// transcript in Icarus Verilog). Final line: "RESULT: n/n tests passed".
//
// Run in Vivado : set as sim top, Run Behavioral Simulation.
// Run in Icarus : iverilog -o sim.vvp rtl/*.v tb/tb_8085_full.v && vvp sim.vvp
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module tb_8085_full;

    reg  clk;
    reg  reset;
    wire [15:0] mem_addr;
    wire [7:0]  mem_din;
    wire        mem_rd;
    wire        halted;

    // ---- device under test ----
    cpu_8085 dut (
        .clk(clk),
        .reset(reset),
        .mem_addr(mem_addr),
        .mem_din(mem_din),
        .mem_rd(mem_rd),
        .halted(halted)
    );

    memory imem (
        .addr(mem_addr),
        .rd(mem_rd),
        .dout(mem_din),
        .din(8'h00),
        .wr(1'b0),
        .clk(clk)
    );

    // ---- 100 MHz clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- cycle counter (for the paper) ----
    integer cycles;
    initial cycles = 0;
    always @(posedge clk) cycles = cycles + 1;

    integer npass;
    integer nfail;
    initial begin npass = 0; nfail = 0; end

    // ---- check helpers: each prints PASS/FAIL to the console ----
    task automatic check8;
        input [8*48:1] tname;
        input [7:0]    got;
        input [7:0]    exp;
        begin
            if (got !== exp) begin
                $display("  FAIL: %0s -> got %h, expected %h", tname, got, exp);
                nfail = nfail + 1;
            end else begin
                $display("  PASS: %0s = %h", tname, got);
                npass = npass + 1;
            end
        end
    endtask

    task automatic check16;
        input [8*48:1] tname;
        input [15:0]   got;
        input [15:0]   exp;
        begin
            if (got !== exp) begin
                $display("  FAIL: %0s -> got %h, expected %h", tname, got, exp);
                nfail = nfail + 1;
            end else begin
                $display("  PASS: %0s = %h", tname, got);
                npass = npass + 1;
            end
        end
    endtask

    task automatic checkf;
        input [8*48:1] tname;
        input          got;
        input          exp;
        begin
            if (got !== exp) begin
                $display("  FAIL: flag %0s -> got %b, expected %b", tname, got, exp);
                nfail = nfail + 1;
            end else begin
                $display("  PASS: flag %0s = %b", tname, got);
                npass = npass + 1;
            end
        end
    endtask

    // ---- wait until the instruction at 'pcval' has FULLY completed ----
    // (state back to FETCH0 *and* the register file has captured the write,
    //  which lands one clock after the execute state asserts its strobes)
    task automatic at_pc;
        input [15:0] pcval;
        begin
            wait (dut.state == dut.S_FETCH0 && dut.pc == pcval);
            @(posedge clk);   // regfile captures the write on this edge
            #1;
        end
    endtask

    // ---- register dump ----
    task automatic dump_regs;
        input [8*48:1] label;
        begin
            $display("  -- %0s --  PC=%h IR=%h", label, dut.pc, dut.ir);
            $display("     A=%h B=%h C=%h D=%h E=%h H=%h L=%h",
                     dut.u_rf.a, dut.u_rf.b, dut.u_rf.c, dut.u_rf.d,
                     dut.u_rf.e, dut.u_rf.h, dut.u_rf.l);
            $display("     BC=%h DE=%h HL=%h | Z=%b S=%b P=%b CY=%b AC=%b",
                     dut.u_rf.pair_bc, dut.u_rf.pair_de, dut.u_rf.pair_hl,
                     dut.u_rf.fz, dut.u_rf.fs, dut.u_rf.fp,
                     dut.u_rf.fcy, dut.u_rf.fac);
        end
    endtask

    // ---- main test sequence ----
    initial begin
        // VCD dump is for Icarus/GTKWave only; Vivado xsim has its own viewer
        // (it defines XILINX_SIMULATOR automatically).
        `ifndef XILINX_SIMULATOR
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_8085_full);
        `endif

        // ---- load the verification program into memory ----
        // memory.v is blank by design (a real processor ships empty);
        // the program lives HERE, in the testbench, and is loaded
        // before reset is released, so the CPU fetches it from 0000h.
        // The #1 lets memory's own zeroing initial block finish first.
        #1;
        // ===== TEST 1 : MVI + MOV (0000-000F) =====
        imem.mem[16'h0000] = 8'h3E; imem.mem[16'h0001] = 8'hAA; // MVI A,AAh
        imem.mem[16'h0002] = 8'h06; imem.mem[16'h0003] = 8'h55; // MVI B,55h
        imem.mem[16'h0004] = 8'h0E; imem.mem[16'h0005] = 8'hF0; // MVI C,F0h
        imem.mem[16'h0006] = 8'h16; imem.mem[16'h0007] = 8'h0F; // MVI D,0Fh
        imem.mem[16'h0008] = 8'h1E; imem.mem[16'h0009] = 8'h33; // MVI E,33h
        imem.mem[16'h000A] = 8'h26; imem.mem[16'h000B] = 8'h12; // MVI H,12h
        imem.mem[16'h000C] = 8'h2E; imem.mem[16'h000D] = 8'h34; // MVI L,34h
        imem.mem[16'h000E] = 8'h78;                        // MOV A,B   -> A=55h
        imem.mem[16'h000F] = 8'h41;                        // MOV B,C   -> B=F0h
        // ===== TEST 2 : ADD / ADC / SUB (0010-0024) =====
        imem.mem[16'h0010] = 8'h3E; imem.mem[16'h0011] = 8'h05; // MVI A,05h
        imem.mem[16'h0012] = 8'h06; imem.mem[16'h0013] = 8'h03; // MVI B,03h
        imem.mem[16'h0014] = 8'h80;                        // ADD B     -> A=08h
        imem.mem[16'h0015] = 8'h3E; imem.mem[16'h0016] = 8'hFF; // MVI A,FFh
        imem.mem[16'h0017] = 8'h06; imem.mem[16'h0018] = 8'h01; // MVI B,01h
        imem.mem[16'h0019] = 8'h80;                        // ADD B     -> A=00h CY=1 Z=1
        imem.mem[16'h001A] = 8'h88;                        // ADC B     -> A=02h (00+01+CY)
        imem.mem[16'h001B] = 8'h3E; imem.mem[16'h001C] = 8'h0A; // MVI A,0Ah
        imem.mem[16'h001D] = 8'h06; imem.mem[16'h001E] = 8'h04; // MVI B,04h
        imem.mem[16'h001F] = 8'h90;                        // SUB B     -> A=06h
        imem.mem[16'h0020] = 8'h3E; imem.mem[16'h0021] = 8'h04; // MVI A,04h
        imem.mem[16'h0022] = 8'h06; imem.mem[16'h0023] = 8'h0A; // MVI B,0Ah
        imem.mem[16'h0024] = 8'h90;                        // SUB B     -> A=FAh CY=1
        // ===== TEST 3 : ANA / XRA / ORA / CMP (0025-0032) =====
        imem.mem[16'h0025] = 8'h3E; imem.mem[16'h0026] = 8'hF0; // MVI A,F0h
        imem.mem[16'h0027] = 8'h06; imem.mem[16'h0028] = 8'h0F; // MVI B,0Fh
        imem.mem[16'h0029] = 8'hA0;                        // ANA B     -> A=00h Z=1
        imem.mem[16'h002A] = 8'h3E; imem.mem[16'h002B] = 8'hF0; // MVI A,F0h
        imem.mem[16'h002C] = 8'hA8;                        // XRA B     -> A=FFh S=1
        imem.mem[16'h002D] = 8'h3E; imem.mem[16'h002E] = 8'hF0; // MVI A,F0h
        imem.mem[16'h002F] = 8'hB0;                        // ORA B     -> A=FFh
        imem.mem[16'h0030] = 8'h3E; imem.mem[16'h0031] = 8'h05; // MVI A,05h
        imem.mem[16'h0032] = 8'hB8;                        // CMP B     -> A stays 05h, CY=1
        // ===== TEST 4 : INR / DCR (0033-003E) =====
        imem.mem[16'h0033] = 8'h06; imem.mem[16'h0034] = 8'h00; // MVI B,00h
        imem.mem[16'h0035] = 8'h04;                        // INR B     -> 01h
        imem.mem[16'h0036] = 8'h04;                        // INR B     -> 02h
        imem.mem[16'h0037] = 8'h05;                        // DCR B     -> 01h
        imem.mem[16'h0038] = 8'h05;                        // DCR B     -> 00h Z=1
        imem.mem[16'h0039] = 8'h3E; imem.mem[16'h003A] = 8'hFF; // MVI A,FFh
        imem.mem[16'h003B] = 8'h06; imem.mem[16'h003C] = 8'h01; // MVI B,01h
        imem.mem[16'h003D] = 8'h80;                        // ADD B     -> A=00h CY=1
        imem.mem[16'h003E] = 8'h04;                        // INR B     -> B=02h, CY stays 1
        // ===== TEST 5 : LXI (003F-0047) =====
        imem.mem[16'h003F] = 8'h01; imem.mem[16'h0040] = 8'h34; imem.mem[16'h0041] = 8'h12; // LXI B,1234h
        imem.mem[16'h0042] = 8'h11; imem.mem[16'h0043] = 8'h78; imem.mem[16'h0044] = 8'h56; // LXI D,5678h
        imem.mem[16'h0045] = 8'h21; imem.mem[16'h0046] = 8'hCD; imem.mem[16'h0047] = 8'hAB; // LXI H,ABCDh
        // ===== TEST 6 : JMP / JNZ / JZ (0048-005B) =====
        imem.mem[16'h0048] = 8'hC3; imem.mem[16'h0049] = 8'h4E; imem.mem[16'h004A] = 8'h00; // JMP 004Eh
        imem.mem[16'h004B] = 8'h3E; imem.mem[16'h004C] = 8'hFF; // MVI A,FFh (skipped)
        imem.mem[16'h004D] = 8'h00;                        // NOP       (skipped)
        imem.mem[16'h004E] = 8'h06; imem.mem[16'h004F] = 8'h03; // MVI B,03h
        imem.mem[16'h0050] = 8'h05;                        // DCR B     (loop body)
        imem.mem[16'h0051] = 8'hC2; imem.mem[16'h0052] = 8'h50; imem.mem[16'h0053] = 8'h00; // JNZ 0050h
        imem.mem[16'h0054] = 8'h3E; imem.mem[16'h0055] = 8'h01; // MVI A,01h
        imem.mem[16'h0056] = 8'hCA; imem.mem[16'h0057] = 8'h5B; imem.mem[16'h0058] = 8'h00; // JZ 005Bh
        imem.mem[16'h0059] = 8'h3E; imem.mem[16'h005A] = 8'hFF; // MVI A,FFh (skipped)
        imem.mem[16'h005B] = 8'h00;                        // NOP
        // ===== TEST 7 : MUL8 / MUL16 - project novelty (005C-006A) =====
        imem.mem[16'h005C] = 8'h3E; imem.mem[16'h005D] = 8'h12; // MVI A,12h
        imem.mem[16'h005E] = 8'h06; imem.mem[16'h005F] = 8'h10; // MVI B,10h
        imem.mem[16'h0060] = 8'h08;                        // MUL8      -> HL=0120h
        imem.mem[16'h0061] = 8'h06; imem.mem[16'h0062] = 8'h34; // MVI B,34h
        imem.mem[16'h0063] = 8'h0E; imem.mem[16'h0064] = 8'h12; // MVI C,12h -> BC=3412h
        imem.mem[16'h0065] = 8'h16; imem.mem[16'h0066] = 8'h56; // MVI D,56h
        imem.mem[16'h0067] = 8'h1E; imem.mem[16'h0068] = 8'h78; // MVI E,78h -> DE=5678h
        imem.mem[16'h0069] = 8'h28;                        // MUL16     -> HL=7470h CY=1
        imem.mem[16'h006A] = 8'h76;                        // HLT

        // hold reset for a few clocks
        reset = 1'b1;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        $display("");
        $display("##################################################");
        $display("#  8085 + MUL8/MUL16  FULL TEST SUITE");
        $display("##################################################");

        // ===== TEST 1 : MVI + MOV =====
        at_pc(16'h0010);
        $display("\n[TEST 1] MVI r,d8 / MOV r,r");
        check8("A after MOV A,B", dut.u_rf.a, 8'h55);
        check8("B after MOV B,C", dut.u_rf.b, 8'hF0);
        check8("C", dut.u_rf.c, 8'hF0);
        check8("D", dut.u_rf.d, 8'h0F);
        check8("E", dut.u_rf.e, 8'h33);
        check8("H", dut.u_rf.h, 8'h12);
        check8("L", dut.u_rf.l, 8'h34);

        // ===== TEST 2 : ADD / ADC / SUB =====
        $display("\n[TEST 2] ADD / ADC / SUB + flags");
        at_pc(16'h0015);                       // after ADD B (05h+03h)
        check8("ADD 05+03 -> A", dut.u_rf.a, 8'h08);
        checkf("CY", dut.u_rf.fcy, 1'b0);
        checkf("Z",  dut.u_rf.fz,  1'b0);

        at_pc(16'h001A);                       // after ADD B (FFh+01h)
        check8("ADD FF+01 -> A", dut.u_rf.a, 8'h00);
        checkf("CY", dut.u_rf.fcy, 1'b1);
        checkf("Z",  dut.u_rf.fz,  1'b1);
        checkf("AC", dut.u_rf.fac, 1'b1);

        at_pc(16'h001B);                       // after ADC B (00+01+CY)
        check8("ADC 00+01+CY -> A", dut.u_rf.a, 8'h02);
        checkf("CY", dut.u_rf.fcy, 1'b0);

        at_pc(16'h0025);                       // after SUB B (04h-0Ah)
        check8("SUB 04-0A -> A", dut.u_rf.a, 8'hFA);
        checkf("CY (borrow)", dut.u_rf.fcy, 1'b1);
        checkf("S", dut.u_rf.fs, 1'b1);

        // ===== TEST 3 : ANA / XRA / ORA / CMP =====
        $display("\n[TEST 3] ANA / XRA / ORA / CMP");
        at_pc(16'h002A);                       // after ANA B (F0h & 0Fh)
        check8("ANA F0&0F -> A", dut.u_rf.a, 8'h00);
        checkf("Z",  dut.u_rf.fz,  1'b1);
        checkf("CY", dut.u_rf.fcy, 1'b0);

        at_pc(16'h002D);                       // after XRA B (F0h ^ 0Fh)
        check8("XRA F0^0F -> A", dut.u_rf.a, 8'hFF);
        checkf("S", dut.u_rf.fs, 1'b1);
        checkf("Z", dut.u_rf.fz, 1'b0);

        at_pc(16'h0030);                       // after ORA B (F0h | 0Fh)
        check8("ORA F0|0F -> A", dut.u_rf.a, 8'hFF);

        at_pc(16'h0033);                       // after CMP B (05h vs 0Fh)
        check8("CMP: A unchanged", dut.u_rf.a, 8'h05);
        checkf("CY (A<B)", dut.u_rf.fcy, 1'b1);
        checkf("Z", dut.u_rf.fz, 1'b0);

        // ===== TEST 4 : INR / DCR =====
        $display("\n[TEST 4] INR / DCR (+ CY preservation)");
        at_pc(16'h0039);                       // after DCR B -> 00h
        check8("B after INR/INR/DCR/DCR", dut.u_rf.b, 8'h00);
        checkf("Z", dut.u_rf.fz, 1'b1);

        at_pc(16'h003F);                       // after INR B (CY was 1)
        check8("B after INR", dut.u_rf.b, 8'h02);
        checkf("CY preserved by INR", dut.u_rf.fcy, 1'b1);

        // ===== TEST 5 : LXI =====
        $display("\n[TEST 5] LXI rp,d16");
        at_pc(16'h0048);
        check16("BC", dut.u_rf.pair_bc, 16'h1234);
        check16("DE", dut.u_rf.pair_de, 16'h5678);
        check16("HL", dut.u_rf.pair_hl, 16'hABCD);

        // ===== TEST 6 : JMP / JNZ / JZ =====
        $display("\n[TEST 6] JMP / JNZ / JZ");
        at_pc(16'h005C);
        check8("B after JNZ loop", dut.u_rf.b, 8'h00);
        checkf("Z after loop", dut.u_rf.fz, 1'b1);
        check8("A (MVI A,FF skipped by JZ)", dut.u_rf.a, 8'h01);

        // ===== TEST 7 : MUL8 / MUL16 (novelty) =====
        $display("\n[TEST 7] MUL8 / MUL16  *** project novelty ***");
        at_pc(16'h0061);                       // after MUL8
        check16("MUL8: HL = 12h*10h", dut.u_rf.pair_hl, 16'h0120);
        dump_regs("after MUL8");

        at_pc(16'h006A);                       // after MUL16
        check16("MUL16: HL = (3412h*5678h)[15:0]", dut.u_rf.pair_hl, 16'h7470);
        checkf("MUL16: CY (overflow)", dut.u_rf.fcy, 1'b1);
        dump_regs("after MUL16");

        // ===== finish =====
        wait (halted == 1'b1);
        repeat (2) @(posedge clk);
        $display("\nCPU halted after %0d clock cycles.", cycles);
        dump_regs("final");

        $display("");
        $display("##################################################");
        if (nfail == 0)
            $display("#  RESULT: ALL %0d TESTS PASSED", npass);
        else
            $display("#  RESULT: %0d PASSED, %0d FAILED", npass, nfail);
        $display("##################################################");
        $display("");
        $finish;
    end

    // ---- watchdog: never hang forever if something is broken ----
    initial begin
        #4000000;
        $display("TIMEOUT: CPU did not halt - check the design.");
        $finish;
    end

endmodule
