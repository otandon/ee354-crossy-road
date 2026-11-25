`timescale 1ns / 1ps
`default_nettype none
// tb_game_fsm -- every row of the DESIGN 7 transition table at least once:
// start (with the switch level rules), pause/resume, death by car / water /
// carried off, the DEATH and LEVEL_CLEAR hold times, respawn, third death to
// GAME_OVER, level clear to the next level, level 5 clear to WIN, back to
// TITLE from both end screens; the PLAY priority goal > death > pause;
// inputs ignored outside the states that use them; reset from every state;
// play_tick only in PLAY; respawn and level_load as single-cycle pulses.
module tb_game_fsm;
`include "crossy_defs.vh"

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg frame_tick = 1'b0, req_c = 1'b0;
  reg hit_car = 1'b0, in_water = 1'b0, carried_off = 1'b0, at_goal = 1'b0, new_row = 1'b0;
  reg [2:0] sw_level = 3'd0;
  wire [2:0] state, level;
  wire [1:0] lives;
  wire play_tick, respawn, level_load;
  wire [3:0] score_th, score_h, score_t, timer_tens, timer_ones;

  game_fsm dut(.clk(clk), .reset(reset), .frame_tick(frame_tick), .req_c(req_c),
               .hit_car(hit_car), .in_water(in_water), .carried_off(carried_off),
               .at_goal(at_goal), .new_row(new_row), .sw_level(sw_level),
               .state(state), .level(level), .lives(lives),
               .play_tick(play_tick), .respawn(respawn), .level_load(level_load),
               .score_th(score_th), .score_h(score_h), .score_t(score_t),
               .timer_tens(timer_tens), .timer_ones(timer_ones));

  integer errors = 0;
  integer respawns = 0, loads = 0, play_ticks = 0;
  reg     last_respawn = 1'b0, last_load = 1'b0;

  // Pulse bookkeeping and the play_tick rule, checked every cycle.
  always @(posedge clk) begin
    if (respawn === 1'b1) respawns = respawns + 1;
    if (level_load === 1'b1) loads = loads + 1;
    if (play_tick === 1'b1) play_ticks = play_ticks + 1;
    if (respawn === 1'b1 && last_respawn === 1'b1) begin
      errors = errors + 1; $display("FAIL respawn wider than one cycle");
    end
    if (level_load === 1'b1 && last_load === 1'b1) begin
      errors = errors + 1; $display("FAIL level_load wider than one cycle");
    end
    if (play_tick !== (frame_tick && state == S_PLAY)) begin
      errors = errors + 1; $display("FAIL play_tick=%b with frame_tick=%b state=%0d", play_tick, frame_tick, state);
    end
    last_respawn = respawn;
    last_load = level_load;
  end

  // One frame: inputs {c, hit, water, off, goal} held for the tick cycle only
  // for req_c (it is a latch output cleared by the tick); collision inputs
  // are levels and stay as set.
  task frame;
    input c;
    begin
      @(negedge clk);
      req_c = c; frame_tick = 1'b1;
      @(negedge clk);
      req_c = 1'b0; frame_tick = 1'b0;
      repeat (3) @(negedge clk);
    end
  endtask

  task frames;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) frame(1'b0);
    end
  endtask

  task set_hazards;
    input hit, water, off, goal;
    begin
      hit_car = hit; in_water = water; carried_off = off; at_goal = goal;
    end
  endtask

  task expect_state;
    input [2:0] want;
    input [8*48-1:0] what;
    begin
      if (state !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: state %0d, expected %0d", what, state, want);
      end
    end
  endtask

  task expect_status;
    input [2:0] want_state, want_level;
    input [1:0] want_lives;
    input [8*48-1:0] what;
    begin
      if (state !== want_state || level !== want_level || lives !== want_lives) begin
        errors = errors + 1;
        $display("FAIL %0s: state %0d level %0d lives %0d, expected %0d %0d %0d",
                 what, state, level, lives, want_state, want_level, want_lives);
      end
    end
  endtask

  task expect_pulses;
    input integer want_respawns, want_loads;
    input [8*48-1:0] what;
    begin
      if (respawns !== want_respawns || loads !== want_loads) begin
        errors = errors + 1;
        $display("FAIL %0s: %0d respawn / %0d level_load pulses, expected %0d / %0d",
                 what, respawns, loads, want_respawns, want_loads);
      end
      respawns = 0; loads = 0;
    end
  endtask

  // Frames spent in the current state before it changes (bounded).
  integer held;
  task count_hold;
    reg [2:0] s0;
    begin
      s0 = state; held = 0;
      while (state == s0 && held < 1000) begin
        frame(1'b0);
        held = held + 1;
      end
    end
  endtask

  task do_reset;
    begin
      @(negedge clk); reset = 1'b1;
      @(negedge clk); reset = 1'b0;
      set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
      respawns = 0; loads = 0;
    end
  endtask

  // Start a game from TITLE with the given switch setting.
  task start;
    input [2:0] sw;
    begin
      sw_level = sw;
      frame(1'b1);
    end
  endtask

  integer k;

  initial begin
    @(negedge clk); @(negedge clk);
    reset = 1'b0;
    respawns = 0; loads = 0;

    // ---------------------------------------------------- reset state
    expect_status(S_TITLE, 3'd1, 2'd0, "after reset");

    // ---------------------------------------------------- TITLE waits for BtnC on a tick
    frames(5);
    expect_state(S_TITLE, "TITLE without BtnC");
    @(negedge clk); req_c = 1'b1; repeat (5) @(negedge clk); req_c = 1'b0;
    expect_state(S_TITLE, "req_c without a frame tick");
    set_hazards(1'b1, 1'b1, 1'b1, 1'b1);
    frames(3);
    expect_status(S_TITLE, 3'd1, 2'd0, "collision inputs ignored in TITLE");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    if (play_ticks !== 0) begin
      errors = errors + 1; $display("FAIL %0d play_ticks outside PLAY", play_ticks);
    end
    expect_pulses(0, 0, "no pulses in TITLE");

    // ---------------------------------------------------- TITLE -> PLAY, switch rules
    start(3'd0);
    expect_status(S_PLAY, 3'd1, 2'd3, "start with SW=0 gives level 1");
    expect_pulses(1, 1, "start pulses respawn and level_load once");
    do_reset; start(3'd3); expect_status(S_PLAY, 3'd3, 2'd3, "start with SW=3");
    do_reset; start(3'd5); expect_status(S_PLAY, 3'd5, 2'd3, "start with SW=5");
    do_reset; start(3'd6); expect_status(S_PLAY, 3'd1, 2'd3, "start with SW=6 gives level 1");
    do_reset; start(3'd7); expect_status(S_PLAY, 3'd1, 2'd3, "start with SW=7 gives level 1");
    do_reset; start(3'd1); expect_status(S_PLAY, 3'd1, 2'd3, "start with SW=1");
    expect_pulses(1, 1, "start pulses");
    // the switch is read only at the start
    sw_level = 3'd4;
    frames(3);
    expect_status(S_PLAY, 3'd1, 2'd3, "switch change during play ignored");

    // ---------------------------------------------------- play_tick only in PLAY
    play_ticks = 0;
    frames(10);
    if (play_ticks !== 10) begin
      errors = errors + 1; $display("FAIL %0d play_ticks in 10 PLAY frames", play_ticks);
    end

    // ---------------------------------------------------- PLAY <-> PAUSE
    frame(1'b1);
    expect_state(S_PAUSE, "BtnC pauses");
    play_ticks = 0;
    set_hazards(1'b1, 1'b1, 1'b1, 1'b1);
    frames(20);
    expect_status(S_PAUSE, 3'd1, 2'd3, "PAUSE ignores collisions and goal");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    if (play_ticks !== 0) begin
      errors = errors + 1; $display("FAIL %0d play_ticks while paused", play_ticks);
    end
    frame(1'b1);
    expect_state(S_PLAY, "BtnC resumes");
    expect_pulses(0, 0, "pause and resume send no pulses");

    // ---------------------------------------------------- PLAY -> DEATH (car), hold, respawn
    set_hazards(1'b1, 1'b0, 1'b0, 1'b0);
    frame(1'b0);
    expect_status(S_DEATH, 3'd1, 2'd2, "hit by a car");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    count_hold;
    if (held !== HOLD_DEATH + 1) begin
      errors = errors + 1; $display("FAIL DEATH lasted %0d frame ticks, expected %0d", held, HOLD_DEATH + 1);
    end
    expect_status(S_PLAY, 3'd1, 2'd2, "respawn after the hold");
    expect_pulses(1, 0, "death respawns without level_load");

    // ---------------------------------------------------- BtnC is ignored in DEATH
    set_hazards(1'b0, 1'b1, 1'b0, 1'b0);
    frame(1'b0);
    expect_status(S_DEATH, 3'd1, 2'd1, "fell in the water");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    for (k = 0; k < 10; k = k + 1) frame(1'b1);
    expect_state(S_DEATH, "BtnC ignored in DEATH");
    count_hold;
    expect_status(S_PLAY, 3'd1, 2'd1, "second respawn");
    respawns = 0; loads = 0;

    // ---------------------------------------------------- third death -> GAME_OVER
    set_hazards(1'b0, 1'b0, 1'b1, 1'b0);
    frame(1'b0);
    expect_status(S_DEATH, 3'd1, 2'd0, "carried off: third death");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    count_hold;
    expect_status(S_GAME_OVER, 3'd1, 2'd0, "no lives left");
    expect_pulses(0, 0, "no respawn into GAME_OVER");
    frames(10);
    expect_state(S_GAME_OVER, "GAME_OVER waits for BtnC");
    frame(1'b1);
    expect_state(S_TITLE, "GAME_OVER -> TITLE on BtnC");

    // ---------------------------------------------------- level clear -> next level
    start(3'd1);
    respawns = 0; loads = 0;
    set_hazards(1'b0, 1'b0, 1'b0, 1'b1);
    frame(1'b0);
    expect_status(S_LEVEL_CLEAR, 3'd1, 2'd3, "goal reached");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    for (k = 0; k < 5; k = k + 1) frame(1'b1);
    expect_state(S_LEVEL_CLEAR, "BtnC ignored in LEVEL_CLEAR");
    count_hold;
    if (held !== HOLD_CLEAR + 1 - 5) begin
      errors = errors + 1; $display("FAIL LEVEL_CLEAR lasted %0d frame ticks, expected %0d", held + 5, HOLD_CLEAR + 1);
    end
    expect_status(S_PLAY, 3'd2, 2'd3, "next level");
    expect_pulses(1, 1, "next level sends respawn and level_load");

    // ---------------------------------------------------- goal and death on the same tick
    set_hazards(1'b1, 1'b1, 1'b1, 1'b1);
    frame(1'b1);
    expect_status(S_LEVEL_CLEAR, 3'd2, 2'd3, "goal beats death and pause");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    count_hold;
    expect_status(S_PLAY, 3'd3, 2'd3, "level 3");

    // ---------------------------------------------------- death beats pause
    set_hazards(1'b1, 1'b0, 1'b0, 1'b0);
    frame(1'b1);
    expect_status(S_DEATH, 3'd3, 2'd2, "death beats pause");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    count_hold;
    expect_status(S_PLAY, 3'd3, 2'd2, "respawn in level 3");

    // ---------------------------------------------------- level 5 clear -> WIN
    set_hazards(1'b0, 1'b0, 1'b0, 1'b1);
    frame(1'b0); set_hazards(1'b0, 1'b0, 1'b0, 1'b0); count_hold;
    expect_status(S_PLAY, 3'd4, 2'd2, "level 4");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b1);
    frame(1'b0); set_hazards(1'b0, 1'b0, 1'b0, 1'b0); count_hold;
    expect_status(S_PLAY, 3'd5, 2'd2, "level 5, lives carried over");
    respawns = 0; loads = 0;
    set_hazards(1'b0, 1'b0, 1'b0, 1'b1);
    frame(1'b0);
    expect_status(S_LEVEL_CLEAR, 3'd5, 2'd2, "level 5 goal");
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0);
    count_hold;
    expect_status(S_WIN, 3'd5, 2'd2, "level 5 clear wins");
    expect_pulses(0, 0, "no respawn or level_load into WIN");
    frames(10);
    expect_state(S_WIN, "WIN waits for BtnC");
    frame(1'b1);
    expect_state(S_TITLE, "WIN -> TITLE on BtnC");

    // ---------------------------------------------------- start at level 5 directly
    start(3'd5);
    set_hazards(1'b0, 1'b0, 1'b0, 1'b1);
    frame(1'b0); set_hazards(1'b0, 1'b0, 1'b0, 1'b0); count_hold;
    expect_state(S_WIN, "SW=5 start, one clear wins");

    // ---------------------------------------------------- reset from every state (IO-3)
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from WIN");
    start(3'd2);
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from PLAY");
    start(3'd2); frame(1'b1);
    expect_state(S_PAUSE, "paused before reset");
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from PAUSE");
    start(3'd2); set_hazards(1'b1, 1'b0, 1'b0, 1'b0); frame(1'b0);
    expect_state(S_DEATH, "dying before reset");
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from DEATH");
    start(3'd2); set_hazards(1'b0, 1'b0, 1'b0, 1'b1); frame(1'b0);
    expect_state(S_LEVEL_CLEAR, "clearing before reset");
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from LEVEL_CLEAR");
    start(3'd2);
    for (k = 0; k < 3; k = k + 1) begin
      set_hazards(1'b1, 1'b0, 1'b0, 1'b0); frame(1'b0);
      set_hazards(1'b0, 1'b0, 1'b0, 1'b0); count_hold;
    end
    expect_state(S_GAME_OVER, "game over before reset");
    do_reset; expect_status(S_TITLE, 3'd1, 2'd0, "reset from GAME_OVER");
    // reset in the middle of a hold, then a fresh game starts cleanly
    start(3'd1); set_hazards(1'b1, 1'b0, 1'b0, 1'b0); frame(1'b0); frames(10);
    do_reset;
    start(3'd1);
    expect_status(S_PLAY, 3'd1, 2'd3, "fresh game after reset mid-hold");
    set_hazards(1'b1, 1'b0, 1'b0, 1'b0); frame(1'b0);
    set_hazards(1'b0, 1'b0, 1'b0, 1'b0); count_hold;
    if (held !== HOLD_DEATH + 1) begin
      errors = errors + 1; $display("FAIL hold after reset lasted %0d", held);
    end

    if (errors == 0) $display("PASS tb_game_fsm");
    else             $display("FAIL tb_game_fsm");
    $finish;
  end
endmodule
`default_nettype wire
