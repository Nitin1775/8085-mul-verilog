# 8085 Soft Core with Hardware Multiply — Verilog

**B.Tech Final Year Project — 5-member team including Nitin Shukla, KIET Group of Institutions, 2026**

A stock 8085 has no multiply instruction. This core adds two custom multiply
instructions on the 8085's undocumented opcodes, and verifies the whole core
in simulation. No FPGA board is needed to run it.

> **Correct timing claim:** the multiplier itself is combinational (1 execute
> cycle). A full MUL8 / MUL16 instruction takes **3 clock cycles** on this
> core (fetch + execute). It is *not* a 1-cycle instruction end-to-end.

| Instruction | Opcode | Operation | Flags |
|---|---|---|---|
| `MUL8` | `0x08` | `HL = A × B` (unsigned 8×8 → 16) | Z, S, P from result; CY=0 |
| `MUL16` | `0x28` | `HL = (BC × DE)[15:0]` (unsigned 16×16 → low 16) | Z, S, P; CY=1 if product > 16 bits |

`0x08` and `0x28` are NOPs on a real 8085, so existing programs keep working.

## What this demonstrates

- Verilog RTL: CPU control FSM, ALU, register file, memory, datapath wiring
- ISA extension: custom opcodes without breaking the base instruction set
- Verification: directed testbenches with PASS/FAIL checks, not just waveforms
- Vivado flow: synthesis top (`top_8085`), Artix-7 35T setup script, timing constraint

## File layout

```
├── rtl/
│   ├── cpu_8085.v    # PC, IR, control FSM, datapath wiring
│   ├── alu.v         # 8-bit ALU + 8085 flags (ADD/ADC/SUB/ANA/XRA/ORA/CMP/INR/DCR)
│   ├── mul_unit.v    # Combinational 8x8 and 16x16 multipliers (the novelty)
│   ├── regfile.v     # A,B,C,D,E,H,L + flags, 16-bit pair access
│   ├── memory.v      # 4KB memory, blank by design — loaded by each testbench
│   └── top_8085.v    # Synthesis top (CPU + memory)
├── tb/
│   ├── tb_8085_full.v     # Full 42-check suite — the main verification evidence
│   ├── tb_8085.v          # Quick MUL demo with register dumps
│   ├── tb_mul_exhaustive.v # Exhaustive MUL8 verification
│   └── tb_user_program.v  # Run your own program, check the register dump by hand
├── vivado_setup.tcl  # One-command Vivado project setup (Artix-7 35T)
└── timing.xdc        # 10 ns clock constraint for top_8085
```

Supported subset (educational): `NOP, MVI r,d8, MOV r,r, LXI B/D/H,d16, ADD/ADC/SUB r, ADI d8, ANA/XRA/ORA/CMP r, INR/DCR r, JMP/JNZ/JZ, HLT` — plus `MUL8` / `MUL16`.

## Run it (free tools, Icarus Verilog)

```bash
# Full 42-check suite
iverilog -o sim.vvp rtl/*.v tb/tb_8085_full.v
vvp sim.vvp

# Quick MUL demo
iverilog -o sim.vvp rtl/*.v tb/tb_8085.v
vvp sim.vvp

# Your own program: edit the USER PROGRAM section in tb/tb_user_program.v, then
iverilog -o user.vvp rtl/cpu_8085.v rtl/alu.v rtl/mul_unit.v rtl/regfile.v rtl/memory.v tb/tb_user_program.v
vvp user.vvp
```

Expected from the full suite: `RESULT: ALL 42 TESTS PASSED`, including
`MUL8 -> HL = 0120h (12h * 10h = 288)` and `MUL16 -> HL = 7470h, CY = 1`.

## Official result — tb_8085_full only

For the paper, resume, and GitHub, the result comes **only** from
`tb/tb_8085_full.v` — final line `# RESULT: ALL 42 TESTS PASSED`
(or `# RESULT: n PASSED, m FAILED` if any fail).

The other testbenches are **not** result evidence:
- `tb_8085.v` — demo only, register dumps, no counted result
- `tb_mul_exhaustive.v` — supplementary MUL check, not the 42-check result
- `tb_user_program.v` — hand-checked by you, no PASS/FAIL count

`vivado_setup.tcl` already uses `tb_8085_full` as the simulation top, so
Vivado and Icarus now point at the same official result.

Memory is blank by design — like a real 8085, a program is loaded by the
testbench that runs it. That is what makes this a processor, not a test replay.

## Run it in Vivado

1. Open Vivado → Tools → Run Tcl Script → select `vivado_setup.tcl`
   (or `vivado -mode batch -source vivado_setup.tcl` from this folder)
2. It creates project `cpu8085_mul`, adds all sources, and runs the
   behavioural simulation with `tb_8085_full` as the top.
3. Synthesis top is `top_8085`. For the area cost of the novelty, synthesise
   once with `USE_MUL = 1` in `mul_unit.v` and once with `USE_MUL = 0`, and
   compare LUT/FF/BRAM — fill that table from your own run, don't copy numbers.

Board part in the script is `xc7a35tcpg236-1` (Artix-7 35T: Basys3 / Arty A7).
Change the `PART` line if your lab uses a different board.

## Results, honestly stated

| Task | Clocks on this core |
|---|---|
| MUL8 / MUL16 instruction (fetch + execute) | 3 |
| Textbook 8085 software 8-bit multiply (shift-and-add loop) | ~250 T-states |

So roughly 80–100× faster for multiply-heavy code, for one small
combinational multiplier. Area numbers are left for your Vivado/Yosys run
(see above) — they are not claimed here without a run to back them.

## Limitations

- Educational instruction subset — no stack / CALL / RET yet
- Non-pipelined, multi-cycle baseline core; only the multiply execute is single-cycle
- Verified in simulation; FPGA timing/power are future work, not claimed results

## References

- R. S. Gaonkar, *Microprocessor Architecture, Programming, and Applications with the 8085*
- Intel MCS-80/85 Family User's Manual (opcode map)
- Ken Shirriff's 8085 reverse-engineering notes (righto.com) — undocumented opcodes
