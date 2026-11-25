`timescale 1ns / 1ps
`default_nettype none
// tb_player_ctrl -- hops, edges, priority, best_row/new_row, respawn,
// level_load, and nothing moves without play_tick.
module tb_player_ctrl;
`include "crossy_defs.vh"

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg play_tick = 1'b0, respawn = 1'b0, level_load = 1'b0;
  reg req_u = 1'b0, req_d = 1'b0, req_l = 1'b0, req_r = 1'b0;
  reg [25:0] lane_p = 26'd0;
  wire [9:0] player_x;
  wire [3:0] player_row;
  wire at_goal, new_row, carried_off;

  player_ctrl dut(.clk(clk), .reset(reset), .play_tick(play_tick),
                  .respawn(respawn), .level_load(level_load),
                  .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r),
                  .lane_p(lane_p), .player_x(player_x), .player_row(player_row),
                  .at_goal(at_goal), .new_row(new_row), .carried_off(carried_off));

  integer errors = 0;
  reg     saw_new_row;
  integer new_rows = 0;

  // new_row must never be high outside a play_tick
  always @(negedge clk)
    if (new_row === 1'b1 && play_tick !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL new_row high without play_tick at %0t", $time);
    end

  // One frame: requests {u,d,l,r} are held during a single play_tick cycle.
  task tick;
    input [3:0] udlr;
    begin
      {req_u, req_d, req_l, req_r} = udlr;
      play_tick = 1'b1;
      #1 saw_new_row = new_row;
      if (new_row === 1'b1) new_rows = new_rows + 1;
      @(posedge clk); #1;
      play_tick = 1'b0;
      {req_u, req_d, req_l, req_r} = 4'b0000;
      repeat (3) @(posedge clk); #1;
    end
  endtask

  task pulse_respawn;
    begin
      respawn = 1'b1; @(posedge clk); #1; respawn = 1'b0;
    end
  endtask

  task pulse_level_load;
    begin
      level_load = 1'b1; respawn = 1'b1; @(posedge clk); #1;
      level_load = 1'b0; respawn = 1'b0;
    end
  endtask

  task expect_pos;
    input [9:0] want_x;
    input [3:0] want_row;
    input [8*48-1:0] what;
    begin
      if (player_x !== want_x || player_row !== want_row) begin
        errors = errors + 1;
        $display("FAIL %0s: at (x=%0d,row=%0d) expected (x=%0d,row=%0d)",
                 what, player_x, player_row, want_x, want_row);
      end
    end
  endtask

  task expect_bit;
    input got, want;
    input [8*48-1:0] what;
    begin
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: %b expected %b", what, got, want);
      end
    end
  endtask

  integer k;

  initial begin
    lane_p = LANE_GRASS;
    repeat (2) @(posedge clk); #1;
    reset = 1'b0;
    expect_pos(START_X, START_ROW, "after reset");
    expect_bit(at_goal, 1'b0, "at_goal at start");
    expect_bit(carried_off, 1'b0, "carried_off on grass");

    // ---- requests without play_tick do nothing
    {req_u, req_d, req_l, req_r} = 4'b1111;
    repeat (20) @(posedge clk); #1;
    {req_u, req_d, req_l, req_r} = 4'b0000;
    expect_pos(START_X, START_ROW, "requests without play_tick");

    // ---- play_tick with no request does nothing on grass
    tick(4'b0000);
    expect_pos(START_X, START_ROW, "idle play_tick");

    // ---- bottom edge: hop down from row 14 is ignored
    tick(4'b0100);
    expect_pos(START_X, START_ROW, "hop down at bottom edge");

    // ---- one tile per hop in each direction
    tick(4'b1000); expect_pos(10'd320, 4'd13, "hop up");
    expect_bit(saw_new_row, 1'b1, "new_row on first visit to row 13");
    tick(4'b0100); expect_pos(10'd320, 4'd14, "hop down");
    expect_bit(saw_new_row, 1'b0, "no new_row going down");
    tick(4'b1000); expect_pos(10'd320, 4'd13, "hop up again");
    expect_bit(saw_new_row, 1'b0, "no new_row on a row already reached");
    tick(4'b0010); expect_pos(10'd288, 4'd13, "hop left");
    tick(4'b0001); expect_pos(10'd320, 4'd13, "hop right");

    // ---- priority: up beats left/right; down beats left/right; left beats right
    tick(4'b1011); expect_pos(10'd320, 4'd12, "up has priority");
    tick(4'b0111); expect_pos(10'd320, 4'd13, "down has priority over left/right");
    tick(4'b0011); expect_pos(10'd288, 4'd13, "left has priority over right");
    tick(4'b0001);

    // ---- left edge
    for (k = 0; k < 10; k = k + 1) tick(4'b0010);
    expect_pos(10'd0, 4'd13, "walk to the left edge");
    tick(4'b0010); expect_pos(10'd0, 4'd13, "hop left at x=0 ignored");
    // ---- right edge
    for (k = 0; k < 19; k = k + 1) tick(4'b0001);
    expect_pos(10'd608, 4'd13, "walk to the right edge");
    tick(4'b0001); expect_pos(10'd608, 4'd13, "hop right at x=608 ignored");
    tick(4'b0010); expect_pos(10'd576, 4'd13, "hop left from 608");
    tick(4'b0001); expect_pos(10'd608, 4'd13, "hop right from 576");

    // ---- climb to the top: new_row once for each of rows 12..0
    new_rows = 0;
    for (k = 0; k < 13; k = k + 1) tick(4'b1000);
    expect_pos(10'd608, 4'd0, "climb to the goal row");
    if (new_rows !== 12) begin
      // row 12 was already reached by the priority test above
      errors = errors + 1;
      $display("FAIL %0d new_row pulses on the climb, expected 12", new_rows);
    end
    expect_bit(at_goal, 1'b1, "at_goal on row 0");
    // ---- top edge
    tick(4'b1000); expect_pos(10'd608, 4'd0, "hop up at row 0 ignored");
    expect_bit(saw_new_row, 1'b0, "no new_row from an ignored hop");
    // hopping back and forth earns nothing
    new_rows = 0;
    for (k = 0; k < 5; k = k + 1) begin tick(4'b0100); tick(4'b1000); end
    if (new_rows !== 0) begin
      errors = errors + 1; $display("FAIL hopping back and forth gave %0d new_row", new_rows);
    end

    // ---- respawn: back to start, best_row kept (no score for rows again)
    pulse_respawn;
    expect_pos(START_X, START_ROW, "respawn");
    expect_bit(at_goal, 1'b0, "at_goal after respawn");
    new_rows = 0;
    for (k = 0; k < 14; k = k + 1) tick(4'b1000);
    if (new_rows !== 0) begin
      errors = errors + 1; $display("FAIL %0d new_row after respawn in the same level", new_rows);
    end

    // ---- level_load: best_row cleared, every row scores again
    pulse_level_load;
    expect_pos(START_X, START_ROW, "level_load + respawn");
    new_rows = 0;
    for (k = 0; k < 14; k = k + 1) tick(4'b1000);
    if (new_rows !== 14) begin
      errors = errors + 1; $display("FAIL %0d new_row after level_load, expected 14", new_rows);
    end

    // ---- reset from anywhere
    reset = 1'b1; @(posedge clk); #1; reset = 1'b0;
    expect_pos(START_X, START_ROW, "reset");

    if (errors == 0) $display("PASS tb_player_ctrl");
    else             $display("FAIL tb_player_ctrl");
    $finish;
  end
endmodule
`default_nettype wire
