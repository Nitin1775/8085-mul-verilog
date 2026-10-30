// ============================================================================
// memory.v - program/data memory for the 8085 soft core
//
// 4 KB, combinational read. BLANK BY DESIGN: this memory holds no fixed
// program and no predefined inputs. It is just storage, like the RAM/ROM
// chips around a real 8085 - the processor itself comes empty, and
// whoever uses it loads a program into memory first. Each testbench
// does exactly that:
//   tb_8085_full.v    loads the 7-section verification program
//   tb_8085.v         loads the same program for the MUL demo
//   tb_user_program.v loads YOUR program (you edit it there)
// An all-zero memory reads as 00h = NOP, so an empty machine simply
// slides through NOPs until a program is loaded.
// This works identically in:
//   * Icarus Verilog simulation
//   * Vivado xsim behavioral simulation
//   * Vivado synthesis  (infers zero-initialized Block RAM)
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

/* verilator lint_off UNUSEDSIGNAL */
// Lint waiver for this module only: addr[15:12] are unused because this
// is a 4 KB memory (addr[11:0] only); rd, din, wr and clk are kept for a
// realistic memory interface but unused in this subset, which has a
// combinational read and is loaded directly by the testbench. These are
// intentional interface choices, not missing connections.
module memory (
    input  wire [15:0] addr,
    input  wire        rd,          // read strobe (kept for realism)
    output wire [7:0]  dout,
    input  wire [7:0]  din,        // unused by current instruction subset
    input  wire        wr,          // unused by current instruction subset
    input  wire        clk
);

    reg [7:0] mem [0:4095];
    integer i;

    initial begin
        for (i = 0; i < 4096; i = i + 1)
            mem[i] = 8'h00;

        // No program is stored here. The memory is blank on purpose:
        // the program is loaded by the testbench (see the header).
        // Until then every location reads 00h, which is NOP.
    end

    // combinational read: like a fast ROM / SRAM with zero wait states
    assign dout = mem[addr[11:0]];

endmodule
/* verilator lint_on UNUSEDSIGNAL */
