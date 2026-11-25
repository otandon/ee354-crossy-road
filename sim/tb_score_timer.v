`timescale 1ns / 1ps
`default_nettype none
// tb_score_timer -- BCD score and timer inside game_fsm (DESIGN 8.5, 8.6):
// score carry 90 -> 100 and 990 -> 1000, +100 with carry, score kept across
// deaths and levels and cleared on a new game, new_row ignored outside a
// play_tick; per-level timer loads, one second per 60 play ticks, borrow
// 10 -> 09 and 60 -> 59, frozen in PAUSE / DEATH / LEVEL_CLEAR, 00 causes a
// death and a reload, goal on the tick the timer runs out clears the level.
module tb_score_timer;
`include "crossy_defs.vh"

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg frame_tick = 1'b0, req_c = 1'b0;
  reg hit_car = 1'b0, in_water = 1'b0, carried_off = 1'b0, at_goal = 1'b0, new_row = 1'b0;
  reg [2:0] sw_level = 3'd1;
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

  wire [15:0] score = {score_th, score_h, score_t, 4'd0};   // BCD, as displayed
  wire [7:0]  timer = {timer_tens, timer_ones};

  integer errors = 0;

  // One frame. nr: new_row is high during the tick (as player_ctrl drives it).
  task frame;
    input c, nr;
    begin
      @(negedge clk);
      req_c = c; new_row = nr; frame_tick = 1'b1;
      @(negedge clk);
      req_c = 1'b0; new_row = 1'b0; frame_tick = 1'b0;
      repeat (3) @(negedge clk);
    end
  endtask

  task frames;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) frame(1'b0, 1'b0);
    end
  endtask

  task new_rows;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) frame(1'b0, 1'b1);
    end
  endtask

  task expect_score;
    input [15:0] want;
    input [8*48-1:0] what;
    begin
      if (score !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: score %h, expected %h", what, score, want);
      end
    end
  endtask

  task expect_timer;
    input [7:0] want;
    input [8*48-1:0] what;
    begin
      if (timer !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: timer %h, expected %h", what, timer, want);
      end
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

  task start;
    input [2:0] sw;
    begin
      sw_level = sw;
      frame(1'b1, 1'b0);
    end
  endtask

  task do_reset;
    begin
      @(negedge clk); reset = 1'b1; @(negedge clk); reset = 1'b0;
    end
  endtask

  // Run until the state leaves its current value (bounded).
  task wait_state_change;
    integer k;
    reg [2:0] s0;
    begin
      s0 = state; k = 0;
      while (state == s0 && k < 1000) begin frame(1'b0, 1'b0); k = k + 1; end
    end
  endtask

  function integer bcd2int;
    input [7:0] b;
    begin
      bcd2int = b[7:4] * 10 + b[3:0];
    end
  endfunction

  task run_down;
    integer k, since, prev, seconds;
    reg     first;
    begin
      k = 0; since = 0; first = 1'b1; seconds = 0;
      prev = bcd2int(timer);
      while (timer !== 8'h00 && k < 5000) begin
        frame(1'b0, 1'b0);
        since = since + 1; k = k + 1;
        if (bcd2int(timer) != prev) begin
          if (timer[3:0] > 4'd9 || bcd2int(timer) != prev - 1) begin
            errors = errors + 1;
            $display("FAIL timer stepped from %0d to %h", prev, timer);
          end
          if (!first && since != 60) begin
            errors = errors + 1;
            $display("FAIL second ending at %h lasted %0d play ticks", timer, since);
          end
          first = 1'b0; since = 0; seconds = seconds + 1;
          prev = bcd2int(timer);
        end
      end
      if (state !== S_PLAY) begin
        errors = errors + 1; $display("FAIL left PLAY before the timer reached 00");
      end
      $display("ran the timer down through %0d seconds", seconds);
    end
  endtask

  initial begin
    @(negedge clk); @(negedge clk);
    reset = 1'b0;
    expect_score(16'h0000, "after reset");
    expect_timer(8'h00, "after reset");

    // ------------------------------------------------ timer load per level
    start(3'd1); expect_timer(TIME_L1, "level 1 start");
    do_reset; start(3'd2); expect_timer(TIME_L2, "level 2 start");
    do_reset; start(3'd3); expect_timer(TIME_L3, "level 3 start");
    do_reset; start(3'd4); expect_timer(TIME_L4, "level 4 start");
    do_reset; start(3'd5); expect_timer(TIME_L5, "level 5 start");
    do_reset; start(3'd0); expect_timer(TIME_L1, "SW=0 start loads level 1 time");
    expect_timer(8'h60, "level 1 is 60 s");

    // ------------------------------------------------ one second = 60 play ticks, borrow 60 -> 59
    frames(59);
    expect_timer(8'h60, "59 ticks: still 60");
    frames(1);
    expect_timer(8'h59, "60 ticks: 59 (borrow from tens)");
    frames(60 * 8);
    expect_timer(8'h51, "8 more seconds");
    frames(60);
    expect_timer(8'h50, "50");
    frames(60);
    expect_timer(8'h49, "50 -> 49");

    // ------------------------------------------------ score: +10, carry 90 -> 100
    expect_score(16'h0000, "score before any row");
    new_rows(1);
    expect_score(16'h0010, "+10");
    new_rows(8);
    expect_score(16'h0090, "90");
    new_rows(1);
    expect_score(16'h0100, "90 -> 100");
    // new_row outside a play_tick is ignored
    @(negedge clk); new_row = 1'b1; repeat (5) @(negedge clk); new_row = 1'b0;
    expect_score(16'h0100, "new_row without a tick");

    // ------------------------------------------------ pause freezes the timer and score
    frame(1'b1, 1'b0);
    expect_state(S_PAUSE, "paused");
    frames(300);
    frame(1'b0, 1'b1);
    expect_timer(8'h49, "timer frozen in PAUSE");
    expect_score(16'h0100, "new_row ignored in PAUSE");
    frame(1'b1, 1'b0);
    expect_state(S_PLAY, "resumed");

    // ------------------------------------------------ borrow 10 -> 09
    // 49 -> 10 is 39 s; the sub-second count resumed where the pause left it
    frames(60 * 39);
    expect_timer(8'h10, "10");
    frames(60);
    expect_timer(8'h09, "10 -> 09");

    // ------------------------------------------------ score carry 990 -> 1000
    new_rows(89);
    expect_score(16'h0990, "990");
    new_rows(1);
    expect_score(16'h1000, "990 -> 1000");

    // ------------------------------------------------ timer 00 causes a death and a reload
    // Run down to 00. Every change must be exactly one second less (BCD) and
    // every full second must last exactly 60 play ticks.
    run_down;
    expect_timer(8'h00, "ran out");
    expect_state(S_PLAY, "still PLAY on the tick it reached 00");
    frame(1'b0, 1'b0);
    expect_state(S_DEATH, "timer 00 kills");
    if (lives !== 2'd2) begin errors = errors + 1; $display("FAIL lives %0d after timeout", lives); end
    expect_timer(8'h00, "timer stays 00 during DEATH (no underflow)");
    wait_state_change;
    expect_state(S_PLAY, "respawned");
    expect_timer(TIME_L1, "timer reloaded on respawn");
    expect_score(16'h1000, "score kept across a death");
    // the sub-second count restarts on reload
    frames(59); expect_timer(8'h60, "59 ticks after reload");
    frames(1);  expect_timer(8'h59, "60 ticks after reload");

    // ------------------------------------------------ +100 with carry: 1000 -> 1100, then 1150 -> 1250
    at_goal = 1'b1; frame(1'b0, 1'b0); at_goal = 1'b0;
    expect_state(S_LEVEL_CLEAR, "goal");
    expect_score(16'h1100, "+100 for the level");
    frames(60);
    expect_timer(8'h59, "timer frozen in LEVEL_CLEAR");
    wait_state_change;
    expect_state(S_PLAY, "level 2");
    expect_timer(TIME_L2, "level 2 time loaded");
    new_rows(5);
    expect_score(16'h1150, "1150");
    at_goal = 1'b1; frame(1'b0, 1'b0); at_goal = 1'b0;
    expect_score(16'h1250, "1150 + 100");
    wait_state_change;
    expect_timer(TIME_L3, "level 3 time loaded");
    new_rows(5);
    at_goal = 1'b1; frame(1'b0, 1'b0); at_goal = 1'b0;
    expect_score(16'h1400, "1300 + 100, carry into thousands");
    wait_state_change;
    expect_timer(TIME_L4, "level 4 time loaded");

    // ------------------------------------------------ goal on the tick the timer runs out
    run_down;
    expect_timer(8'h00, "level 4 ran out");
    at_goal = 1'b1; frame(1'b0, 1'b0); at_goal = 1'b0;
    expect_state(S_LEVEL_CLEAR, "goal beats timeout");
    wait_state_change;
    expect_timer(TIME_L5, "level 5 time loaded");

    // ------------------------------------------------ new game clears the score
    hit_car = 1'b1;
    repeat (3) begin frame(1'b0, 1'b0); wait_state_change; end
    hit_car = 1'b0;
    expect_state(S_GAME_OVER, "game over");
    expect_score(16'h1500, "score shown on GAME_OVER");
    frame(1'b1, 1'b0);
    expect_state(S_TITLE, "title");
    expect_score(16'h1500, "score still shown on TITLE");
    start(3'd1);
    expect_score(16'h0000, "score cleared by a new game");
    expect_timer(TIME_L1, "timer loaded by a new game");

    // ------------------------------------------------ reset clears both
    new_rows(3);
    do_reset;
    expect_score(16'h0000, "reset clears score");
    expect_timer(8'h00, "reset clears timer");

    if (errors == 0) $display("PASS tb_score_timer");
    else             $display("FAIL tb_score_timer");
    $finish;
  end
endmodule
`default_nettype wire
