# Crossy Road on FPGA (EE354 final project)

A five-level Crossy Road game in Verilog for the Nexys A7-100T, drawn over VGA.
Team: Om Tandon (display and I/O), Ahmed Ataelfadeel (game logic).

## Read first

1. `DESIGN.md` is the specification. Read all of it before writing code.
   Section 6 has the module port lists, section 8 the reference logic,
   section 13 the build order.
2. `class_requirements.pdf` and `proposal.pdf` are what the project is graded against.
3. `skeleton/` holds the course's original demo files, for reference only.

If `DESIGN.md` and a skeleton file disagree about how the skeleton behaves,
the skeleton file is right: stop and tell me. If `DESIGN.md` is ambiguous or
looks wrong, ask before guessing. The Verilog inside `DESIGN.md` is an
untested sketch; treat it as intent, and verify it in simulation.

## Layout

```
DESIGN.md            specification
skeleton/            original course files; never edit, never build
src/                 all synthesizable code, plus crossy_defs.vh
sim/                 testbenches, one tb_<module>.v per module
constr/crossy.xdc    copy of skeleton/vga_demo.xdc with extra pins uncommented
scripts/             sim.sh and build.tcl
build/               generated output; git-ignored
PROGRESS.md          running status log
```

Create `sim/`, `constr/`, `scripts/` and `PROGRESS.md` as you need them.

## Hard rules

- Do not modify `src/display_controller.v` or anything in `skeleton/`.
- Plain Verilog-2001 only. No SystemVerilog (`logic`, `always_ff`, interfaces,
  `.sv` files), no Vivado IP cores, no block designs, no block RAM.
- One clock: `ClkPort` (100 MHz) for every new module. Never create another
  clock. `frame_tick` and `play_tick` are enables, not clocks.
- `crossy_top` keeps the port names from `skeleton/vga_top.v` and the names in
  the XDC (note `Ld0`-`Ld2` but `LD9`-`LD15`).
- Module ports follow `DESIGN.md` section 6. If a port list must change,
  update `DESIGN.md` in the same commit and say so in your summary.
- Shared constants and the `occupied` function live only in
  `src/crossy_defs.vh`. Never duplicate a constant in a module.
- Base game only. Do not start any stretch goal from section 14 unless asked.

## Verilog style

- Sequential: `always @(posedge clk)` with `<=` only. Synchronous,
  active-high `reset`. No `initial` blocks in `src/`.
- Combinational: `always @(*)` with `=` only, and a default assignment for
  every output at the top of the block. Every `case` has a `default`.
- Explicit widths on all constants (`10'd640`, not `640`).
- One module per file; file name equals module name.
- Each register is written in exactly one `always` block.
- Start each new file with `` `default_nettype none `` and end it with
  `` `default_nettype wire ``.
- The skeleton's style (initial blocks, blocking assignments in clocked
  blocks) is not a model to copy.

## Two machines

This repo is edited on a Mac and built on a separate VM. Check which one you
are on before running tools: `which iverilog` and `which vivado`.

**Mac (no Vivado).** Write code and run simulations with Icarus Verilog.
If `iverilog` is missing, tell me to run `brew install icarus-verilog`;
do not try to install Vivado here.

```
scripts/sim.sh              # run every testbench
scripts/sim.sh player_ctrl  # run sim/tb_player_ctrl.v only
```

`sim.sh` should compile with `iverilog -g2005 -Wall -I src`, run with `vvp`,
and exit non-zero if any testbench prints FAIL or fails to compile.

**VM (Vivado).** Synthesis, implementation and bitstream, in batch mode:

```
vivado -mode batch -source scripts/build.tcl
```

`build.tcl` is a non-project flow: `read_verilog` every `.v` in `src/`,
`read_xdc constr/crossy.xdc`, `synth_design -top crossy_top -part
xc7a100tcsg324-1 -include_dirs src`, then `opt_design`, `place_design`,
`route_design`, `report_timing_summary`, `report_utilization`, and
`write_bitstream`. All output goes to `build/`. Do not create or commit a
Vivado project (`.xpr`).

A VM build passes only when all three hold:
- no "inferring latch" or multi-driven net messages in the synthesis log,
- the utilization report shows zero latches,
- worst negative slack in the timing summary is zero or positive.

Report any other new warning rather than ignoring it. The counters inside
`display_controller` showing up as unclocked is expected (DESIGN.md section 9).

On the Mac you cannot run Vivado, so never claim a change synthesizes or
meets timing. Say it is simulated only and list what must be checked on the VM.

## Testbenches

- Self-checking: compare against expected values, print one line per check
  on failure, and end with exactly `PASS tb_<name>` or `FAIL tb_<name>`,
  then `$finish`.
- Drive `frame_tick` directly in unit tests (one pulse every few clocks).
  Only `tb_top` instantiates the real `display_controller`, for a frame or two.
- Cover the cases listed in `DESIGN.md` section 12.
- A module is not done until its testbench passes. Do not weaken a test to
  make it pass; fix the module, or tell me the spec is wrong.

## How to work

- Follow the ten milestones in `DESIGN.md` section 13, in order. Do not
  skip ahead.
- For each module: write it, write its testbench, run `scripts/sim.sh`,
  fix until it passes, then commit. One milestone per commit at minimum.
- After each milestone, update `PROGRESS.md` with: what was built, which
  testbenches pass, what is unverified, and the exact things I need to
  check on the VM and on the board.
- Stop after each milestone that changes what appears on screen (2, 3, 4,
  5, 6, 7, 8, 9) and wait for me to confirm the board result before
  building on it.

## What you cannot verify

You cannot see the board, the monitor, or the buttons. Simulation proves
logic, not the picture. For anything visual or physical (colors, flicker,
button feel, the seven-segment display, playability), give me a short
checklist of what to look for, taken from the bring-up steps and acceptance
checklist in `DESIGN.md` section 12, and treat it as unverified until I
report back.

## Values that are meant to change

Level layouts, speeds, timers, patterns and hold times are marked *tunable*
in `DESIGN.md`. Keep them as named constants in `crossy_defs.vh` or
`level_rom.v` so they can be adjusted after playtesting without touching logic.
