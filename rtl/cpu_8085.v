// ============================================================================
// cpu_8085.v - 8085-compatible 8-bit soft-core CPU (educational subset)
//              with custom single-cycle MUL8 / MUL16 instructions.
//
// Datapath : PC, IR, register file, ALU, multiplier, tiny control FSM.
// Timing   : multi-cycle - every instruction is FETCH0 -> FETCH1 ->
//            (operand fetch) -> EXECUTE -> FETCH0 ...
//
// Custom instructions (the novelty of this project):
//   MUL8  opcode 0x08 : HL = A * B
//   MUL16 opcode 0x28 : HL = (BC * DE)[15:0], CY = 1 on overflow
// Both execute in ONE state (S_MUL) because mul_unit is combinational.
//
// Note: this is a teaching subset, not a cycle-accurate replica of every
// 8085 instruction. The instructions below cover all the addressing modes
// needed for the demo and the paper; the FSM is written so new opcodes
// can be added by copying one of the existing cases.
// TODO (v2): PUSH/POP/CALL/RET + stack pointer, LDA/STA, rotates.
//
// Author : 8085 Team (5 members), B.Tech Final Year Project (2026)
// ============================================================================
`timescale 1ns / 1ps

module cpu_8085 (
    input  wire        clk,
    input  wire        reset,       // synchronous, active high
    output reg  [15:0] mem_addr,   // memory address bus
    input  wire [7:0]  mem_din,    // byte read from memory
    output reg         mem_rd,      // memory read strobe
    output reg         halted       // high after HLT, stays high
);

    // ------------------------- FSM states -------------------------
    localparam S_FETCH0 = 4'd0,    // drive PC onto the address bus
               S_FETCH1 = 4'd1,    // latch opcode into IR, decode
               S_MVI_RD = 4'd2,    // MVI: fetch immediate byte
               S_MVI_WR = 4'd3,    // MVI: write it to the register
               S_IMM_RD = 4'd4,    // ADI: fetch immediate byte
               S_IMM_EX = 4'd5,    // ADI: A = A + imm8
               S_REG_EX = 4'd6,    // ADD/ADC/SUB/ANA/XRA/ORA/CMP/INR/DCR r
               S_JMP_L  = 4'd7,    // JMP/JNZ/JZ: fetch low address byte
               S_JMP_H  = 4'd8,    // ...fetch high byte, maybe load PC
               S_LXI_L  = 4'd9,    // LXI: fetch low byte
               S_LXI_H  = 4'd10,   // LXI: fetch high byte, write pair
               S_MUL    = 4'd11,   // MUL8 / MUL16 : single-cycle execute
               S_MOV    = 4'd12,   // MOV r1, r2
               S_HALT   = 4'd13;

    // ------------------------- internal registers -------------------------
    reg [3:0]  state;
    reg [15:0] pc;                 // program counter
    reg [7:0]  ir;                 // instruction register
    reg [7:0]  jmp_lo;             // scratch for 16-bit immediates

    // ------------------------- pulsed control signals ---------------------
    // (driven low by default every clock, asserted for one cycle when needed)
    reg        we;
    reg [2:0]  waddr;
    reg [7:0]  wdata;
    reg        bc_we, de_we, hl_we;
    reg [15:0] bc_wdata, de_wdata, hl_wdata;
    reg        flag_we;
    reg        fz_in, fs_in, fp_in, fcy_in, fac_in;

    // ------------------------- datapath wires -------------------------
    wire [7:0]  rf_r1, rf_r2, rf_acc;
    /* verilator lint_off UNUSEDSIGNAL */
    // Lint waiver: pair_hl, fs, fp and fac are written into the register
    // file but never read by this FSM (it only reads fz for JNZ/JZ and
    // fcy for ADC). They are kept for flag/pair completeness, not missing
    // connections; removing them would hide the full flag register.
    wire [15:0] pair_bc, pair_de, pair_hl;
    wire        fz, fs, fp, fcy, fac;
    /* verilator lint_on UNUSEDSIGNAL */

    wire [7:0]  alu_result;
    wire        alu_z, alu_s, alu_p, alu_cy, alu_ac;
    reg  [3:0]  alu_op;

    wire [15:0] prod8;
    wire [31:0] prod32;

    // INR/DCR work on the addressed register itself, not on A.
    // NOTE: for INR/DCR (00rrr100 / 00rrr101) the register lives in
    // bits [5:3], unlike ADD-style ops where it is in [2:0].
    wire is_inr_dcr = (ir[7:6] == 2'b00) &&
                      (ir[2:0] == 3'b100 || ir[2:0] == 3'b101);
    wire [2:0] rsel = is_inr_dcr ? ir[5:3] : ir[2:0];

    wire [7:0] alu_a = is_inr_dcr ? rf_r1 : rf_acc;
    wire [7:0] alu_b = (state == S_IMM_EX) ? mem_din : rf_r1;

    // ------------------------- sub-modules -------------------------
    regfile u_rf (
        .clk(clk),       .reset(reset),
        .raddr1(rsel), .rdata1(rf_r1),
        .raddr2(3'b000),  .rdata2(rf_r2),      // port 2 hardwired to B (MUL8)
        .we(we), .waddr(waddr), .wdata(wdata),
        .pair_bc(pair_bc), .pair_de(pair_de), .pair_hl(pair_hl),
        .bc_we(bc_we), .bc_wdata(bc_wdata),
        .de_we(de_we), .de_wdata(de_wdata),
        .hl_we(hl_we), .hl_wdata(hl_wdata),
        .acc(rf_acc),
        .flag_we(flag_we),
        .fz_in(fz_in), .fs_in(fs_in), .fp_in(fp_in),
        .fcy_in(fcy_in), .fac_in(fac_in),
        .fz(fz), .fs(fs), .fp(fp), .fcy(fcy), .fac(fac)
    );

    alu u_alu (
        .a(alu_a), .b(alu_b), .op(alu_op), .cin(fcy),
        .result(alu_result),
        .z(alu_z), .s(alu_s), .p(alu_p), .cy(alu_cy), .ac(alu_ac)
    );

    mul_unit u_mul (
        .a8(rf_acc), .b8(rf_r2), .p8(prod8),
        .a16(pair_bc), .b16(pair_de), .p16(prod32)
    );

    // ------------------------- ALU operation select -------------------------
    always @(*) begin
        alu_op = 4'd0;
        if (state == S_IMM_EX) begin
            alu_op = 4'd0;                          // ADI = ADD immediate
        end else if (state == S_REG_EX) begin
            if (ir[7:6] == 2'b00 && ir[2:0] == 3'b100)
                alu_op = 4'd7;                      // INR r
            else if (ir[7:6] == 2'b00 && ir[2:0] == 3'b101)
                alu_op = 4'd8;                      // DCR r
            else case (ir[5:3])
                3'b000: alu_op = 4'd0;              // ADD r
                3'b001: alu_op = 4'd1;              // ADC r
                3'b010: alu_op = 4'd2;              // SUB r
                3'b100: alu_op = 4'd3;              // ANA r
                3'b101: alu_op = 4'd4;              // XRA r
                3'b110: alu_op = 4'd5;              // ORA r
                3'b111: alu_op = 4'd6;              // CMP r
                default: alu_op = 4'd0;
            endcase
        end
    end

    // ------------------------- branch condition helper -------------------------
    function jump_taken;
        input [7:0] opcode;
        input       zero_flag;
        begin
            case (opcode)
                8'hC3:   jump_taken = 1'b1;        // JMP  : always
                8'hC2:   jump_taken = ~zero_flag; // JNZ  : jump if Z=0
                8'hCA:   jump_taken = zero_flag;  // JZ   : jump if Z=1
                default: jump_taken = 1'b0;
            endcase
        end
    endfunction

    // ------------------------- main control FSM -------------------------
    always @(posedge clk) begin
        if (reset) begin
            state    <= S_FETCH0;
            pc       <= 16'd0;
            ir       <= 8'd0;
            jmp_lo   <= 8'd0;
            mem_addr <= 16'd0;
            mem_rd   <= 1'b0;
            halted   <= 1'b0;
            we <= 1'b0; bc_we <= 1'b0; de_we <= 1'b0; hl_we <= 1'b0;
            flag_we <= 1'b0;
        end else begin
            // pulsed strobes default to 0 every cycle
            we <= 1'b0; bc_we <= 1'b0; de_we <= 1'b0; hl_we <= 1'b0;
            flag_we <= 1'b0; mem_rd <= 1'b0;

            case (state)

                // ---------- instruction fetch ----------
                S_FETCH0: begin
                    mem_addr <= pc;
                    mem_rd   <= 1'b1;
                    state    <= S_FETCH1;
                end

                S_FETCH1: begin
                    ir       <= mem_din;
                    pc       <= pc + 16'd1;
                    mem_addr <= pc + 16'd1;
                    mem_rd   <= 1'b1;

                    // ---------- decode ----------
                    case (mem_din)
                        8'h00: state <= S_FETCH0;   // NOP
                        8'h76: state <= S_HALT;     // HLT
                        8'h08: state <= S_MUL;      // MUL8  (custom - our work)
                        8'h28: state <= S_MUL;      // MUL16 (custom - our work)
                        8'hC3, 8'hC2, 8'hCA:
                               state <= S_JMP_L;   // JMP / JNZ / JZ
                        8'hC6: state <= S_IMM_RD;   // ADI d8
                        default: begin
                            if (mem_din[7:6] == 2'b00 && mem_din[2:0] == 3'b110)
                                state <= S_MVI_RD;  // MVI r, d8  (00rrr110)
                            else if (mem_din[7:6] == 2'b00 &&
                                     (mem_din[2:0] == 3'b100 || mem_din[2:0] == 3'b101))
                                state <= S_REG_EX;  // INR / DCR r
                            else if (mem_din[7:6] == 2'b00 && mem_din[3:0] == 4'b0001)
                                state <= S_LXI_L;   // LXI rp, d16
                            else if (mem_din[7:6] == 2'b01)
                                state <= S_MOV;     // MOV r1, r2 (01dd dsss)
                            else if (mem_din[7:6] == 2'b10 &&
                                     (mem_din[5:3] == 3'b000 || mem_din[5:3] == 3'b001 ||
                                      mem_din[5:3] == 3'b010 || mem_din[5:3] == 3'b100 ||
                                      mem_din[5:3] == 3'b101 || mem_din[5:3] == 3'b110 ||
                                      mem_din[5:3] == 3'b111))
                                state <= S_REG_EX;  // ADD/ADC/SUB/ANA/XRA/ORA/CMP r
                            else
                                state <= S_FETCH0;  // unknown opcode -> NOP (safe)
                        end
                    endcase
                end

                // ---------- MVI r, d8 ----------
                S_MVI_RD: begin
                    mem_addr <= pc;
                    mem_rd   <= 1'b1;
                    state    <= S_MVI_WR;
                end
                S_MVI_WR: begin
                    we    <= 1'b1;
                    waddr <= ir[5:3];
                    wdata <= mem_din;               // immediate byte on the bus
                    pc    <= pc + 16'd1;
                    state <= S_FETCH0;
                end

                // ---------- ADI d8 ----------
                S_IMM_RD: begin
                    mem_addr <= pc;
                    mem_rd   <= 1'b1;
                    state    <= S_IMM_EX;
                end
                S_IMM_EX: begin
                    // alu_b is mem_din here (the immediate byte, still on the bus)
                    we      <= 1'b1;
                    waddr   <= 3'b111;              // accumulator
                    wdata   <= alu_result;
                    flag_we <= 1'b1;
                    fz_in <= alu_z; fs_in <= alu_s; fp_in <= alu_p;
                    fcy_in <= alu_cy; fac_in <= alu_ac;
                    pc    <= pc + 16'd1;
                    state <= S_FETCH0;
                end

                // ---------- register ALU ops ----------
                S_REG_EX: begin
                    if (ir[7:6] == 2'b10 && ir[5:3] == 3'b111) begin
                        // CMP r : update flags only, throw the result away
                        flag_we <= 1'b1;
                        fz_in <= alu_z; fs_in <= alu_s; fp_in <= alu_p;
                        fcy_in <= alu_cy; fac_in <= alu_ac;
                    end else if (is_inr_dcr) begin
                        // INR / DCR r : write back to the same register.
                        // 8085 does NOT touch CY here, so we feed it back.
                        we      <= 1'b1;
                        waddr   <= ir[5:3];
                        wdata   <= alu_result;
                        flag_we <= 1'b1;
                        fz_in <= alu_z; fs_in <= alu_s; fp_in <= alu_p;
                        fac_in <= alu_ac;
                        fcy_in <= fcy;
                    end else begin
                        // ADD / ADC / SUB / ANA / XRA / ORA r : result -> A
                        we      <= 1'b1;
                        waddr   <= 3'b111;
                        wdata   <= alu_result;
                        flag_we <= 1'b1;
                        fz_in <= alu_z; fs_in <= alu_s; fp_in <= alu_p;
                        fcy_in <= alu_cy; fac_in <= alu_ac;
                    end
                    state <= S_FETCH0;
                end

                // ---------- MOV r1, r2 ----------
                S_MOV: begin
                    we    <= 1'b1;
                    waddr <= ir[5:3];               // destination
                    wdata <= rf_r1;                 // source (raddr1 = ir[2:0])
                    state <= S_FETCH0;
                end

                // ---------- JMP / JNZ / JZ ----------
                S_JMP_L: begin
                    jmp_lo   <= mem_din;
                    pc       <= pc + 16'd1;
                    mem_addr <= pc + 16'd1;
                    mem_rd   <= 1'b1;
                    state    <= S_JMP_H;
                end
                S_JMP_H: begin
                    if (jump_taken(ir, fz))
                        pc <= {mem_din, jmp_lo};    // load new PC
                    else
                        // NOT taken: pc still points AT the high address
                        // byte (JMP_L only advanced past the low byte),
                        // so step past it. Without this, a not-taken
                        // jump would re-fetch the high byte as an
                        // opcode (masked in the test program only
                        // because its jump high bytes are 00h = NOP).
                        pc <= pc + 16'd1;
                    state <= S_FETCH0;
                end

                // ---------- LXI rp, d16 ----------
                S_LXI_L: begin
                    jmp_lo   <= mem_din;
                    pc       <= pc + 16'd1;
                    mem_addr <= pc + 16'd1;
                    mem_rd   <= 1'b1;
                    state    <= S_LXI_H;
                end
                S_LXI_H: begin
                    case (ir[5:4])
                        2'b00: begin bc_we <= 1'b1; bc_wdata <= {mem_din, jmp_lo}; end
                        2'b01: begin de_we <= 1'b1; de_wdata <= {mem_din, jmp_lo}; end
                        2'b10: begin hl_we <= 1'b1; hl_wdata <= {mem_din, jmp_lo}; end
                        default: ; // LXI SP not in this subset
                    endcase
                    pc    <= pc + 16'd1;   // past the high immediate byte
                    state <= S_FETCH0;
                end

                // ---------- MUL8 / MUL16 : single-cycle execute ----------
                // prod8 / prod32 are combinational, so one state is enough.
                S_MUL: begin
                    hl_we   <= 1'b1;
                    flag_we <= 1'b1;
                    if (ir == 8'h08) begin
                        // MUL8: HL = A * B
                        hl_wdata <= prod8;
                        fz_in  <= (prod8 == 16'd0);
                        fs_in  <= prod8[15];
                        fp_in  <= ~(^prod8[7:0]);
                        fcy_in <= 1'b0;
                        fac_in <= 1'b0;
                    end else begin
                        // MUL16: HL = low 16 bits of BC*DE, CY = overflow
                        hl_wdata <= prod32[15:0];
                        fz_in  <= (prod32[15:0] == 16'd0);
                        fs_in  <= prod32[15];
                        fp_in  <= ~(^prod32[7:0]);
                        fcy_in <= |prod32[31:16];
                        fac_in <= 1'b0;
                    end
                    state <= S_FETCH0;
                end

                // ---------- HLT ----------
                S_HALT: begin
                    halted <= 1'b1;
                    state  <= S_HALT;               // stay here forever
                end

                default: state <= S_FETCH0;
            endcase
        end
    end

endmodule
