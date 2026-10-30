// ============================================================================
// regfile.v - 8085 register file
//
// Holds the programmer-visible registers:
//   A, B, C, D, E, H, L   (8-bit each)
//   Flags: Z, S, P, CY, AC
//
// Register encoding matches the 8085 instruction format (bits [2:0] / [5:3]):
//   000=B  001=C  010=D  011=E  100=H  101=L  110=M  111=A
// (M = memory via HL is not implemented in this educational subset,
//  selecting it reads 0x00 and writes are ignored.)
//
// Also exposes BC / DE / HL as 16-bit pairs for the MUL16 instruction.
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module regfile (
    input  wire       clk,
    input  wire       reset,

    // two combinational read ports
    input  wire [2:0] raddr1,
    output wire [7:0] rdata1,
    input  wire [2:0] raddr2,
    output wire [7:0] rdata2,

    // single synchronous write port (8-bit registers)
    input  wire       we,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata,

    // 16-bit pair access (used by LXI and MUL16)
    output wire [15:0] pair_bc,
    output wire [15:0] pair_de,
    output wire [15:0] pair_hl,
    input  wire        bc_we,
    input  wire [15:0] bc_wdata,
    input  wire        de_we,
    input  wire [15:0] de_wdata,
    input  wire        hl_we,
    input  wire [15:0] hl_wdata,

    // accumulator shortcut (ALU input)
    output wire [7:0] acc,

    // flags
    input  wire flag_we,
    input  wire fz_in, fs_in, fp_in, fcy_in, fac_in,
    output wire fz, fs, fp, fcy, fac
);

    reg [7:0] b, c, d, e, h, l, a;
    reg       fz_r, fs_r, fp_r, fcy_r, fac_r;

    // ---- read port 1 ----
    reg [7:0] r1;
    always @(*) begin
        case (raddr1)
            3'b000:  r1 = b;
            3'b001:  r1 = c;
            3'b010:  r1 = d;
            3'b011:  r1 = e;
            3'b100:  r1 = h;
            3'b101:  r1 = l;
            3'b111:  r1 = a;
            default: r1 = 8'h00;   // 3'b110 = M, not implemented here
        endcase
    end
    assign rdata1 = r1;

    // ---- read port 2 ----
    reg [7:0] r2;
    always @(*) begin
        case (raddr2)
            3'b000:  r2 = b;
            3'b001:  r2 = c;
            3'b010:  r2 = d;
            3'b011:  r2 = e;
            3'b100:  r2 = h;
            3'b101:  r2 = l;
            3'b111:  r2 = a;
            default: r2 = 8'h00;
        endcase
    end
    assign rdata2 = r2;

    assign pair_bc = {b, c};
    assign pair_de = {d, e};
    assign pair_hl = {h, l};
    assign acc     = a;

    assign fz  = fz_r;
    assign fs  = fs_r;
    assign fp  = fp_r;
    assign fcy = fcy_r;
    assign fac = fac_r;

    // ---- synchronous writes ----
    always @(posedge clk) begin
        if (reset) begin
            a <= 8'd0; b <= 8'd0; c <= 8'd0; d <= 8'd0;
            e <= 8'd0; h <= 8'd0; l <= 8'd0;
            fz_r <= 1'b0; fs_r <= 1'b0; fp_r <= 1'b0;
            fcy_r <= 1'b0; fac_r <= 1'b0;
        end else begin
            if (we) begin
                case (waddr)
                    3'b000:  b <= wdata;
                    3'b001:  c <= wdata;
                    3'b010:  d <= wdata;
                    3'b011:  e <= wdata;
                    3'b100:  h <= wdata;
                    3'b101:  l <= wdata;
                    3'b111:  a <= wdata;
                    default: ;            // M write ignored (no memory ref yet)
                endcase
            end
            if (bc_we) {b, c} <= bc_wdata;
            if (de_we) {d, e} <= de_wdata;
            if (hl_we) {h, l} <= hl_wdata;

            if (flag_we) begin
                fz_r  <= fz_in;
                fs_r  <= fs_in;
                fp_r  <= fp_in;
                fcy_r <= fcy_in;
                fac_r <= fac_in;
            end
        end
    end

endmodule
