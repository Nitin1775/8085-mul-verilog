// ============================================================================
// alu.v - 8-bit ALU for the 8085-compatible soft core
//
// Operations : ADD, ADC, SUB, ANA, XRA, ORA, CMP, INR, DCR
// Flags      : Z (zero), S (sign), P (parity), CY (carry), AC (aux carry)
//              flag behaviour follows the original Intel 8085.
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module alu (
    input  wire [7:0] a,        // first operand  (usually accumulator)
    input  wire [7:0] b,        // second operand (register or immediate)
    input  wire [3:0] op,       // operation select (see localparams)
    input  wire       cin,      // carry in, used only by ADC
    output reg  [7:0] result,
    output reg        z,        // zero flag
    output reg        s,        // sign flag  (copy of result[7])
    output reg        p,        // parity flag (1 = even parity)
    output reg        cy,       // carry / borrow flag
    output reg        ac        // auxiliary carry (carry out of bit 3)
);

    // internal operation codes (these are NOT 8085 opcodes)
    localparam OP_ADD = 4'd0,
               OP_ADC = 4'd1,
               OP_SUB = 4'd2,
               OP_ANA = 4'd3,
               OP_XRA = 4'd4,
               OP_ORA = 4'd5,
               OP_CMP = 4'd6,   // same datapath as SUB, result discarded by CPU
               OP_INR = 4'd7,
               OP_DCR = 4'd8;

    reg [8:0] wide;             // 9-bit temp to catch carry / borrow
    /* verilator lint_off UNUSEDSIGNAL */
    // Lint waiver: only nibble[4] is read (as aux-carry out). nibble[3:0]
    // are computed as part of the 5-bit low-nibble sum and discarded by
    // design; they are not a missing connection.
    reg [4:0] nibble;           // low-nibble temp to catch aux carry
    /* verilator lint_on UNUSEDSIGNAL */

    // even parity: returns 1 if the byte has an even number of 1 bits
    function parity_even;
        input [7:0] v;
        begin
            parity_even = ~(^v);
        end
    endfunction

    always @(*) begin
        // defaults so we never infer latches
        wide   = 9'd0;
        nibble = 5'd0;
        result = 8'd0;
        cy     = 1'b0;
        ac     = 1'b0;

        case (op)
            OP_ADD, OP_ADC: begin
                // Width fix (was WIDTHEXPAND): the carry term is now
                // explicitly 9 bits / 5 bits, matching wide / nibble.
                // Functionally identical to before (Verilator zero-extended
                // the 1-bit term); this only makes the width explicit.
                wide   = {1'b0, a} + {1'b0, b} + ((op == OP_ADC) ? {8'b0, cin} : 9'b0);
                nibble = {1'b0, a[3:0]} + {1'b0, b[3:0]} + ((op == OP_ADC) ? {4'b0, cin} : 5'b0);
                result = wide[7:0];
                cy     = wide[8];
                ac     = nibble[4];
            end

            OP_SUB, OP_CMP: begin
                wide   = {1'b0, a} - {1'b0, b};
                nibble = {1'b0, a[3:0]} - {1'b0, b[3:0]};
                result = wide[7:0];
                cy     = wide[8];       // 1 = borrow happened (8085 convention)
                ac     = nibble[4];
            end

            OP_ANA: begin
                result = a & b;
                cy     = 1'b0;
                ac     = 1'b1;           // 8085 quirk: ANA always sets AC
            end

            OP_XRA: begin
                result = a ^ b;
                cy     = 1'b0;
                ac     = 1'b0;
            end

            OP_ORA: begin
                result = a | b;
                cy     = 1'b0;
                ac     = 1'b0;
            end

            OP_INR: begin
                wide   = {1'b0, a} + 9'd1;
                nibble = {1'b0, a[3:0]} + 5'd1;
                result = wide[7:0];
                cy     = wide[8];        // computed but ignored by CPU (8085 keeps CY)
                ac     = nibble[4];
            end

            OP_DCR: begin
                wide   = {1'b0, a} - 9'd1;
                nibble = {1'b0, a[3:0]} - 5'd1;
                result = wide[7:0];
                cy     = wide[8];
                ac     = nibble[4];
            end

            default: begin
                result = 8'd0;
            end
        endcase

        // flags common to every operation
        z = (result == 8'd0);
        s = result[7];
        p = parity_even(result);
    end

endmodule
