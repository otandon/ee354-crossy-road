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

## Milestone 2: Static background

**Built**
- `src/level_rom.v`: combinational (level, row) -> descriptor. Level 1 only
  so far: goal row 0, river row 5 (`LOG_A`, right, 1 px/frame), roads rows 10
  (`CAR_A`) and 12 (`CAR_B`), both left, 1 px/frame. Everything else is grass.
  Speeds are named localparams at the top of the file.
- `src/renderer.v`: DESIGN 8.4 as written. Screen coordinates from the
  counters (x = hCount - 145, y = vCount - 35), black outside the 640x480
  window including the 481st line, draw priority text > state backgrounds >
  chicken > car/log > lane.
- `crossy_top`: renderer + one level_rom for the row being drawn, level 1,
  offset 0, state forced to PLAY, chicken parked on the never-drawn row 15.
  Cars and logs therefore appear, standing still at their offset-0 positions.
  LD15 heartbeat kept.

**Tests passing:** `tb_lane_lookup`, `tb_level_rom` (level 1 against the
DESIGN 5 table: kinds, odd-right/even-left directions, speeds, non-empty
moving lanes, empty grass/goal rows, unused levels 0/6/7 are grass),
`tb_renderer` (every lane color, the 4..27 band edges, car edges with and
without offset, chicken box edges, red chicken in DEATH, chicken at x = 608,
each state's background, text priority, blanking and the 481st line),
`tb_top` (now also probes 8 pixels of the level 1 picture on the real VGA
timing).

**Unverified:** synthesis, timing, the picture on a monitor.

**Board checks** (bring-up step 2)
- [ ] 15 horizontal bands, each 32 px tall, top to bottom: yellow goal, four
      grass, blue river (row 5), four grass, gray road (row 10), grass, gray
      road (row 12), two grass.
- [ ] Brown logs on the river: two 6-tile logs starting at the left edge.
      Red cars: two 2-tile cars on row 10, two 3-tile trucks on row 12, all
      starting at the left edge. Cars and logs are thinner than their lane
      (4 px of lane color above and below).
- [ ] Picture fills the screen edge to edge, nothing wraps or is cut off, no
      flicker. LD15 still blinks once a second.

## Milestone 3: Hopping

**Built**
- `src/debouncer.v`: DESIGN 6 sketch. Two-flop synchronizer, 2^21-cycle
  (21 ms) settle counter, one-cycle pulse on press only. Width is the
  parameter `CNT_W`; `crossy_top` passes `DEBOUNCE_BITS` from the defs file.
- `src/input_latch.v`: pulse sets, `frame_tick` clears, set wins on a tie.
- `src/player_ctrl.v`: hops in priority order up > down > left > right, one
  per `play_tick`, edges ignored; `best_row` / `new_row` / `at_goal`. Log
  carry is not in yet (`carried_off` is tied to 0 until milestone 5).
- `crossy_top`: five debouncers, the latch, and `player_ctrl` with
  `play_tick = frame_tick` (no state machine yet). The chicken is drawn.

**Tests passing:** all of the above plus `tb_debouncer` (clean press held
20x the settle time gives one pulse; release, short glitches, one-cycle
spikes and dropouts give none; bouncy press gives one; ten presses give ten;
latency is the settle time + sync), `tb_input_latch` (each bit set/held/
visible on the tick cycle/cleared; set wins on the tick cycle; reset),
`tb_player_ctrl` (one tile per hop, all four edges ignored, hop priority,
new_row exactly once per row per level, none for back-and-forth, none after
respawn, all 14 again after level_load), `tb_top` (adds a chicken pixel
probe).

**Unverified:** button feel, synthesis, timing.

**Board checks** (bring-up step 3)
- [ ] A 24x24 white square sits on the bottom row, horizontally centered
      (left edge of its tile at x = 320).
- [ ] Each tap of BtnU/BtnD/BtnL/BtnR moves it exactly one tile. Tap each
      direction 20 times: exactly 20 hops, none missed, none doubled.
- [ ] Holding a button gives one hop, not repeats.
- [ ] Hopping into each of the four screen edges does nothing.
- [ ] The chicken can walk over the static cars and river (no collisions yet).

## Milestone 4: Scrolling

**Built**
- `src/lane_engine.v`: 15 `level_rom` instances in a generate loop (constant
  row each), 15 offset registers updated per DESIGN 8.1 (wrap at 640 in both
  directions), cleared by reset or `level_load`. `lane_r`/`off_r` are a
  combinational row mux; `lane_p`/`off_p` are registered. Row 15 returns grass
  at offset 0.
- `crossy_top`: the renderer now reads `lane_r`/`off_r` from `lane_engine`
  (level 1, every frame tick is a play tick), and `player_ctrl` gets `lane_p`
  (not used until milestone 5).

**Tests passing:** all previous, plus `tb_lane_engine` (for each level:
lane_r equals level_rom for every row; every row's offset matches an integer
model after each of 700 ticks, which crosses the wrap point moving right and
left; no motion without play_tick; level_load and reset clear; lane_p/off_p
equal the chicken row's values one clock later; row 15 is grass/0).
Levels 2–5 are still all grass, so only speed 1 is exercised until
milestone 8.

**Unverified:** smoothness of motion on the monitor, synthesis, timing.

**Board checks** (bring-up step 4)
- [ ] Logs on row 5 drift right; cars on rows 10 and 12 drift left, about
      10.7 s to cross the whole screen at 1 px/frame.
- [ ] Cars and logs leave one edge and reappear at the other with no jump,
      gap, or one-frame glitch at the wrap point; an object straddling the
      edge is drawn split across both sides.
- [ ] Motion is smooth with no tearing or shimmer (state changes only in
      vertical blanking).
- [ ] The chicken still hops; it passes through cars and stands on water
      (no collisions yet).

## Milestone 5: Collision and log riding

**Built**
- `src/collision.v`: DESIGN 8.3. Three sample points (x+4, x+27, x+16) via
  the shared `occupied`; car hit on either edge, water if the center is off a
  log; both results registered once.
- `src/player_ctrl.v`: now hop > ride the log > snap to the nearest tile, and
  `carried_off` (river lane and the log would push x below 0 or above 608).
  An ignored hop falls through to the ride/snap step.
- `crossy_top`: collision instance; temporary debug LEDs LD14 = hit_car,
  LD13 = in_water, LD12 = carried_off. LD15 heartbeat kept. Nothing kills the
  chicken yet.

**Tests passing:** all previous, plus `tb_collision` (car under only the left
sample point, only the right, last/first pixel, narrowly missing on each side;
offsets; a car split across the wrap point; chicken centered on each log end
and one pixel off it; grass and goal never hit; registered one clock late;
reset) and the new `tb_player_ctrl` cases (carry right/left at speeds 1–4;
carried_off at x = 0 and 608 and not at 1/607; speed 3 at x = 2; speed 4 at
604 vs 608; ignored hop falls through to ride; hop beats ride; snap 47 -> 32,
48 -> 64, 575 -> 576, 69 -> 64; snap only on play_tick). A mutation check
(`>` to `>=` in carried_off; right sample point moved to center) made both
testbenches fail, so the cases have teeth.

**Unverified:** that the LEDs agree with what the eye sees, synthesis, timing.

**Board checks** (bring-up step 5)
- [ ] Hop onto a road and let a car hit the chicken: LD14 lights while they
      overlap and goes out when the car has passed. A car passing one tile
      away does not light it.
- [ ] Hop onto the river (row 5) where there is no log: LD13 lights. Hop onto
      a log: LD13 stays off and the chicken drifts right with the log, staying
      fixed relative to it.
- [ ] Ride a log to the right edge: the chicken stops at the edge, LD12 lights,
      and LD13 lights once the log has moved out from under it.
- [ ] Hop from the log back onto grass between tiles: the chicken snaps to the
      nearest tile (a jump of at most 16 px) one frame later.

## Milestone 6: State machine, lives, respawn

**Built**
- `src/game_fsm.v`: the seven states and every DESIGN 7 transition, written
  as one-cycle event wires (start, goal, death, pause, resume, death_done,
  clear_done, ...) so later blocks reuse the same decisions. PLAY priority is
  goal > death > pause. `lives` decrements on entry to DEATH; DEATH holds 60
  frame ticks and LEVEL_CLEAR 120 (`HOLD_DEATH`/`HOLD_CLEAR` in the defs
  file), then the exit test runs on the next tick, so each lasts hold + 1
  ticks. `respawn` and `level_load` are registered one-cycle pulses.
  Start level = SW2..0 if 1–5, else 1. Unused state code 7 recovers to TITLE.
  Score and timer outputs are held at 0 (milestone 7).
- `crossy_top`: the full module graph from DESIGN 3. Switches go through two
  flip-flops. LEDs now final: Ld0–Ld2 lives, LD15..LD9 one-hot state
  (the milestone 1 heartbeat and milestone 5 debug LEDs are gone).

**Tests passing:** all previous, plus `tb_game_fsm` (reset state; TITLE
waits for BtnC on a tick; SW = 0/1/3/5/6/7; switch ignored after start;
play_tick only in PLAY; pause/resume and nothing moves or dies while paused;
death by car, water and carried-off; DEATH = 61 ticks and LEVEL_CLEAR = 121
ticks; respawn without level_load after a death; BtnC ignored in DEATH and
LEVEL_CLEAR; third death -> GAME_OVER -> TITLE; level clear -> next level
with both pulses; goal + death + BtnC on one tick -> LEVEL_CLEAR; death +
BtnC -> DEATH; level 5 clear -> WIN -> TITLE; SW = 5 start; reset from all
seven states). Mutations (death-before-goal, hold off by one) are caught.
`tb_top` now presses BtnC (debounce shortened by `defparam` in the testbench
only) and checks the title screen in frame 1 and level 1 in frame 2.

**Unverified:** the game loop on the board, synthesis, timing.

**Board checks** (bring-up steps 5–6, first half)
- [ ] After programming or CPU_RESET: black screen, LD15 lit, Ld0–Ld2 off.
- [ ] BtnC: level 1 appears, LD14 lit, all three lives LEDs lit.
- [ ] Hit a car: chicken turns red, LD12 lit, cars keep their position (all
      motion frozen) for about 1 s, one lives LED goes out, then the chicken
      reappears on the start tile and play resumes.
- [ ] Same for stepping into water and for riding a log off either edge.
- [ ] Third death: screen turns dark red, LD10 lit. BtnC returns to the black
      title screen (LD15).
- [ ] BtnC during play freezes everything (LD13); BtnC again resumes exactly
      where it stopped.
- [ ] Reach the top row: about 2 s frozen with LD11 lit, then level 2 loads
      (still looks like level 1 until milestone 8, but lanes restart from
      their initial positions). Clearing level 5 (SW = 5 at start) gives a
      dark green screen with LD9 lit; BtnC returns to the title.
- [ ] CPU_RESET returns to the title from each of the seven states.
