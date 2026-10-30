// ============================================================================
// mul_unit.v - single-cycle hardware multipliers
//              *** THE NOVELTY OF THIS PROJECT ***
//
// A stock 8085 has no multiply instruction at all - you have to do it with
// a slow software loop (shift-and-add, ~hundreds of T-states).
//
// This unit adds two custom instructions built on 8085's undocumented
// opcodes (0x08 and 0x28 are NOPs on a real 8085, so old code still runs):
//
//   MUL8  (opcode 0x08) : HL = A * B              (unsigned 8x8 -> 16)
//   MUL16 (opcode 0x28) : HL = (BC * DE)[15:0]    (unsigned 16x16 -> 16)
//                         CY = 1 if the true product needs more than 16 bits
//
// Both multipliers are pure combinational logic, so each instruction
// finishes in a SINGLE execute cycle (no multi-cycle shift-add FSM).
// Synthesis infers small array multipliers from the '*' operator.
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module mul_unit #(
    parameter USE_MUL = 1   // Set to 0 to synthesize the BASELINE core without the
                            // multipliers (for the paper's area comparison table).
                            // NOTE: only change this for synthesis runs, not simulation.
) (
    // 8-bit multiplier port (for MUL8)
    input  wire [7:0]  a8,
    input  wire [7:0]  b8,
    output wire [15:0] p8,

    // 16-bit multiplier port (for MUL16)
    input  wire [15:0] a16,
    input  wire [15:0] b16,
    output wire [31:0] p16
);

    // Combinational -> single cycle. Nothing sequential here on purpose:
    // that is what makes MUL8/MUL16 "single-cycle" instructions.
    // (With USE_MUL=0 the multipliers are trimmed away by synthesis,
    //  giving you the baseline 8085 area number for comparison.)
    assign p8  = (USE_MUL == 1) ? a8 * b8   : 16'd0;
    assign p16 = (USE_MUL == 1) ? a16 * b16 : 32'd0;

endmodule
