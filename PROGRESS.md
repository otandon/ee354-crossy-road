# Progress log

Simulation is run on the Mac with Icarus Verilog 12.0 (`scripts/sim.sh`).
Nothing in this file has been synthesized or run on the board unless a
milestone entry says so. Every "board check" below is still **unverified**.

## Spec issues

Places where DESIGN.md, the skeleton, CLAUDE.md or the course requirements
disagree or leave a gap. None of them changes game behavior or a section 6
port list, so each was resolved with the reading closest to DESIGN.md.

1. **`default_nettype` in `crossy_defs.vh`.** CLAUDE.md asks every new file to
   start with `` `default_nettype none `` and end with `` `default_nettype wire ``.
   Verilog only allows that directive outside a module, and the header is
   included inside module bodies (it holds localparams and a function, which
   must be module-scoped). Icarus rejects it. The header therefore has no
   `default_nettype` lines; every `.v` file that includes it already sets
   `none` before the module and `wire` after it.
2. **`lane_lookup` is a function, not a module.** Section 3 counts
   `lane_lookup` among the thirteen modules, but sections 5 and 11 and
   CLAUDE.md place it as the `occupied` function in `crossy_defs.vh`. There is
   no `lane_lookup.v`; `tb_lane_lookup` tests the function.
3. **`clk`/`reset` on combinational modules.** Section 6 says "every module
   also takes `clk` and `reset`", but `level_rom`, `renderer` and
   `text_overlay` are described as purely combinational, and their port lists
   omit them. I followed the explicit port lists: those three have no clock or
   reset (an unused clock port would only produce Vivado "no load" warnings).
4. **When `new_row` is valid.** Section 6 calls it a pulse; `game_fsm` only
   acts at frame ticks. `new_row` is combinational and high only during the
   `play_tick` cycle on which a forward hop lands on a row above `best_row`.
   `game_fsm` adds 10 on `play_tick && new_row`.
5. **Vivado flow.** Section 11 describes a GUI project; CLAUDE.md requires a
   non-project batch flow and no `.xpr`. `scripts/build.tcl` follows CLAUDE.md.
6. **Testbench list.** Section 11 lists six testbenches; CLAUDE.md asks for one
   per module. Both are provided: the six from section 12, plus
   `tb_debouncer`, `tb_input_latch`, `tb_level_rom`, `tb_lane_engine`,
   `tb_renderer`, `tb_text_overlay`, `tb_ssd_driver`.
7. **Debouncer length in simulation.** The 21-bit counter (21 ms) is a
   module parameter, `CNT_W`, defaulting to `DEBOUNCE_BITS` = 21 from
   `crossy_defs.vh`, so testbenches can shorten it. Not a port change. The
   synchronizer flops are also reset (the section 6 sketch leaves them unreset).
8. **Switches as controls.** The course asks for "switches and buttons" as
   player controls; the design uses switches only for the debug start level
   (DESIGN 14 lists this as an open question for the TA). Unchanged.
9. **Power-up without reset.** No `initial` blocks are allowed in `src/`, so
   registers power up at the FPGA default of 0. State 0 is TITLE, so the game
   comes up on the title screen; the only visible difference from a pressed
   CPU_RESET is that the level digit shows 0 instead of 1 until the first game
   starts (reset sets level to 1).
10. **Timescale.** `display_controller.v` has `` `timescale 1ns / 1ps ``.
    Icarus warns when some modules have a timescale and others do not, so every
    new file carries the same line. It has no effect on synthesis.
11. **Milestone 1 "skeleton picture still shows".** The skeleton files may not
    be built, so milestone 1's `crossy_top` draws a static copy of the skeleton
    picture (red screen, white band at vCount 400–475) itself. It was replaced
    by the renderer in milestone 2.
12. **The tick that ends PLAY.** `play_tick` is "`frame_tick` while in PLAY", so
    on the frame tick on which the FSM enters DEATH or LEVEL_CLEAR the lanes
    still advance one step and a pending hop still executes. This follows the
    spec; the visible effect is at most one frame of motion.

## Milestone 1: Foundations

**Built**
- `src/crossy_defs.vh`: state codes, lane kinds, colors, pattern library,
  shapes, start position, tunable rule values (lives, hold times, per-level
  timers), debounce length, and the shared `occupied` function.
- `src/crossy_top.v`: full section 6 port list; two-flop reset synchronizer
  (active high, synchronous); `frame_tick` edge-detected from vCount >= 516;
  temporary test picture (see spec issue 11); LD15 toggles every 60 frame ticks
  as a heartbeat. Seven-segment display and the other LEDs are off.
- `scripts/sim.sh`, `scripts/build.tcl`, `constr/crossy.xdc` (the skeleton XDC
  with CPU_RESETN, BtnL/R/D, Sw0–2, Ld0–2 and LD9–LD15 uncommented, nothing else
  changed).

**Tests passing:** `tb_lane_lookup` (2,048,077 checks of `occupied`, including
an exhaustive sweep of offsets 0–639 for tiles 0, 1, 10, 18, 19), `tb_top` (two
real frames: hSync/vSync toggle, RGB 0 whenever bright is 0, no X/Z on any
output, exactly one single-cycle `frame_tick` per frame, inside blanking).

**Unverified:** synthesis, timing, and everything on the board.

**VM checks:** run `scripts/build.tcl`; no latches, no multi-driven nets,
WNS >= 0. Expect unused-input warnings for BtnC/U/D/L/R and Sw0–2 at this
milestone only.

**Board checks** (bring-up step 1)
- [ ] Monitor locks and shows a red screen with a white horizontal band near
      the bottom, like the skeleton demo, with no flicker.
- [ ] LD15 blinks: on about 1 s, off about 1 s (frame_tick is running at 60 Hz).
- [ ] Pressing CPU_RESET restarts the blink phase and the picture stays.
