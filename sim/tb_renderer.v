`timescale 1ns / 1ps
`default_nettype none
// tb_renderer -- pixel colors for every lane kind, the car/log band, the
// chicken box edges, draw priority, the per-state screens, blanking, and the
// coordinate outputs.
module tb_renderer;
`include "crossy_defs.vh"

  reg         bright;
  reg  [9:0]  hCount, vCount;
  reg  [2:0]  state;
  reg  [25:0] lane_r;
  reg  [9:0]  off_r, player_x;
  reg  [3:0]  player_row;
  reg         text_on;
  wire [3:0]  row_r;
  wire [9:0]  x, y;
  wire [11:0] rgb;

  renderer dut(.bright(bright), .hCount(hCount), .vCount(vCount), .state(state),
               .lane_r(lane_r), .off_r(off_r), .player_x(player_x),
               .player_row(player_row), .text_on(text_on),
               .row_r(row_r), .x(x), .y(y), .rgb(rgb));

  integer errors = 0;

  // Put the beam on screen pixel (sx, sy).
  task at;
    input integer sx, sy;
    begin
      hCount = sx + 145;
      vCount = sy + 35;
      #1;
    end
  endtask

  task expect_rgb;
    input [11:0]  want;
    input [8*40-1:0] what;
    begin
      if (rgb !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: x=%0d y=%0d state=%0d rgb=%h expected %h", what, x, y, state, rgb, want);
      end
    end
  endtask

  // Road lane with a single car on tile 10 (x 320..351) at offset 0.
  localparam [25:0] ROAD1  = {K_ROAD,  DIR_LEFT,  3'd1, 20'h00400};
  localparam [25:0] RIVER1 = {K_RIVER, DIR_RIGHT, 3'd1, 20'h00400};

  integer sx, sy;

  initial begin
    bright = 1'b1; state = S_PLAY; lane_r = LANE_GRASS; off_r = 10'd0;
    player_x = 10'd320; player_row = 4'd14; text_on = 1'b0;

    // ---- coordinate outputs
    at(0, 0);
    if (x !== 10'd0 || y !== 10'd0 || row_r !== 4'd0) begin
      errors = errors + 1; $display("FAIL origin maps to x=%0d y=%0d row=%0d", x, y, row_r);
    end
    at(639, 479);
    if (x !== 10'd639 || y !== 10'd479 || row_r !== 4'd14) begin
      errors = errors + 1; $display("FAIL corner maps to x=%0d y=%0d row=%0d", x, y, row_r);
    end
    for (sy = 0; sy < 480; sy = sy + 1) begin
      at(100, sy);
      if (row_r !== sy / 32) begin
        errors = errors + 1; $display("FAIL y=%0d gives row_r %0d", sy, row_r);
      end
    end

    // ---- blanking: black whenever bright is low, whatever else is true
    bright = 1'b0; text_on = 1'b1; state = S_WIN;
    at(10, 10);  expect_rgb(COL_BLACK, "bright=0 with text");
    text_on = 1'b0; state = S_PLAY; lane_r = ROAD1;
    at(330, 16); expect_rgb(COL_BLACK, "bright=0 over a car");
    bright = 1'b1;
    // the 481st line (y = 480) is black even though bright is high
    lane_r = LANE_GOAL;
    at(5, 480);  expect_rgb(COL_BLACK, "481st line");

    // ---- lane backgrounds (beam on the chicken-free row 3)
    lane_r = LANE_GRASS; at(5, 3*32 + 16);   expect_rgb(COL_GRASS, "grass");
    lane_r = LANE_GOAL;  at(5, 0*32 + 16);   expect_rgb(COL_GOAL,  "goal");
    lane_r = ROAD1;      at(5, 3*32 + 16);   expect_rgb(COL_ROAD,  "road");
    lane_r = RIVER1;     at(5, 3*32 + 16);   expect_rgb(COL_WATER, "water");

    // ---- car band: yt 4..27 only, x 320..351 only
    lane_r = ROAD1;
    at(330, 3*32 + 3);  expect_rgb(COL_ROAD, "car band yt=3");
    at(330, 3*32 + 4);  expect_rgb(COL_CAR,  "car band yt=4");
    at(330, 3*32 + 27); expect_rgb(COL_CAR,  "car band yt=27");
    at(330, 3*32 + 28); expect_rgb(COL_ROAD, "car band yt=28");
    at(319, 3*32 + 16); expect_rgb(COL_ROAD, "left of car");
    at(320, 3*32 + 16); expect_rgb(COL_CAR,  "car left edge");
    at(351, 3*32 + 16); expect_rgb(COL_CAR,  "car right edge");
    at(352, 3*32 + 16); expect_rgb(COL_ROAD, "right of car");
    // offset shifts the car right
    off_r = 10'd5;
    at(324, 3*32 + 16); expect_rgb(COL_ROAD, "shifted car, old left edge");
    at(325, 3*32 + 16); expect_rgb(COL_CAR,  "shifted car, new left edge");
    at(356, 3*32 + 16); expect_rgb(COL_CAR,  "shifted car, new right edge");
    off_r = 10'd0;
    lane_r = RIVER1;
    at(330, 3*32 + 16); expect_rgb(COL_LOG,  "log");
    at(330, 3*32 + 2);  expect_rgb(COL_WATER, "above log band");

    // ---- chicken: x player_x+4 .. +27, yt 4..27, only on player_row
    lane_r = LANE_GRASS; player_x = 10'd320; player_row = 4'd14;
    at(323, 14*32 + 16); expect_rgb(COL_GRASS,   "left of chicken");
    at(324, 14*32 + 16); expect_rgb(COL_CHICKEN, "chicken left edge");
    at(347, 14*32 + 16); expect_rgb(COL_CHICKEN, "chicken right edge");
    at(348, 14*32 + 16); expect_rgb(COL_GRASS,   "right of chicken");
    at(330, 14*32 + 3);  expect_rgb(COL_GRASS,   "above chicken");
    at(330, 14*32 + 4);  expect_rgb(COL_CHICKEN, "chicken top");
    at(330, 14*32 + 27); expect_rgb(COL_CHICKEN, "chicken bottom");
    at(330, 14*32 + 28); expect_rgb(COL_GRASS,   "below chicken");
    at(330, 13*32 + 16); expect_rgb(COL_GRASS,   "same x, other row");
    // chicken drawn over a car, red in DEATH
    lane_r = ROAD1;
    at(330, 14*32 + 16); expect_rgb(COL_CHICKEN, "chicken over car");
    state = S_DEATH;
    at(330, 14*32 + 16); expect_rgb(COL_DEAD,    "dead chicken");
    at(350, 14*32 + 16); expect_rgb(COL_CAR,     "car beside dead chicken");
    // chicken at the right screen edge
    state = S_PLAY; lane_r = LANE_GRASS; player_x = 10'd608;
    at(612, 14*32 + 16); expect_rgb(COL_CHICKEN, "chicken at x=608, left edge");
    at(635, 14*32 + 16); expect_rgb(COL_CHICKEN, "chicken at x=608, right edge");
    at(636, 14*32 + 16); expect_rgb(COL_GRASS,   "chicken at x=608, beyond");
    player_x = 10'd320;

    // ---- per-state screens
    lane_r = ROAD1;
    state = S_TITLE;       at(330, 14*32 + 16); expect_rgb(COL_BLACK,     "TITLE is black");
    state = S_GAME_OVER;   at(330, 14*32 + 16); expect_rgb(COL_GAME_OVER, "GAME_OVER background");
    state = S_WIN;         at(330, 14*32 + 16); expect_rgb(COL_WIN,       "WIN background");
    state = S_PAUSE;       at(330, 14*32 + 16); expect_rgb(COL_CHICKEN,   "PAUSE shows playfield");
                           at(330, 3*32 + 16);  expect_rgb(COL_CAR,       "PAUSE shows cars");
    state = S_LEVEL_CLEAR; at(330, 3*32 + 16);  expect_rgb(COL_CAR,       "LEVEL_CLEAR shows playfield");

    // ---- text is drawn over everything that is visible
    text_on = 1'b1;
    state = S_TITLE;     at(200, 150); expect_rgb(COL_TEXT, "text on TITLE");
    state = S_GAME_OVER; at(200, 150); expect_rgb(COL_TEXT, "text on GAME_OVER");
    state = S_PAUSE;     at(330, 14*32 + 16); expect_rgb(COL_TEXT, "text over chicken");
    text_on = 1'b0;

    if (errors == 0) $display("PASS tb_renderer");
    else             $display("FAIL tb_renderer");
    $finish;
  end
endmodule
`default_nettype wire
