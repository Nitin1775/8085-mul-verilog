// ============================================================================
// top_8085.v - top level for SYNTHESIS / IMPLEMENTATION in Vivado
//
// Wraps the CPU core and its program memory into one block with a tiny
// pin list. Set THIS as the top module for synthesis runs:
//
//   | Config            | How                                  |
//   |-------------------|--------------------------------------|
//   | With MUL8 / MUL16 | USE_MUL = 1 (default in mul_unit.v)  |
//   | Baseline 8085     | USE_MUL = 0 (multipliers trimmed away)|
//
// The two utilization reports give you the "hardware cost of the novelty"
// table for the paper.
//
// (For behavioral simulation keep using tb/tb_8085.v as the top instead.)
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module top_8085 (
    input  wire clk,
    input  wire reset,      // synchronous, active high
    output wire halted      // goes high when the CPU executes HLT
);

    wire [15:0] mem_addr;
    wire [7:0]  mem_din;
    wire        mem_rd;

    cpu_8085 u_cpu (
        .clk      (clk),
        .reset    (reset),
        .mem_addr (mem_addr),
        .mem_din  (mem_din),
        .mem_rd   (mem_rd),
        .halted   (halted)
    );

    memory u_mem (
        .addr (mem_addr),
        .rd   (mem_rd),
        .dout (mem_din),
        .din  (8'h00),
        .wr   (1'b0),
        .clk  (clk)
    );

endmodule
