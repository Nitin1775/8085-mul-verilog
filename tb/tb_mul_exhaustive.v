// ============================================================================
// tb_mul_exhaustive.v - exhaustive / sampled verification of mul_unit
//
// Why unit-level, not a CPU program loop:
//   The CPU's S_MUL state is just  HL <= prod8  (MUL8)  or
//   HL <= prod32[15:0], CY <= |prod32[31:16]  (MUL16).
//   The existing tb_8085_full.v already proves that CPU integration for
//   sample values (MUL8 12H x 10H = 0120H, MUL16 3412H x 5678H = 7470H, CY=1).
//   What was NOT proved before was the multiplier itself for every input.
//   This testbench proves the multiplier itself, directly:
//
//   MUL8  : EVERY combination a=0..255, b=0..255  (65,536 cases, exhaustive)
//   MUL16 : edge cases + 10,000 fixed-seed pseudo-random cases
//           (full 2^32 x 2^32 exhaustive is impossible; edges + random
//            sampling is the honest claim, and it is stated as such)
//
// Run in Icarus : iverilog -o mul_ex.vvp rtl/mul_unit.v tb/tb_mul_exhaustive.v
//                 && vvp mul_ex.vvp
// Run in Vivado : set as sim top, Run Behavioral Simulation.
// Author : B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module tb_mul_exhaustive;

    reg  [7:0]  a8, b8;
    wire [15:0] p8;
    reg  [15:0] a16, b16;
    wire [31:0] p16;

    mul_unit dut (
        .a8(a8), .b8(b8), .p8(p8),
        .a16(a16), .b16(b16), .p16(p16)
    );

    integer i, j, k;
    integer nfail8, npass8;
    integer nfail16, npass16;
    reg [15:0] exp8;
    reg [31:0] exp16;
    reg [15:0] rnd_a, rnd_b;
    integer seed;

    initial begin
        nfail8 = 0; npass8 = 0;
        nfail16 = 0; npass16 = 0;

        // ---------- MUL8 exhaustive ----------
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a8 = i[7:0]; b8 = j[7:0];
                #1;
                exp8 = a8 * b8;
                if (j == 0 && (i % 64) == 0) $display("  MUL8 progress: a=%0d/255", i);
                if (p8 !== exp8) begin
                    if (nfail8 < 10)
                        $display("  FAIL MUL8: %h x %h -> got %h, expected %h",
                                 a8, b8, p8, exp8);
                    nfail8 = nfail8 + 1;
                end else begin
                    npass8 = npass8 + 1;
                end
            end
        end
        $display("MUL8 exhaustive: %0d pass, %0d fail (of 65536)", npass8, nfail8);

        // ---------- MUL16 edges ----------
        // {0, 1, 2, 7FFF, 8000, FFFE, FFFF} x {0, 1, 2, 7FFF, 8000, FFFE, FFFF}
        // is covered by the loop below using a small edge list via case.
        for (i = 0; i < 7; i = i + 1) begin
            case (i)
                0: a16 = 16'h0000;
                1: a16 = 16'h0001;
                2: a16 = 16'h0002;
                3: a16 = 16'h7FFF;
                4: a16 = 16'h8000;
                5: a16 = 16'hFFFE;
                default: a16 = 16'hFFFF;
            endcase
            for (j = 0; j < 7; j = j + 1) begin
                case (j)
                    0: b16 = 16'h0000;
                    1: b16 = 16'h0001;
                    2: b16 = 16'h0002;
                    3: b16 = 16'h7FFF;
                    4: b16 = 16'h8000;
                    5: b16 = 16'hFFFE;
                    default: b16 = 16'hFFFF;
                endcase
                #1;
                exp16 = a16 * b16;
                if (p16 !== exp16) begin
                    $display("  FAIL MUL16 edge: %h x %h -> got %h, expected %h",
                             a16, b16, p16, exp16);
                    nfail16 = nfail16 + 1;
                end else begin
                    npass16 = npass16 + 1;
                end
                // CY rule used by the CPU: CY = 1 iff upper 16 bits are non-zero
                if ((|p16[31:16]) !== (|exp16[31:16])) begin
                    $display("  FAIL MUL16 CY: %h x %h", a16, b16);
                    nfail16 = nfail16 + 1;
                end
            end
        end

        // ---------- MUL16 fixed-seed random sampling ----------
        seed = 32'h12345678;
        for (k = 0; k < 10000; k = k + 1) begin
            rnd_a = $random(seed);
            rnd_b = $random(seed);
            a16 = rnd_a; b16 = rnd_b;
            #1;
            exp16 = a16 * b16;
            if ((k % 2000) == 0) $display("  MUL16 random progress: %0d/10000", k);
            if (p16 !== exp16) begin
                if (nfail16 < 20)
                    $display("  FAIL MUL16 rand: %h x %h -> got %h, expected %h",
                             a16, b16, p16, exp16);
                nfail16 = nfail16 + 1;
            end else begin
                npass16 = npass16 + 1;
            end
        end
        $display("MUL16 edges+random: %0d pass, %0d fail (of 10049)", npass16, nfail16);
        $display("RESULT: MUL8 %0d/65536, MUL16 %0d/10049, total fails %0d",
                 npass8, npass16, nfail8 + nfail16);
        $finish;
    end

endmodule
