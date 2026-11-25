// crossy_defs.vh -- shared constants and the occupied() lookup.
//
// Include this file INSIDE a module body, after the port list:
//     `include "crossy_defs.vh"
// Everything here is a localparam or a function, so each including module
// gets its own scoped copy. There is deliberately no include guard: a guard
// would hide the definitions from every module after the first one.
// This file has no `default_nettype lines: Verilog only allows that
// directive outside a module, and this file is always included inside one.
// The including .v file sets `default_nettype none before the module.

// ---------------------------------------------------------------- display
localparam [9:0]  H_START      = 10'd145;  // hCount of screen x = 0 (DESIGN 4)
localparam [9:0]  V_START      = 10'd35;   // vCount of screen y = 0
localparam [9:0]  SCREEN_W     = 10'd640;
localparam [9:0]  SCREEN_H     = 10'd480;
localparam [9:0]  VBLANK_START = 10'd516;  // first vCount after the visible lines

// ---------------------------------------------------------------- game states (DESIGN 7)
localparam [2:0] S_TITLE       = 3'd0;
localparam [2:0] S_PLAY        = 3'd1;
localparam [2:0] S_PAUSE       = 3'd2;
localparam [2:0] S_DEATH       = 3'd3;
localparam [2:0] S_LEVEL_CLEAR = 3'd4;
localparam [2:0] S_GAME_OVER   = 3'd5;
localparam [2:0] S_WIN         = 3'd6;

// ---------------------------------------------------------------- lane descriptor (DESIGN 5)
// {kind[25:24], dir[23], speed[22:20], pattern[19:0]}
localparam [1:0] K_GRASS = 2'd0;
localparam [1:0] K_ROAD  = 2'd1;
localparam [1:0] K_RIVER = 2'd2;
localparam [1:0] K_GOAL  = 2'd3;

localparam       DIR_RIGHT = 1'b0;
localparam       DIR_LEFT  = 1'b1;

localparam [25:0] LANE_GRASS = {K_GRASS, DIR_RIGHT, 3'd0, 20'h00000};
localparam [25:0] LANE_GOAL  = {K_GOAL,  DIR_RIGHT, 3'd0, 20'h00000};

// Pattern library (tunable). Bit i = tile i holds a car / log at offset 0.
localparam [19:0] CAR_A = 20'h00C03;   // two 2-tile cars, wide gaps
localparam [19:0] CAR_B = 20'h00707;   // two 3-tile trucks
localparam [19:0] CAR_C = 20'h30C03;   // three 2-tile cars, tighter gaps
localparam [19:0] LOG_A = 20'h03F3F;   // two 6-tile logs
localparam [19:0] LOG_B = 20'h0F0F0;   // two 4-tile logs
localparam [19:0] LOG_C = 20'h1C387;   // three 3-tile logs

// ---------------------------------------------------------------- colors (12-bit {R,G,B})
localparam [11:0] COL_BLACK     = 12'h000;
localparam [11:0] COL_GRASS     = 12'h3A3;
localparam [11:0] COL_ROAD      = 12'h444;
localparam [11:0] COL_CAR       = 12'hE22;
localparam [11:0] COL_WATER     = 12'h24C;
localparam [11:0] COL_LOG       = 12'h852;
localparam [11:0] COL_GOAL      = 12'hFC0;
localparam [11:0] COL_CHICKEN   = 12'hFFF;
localparam [11:0] COL_DEAD      = 12'hF00;
localparam [11:0] COL_TEXT      = 12'hFFF;
localparam [11:0] COL_GAME_OVER = 12'h400;
localparam [11:0] COL_WIN       = 12'h040;

// ---------------------------------------------------------------- shapes
localparam [4:0] BAND_TOP    = 5'd4;   // cars, logs and chicken: yt 4..27
localparam [4:0] BAND_BOTTOM = 5'd27;
localparam [9:0] BODY_LEFT   = 10'd4;  // chicken body: player_x+4 .. player_x+27
localparam [9:0] BODY_RIGHT  = 10'd27;
localparam [9:0] BODY_CENTER = 10'd16;

// ---------------------------------------------------------------- player
localparam [9:0] TILE      = 10'd32;
localparam [9:0] START_X   = 10'd320;
localparam [3:0] START_ROW = 4'd14;
localparam [3:0] GOAL_ROW  = 4'd0;
localparam [9:0] MAX_X     = 10'd608;  // rightmost tile's left edge
localparam [9:0] MAX_HOP_R = 10'd576;  // hop right allowed while player_x <= this
localparam [3:0] NUM_ROWS  = 4'd15;    // rows 0..14; row 15 is the unused 481st line

// ---------------------------------------------------------------- game rules (tunable)
localparam [1:0] START_LIVES   = 2'd3;
localparam [2:0] FIRST_LEVEL   = 3'd1;
localparam [2:0] LAST_LEVEL    = 3'd5;
localparam [6:0] HOLD_DEATH    = 7'd60;    // frames in DEATH (1 s)
localparam [6:0] HOLD_CLEAR    = 7'd120;   // frames in LEVEL_CLEAR (2 s)
localparam [5:0] FRAMES_PER_S  = 6'd60;    // frame_cnt counts 0 .. FRAMES_PER_S-1
// Per-level timer, two BCD digits {tens, ones}
localparam [7:0] TIME_L1 = 8'h60;
localparam [7:0] TIME_L2 = 8'h60;
localparam [7:0] TIME_L3 = 8'h50;
localparam [7:0] TIME_L4 = 8'h45;
localparam [7:0] TIME_L5 = 8'h40;

// ---------------------------------------------------------------- input
localparam integer DEBOUNCE_BITS = 21;     // 2^21 cycles at 100 MHz ~ 21 ms

// ---------------------------------------------------------------- shared lookup (DESIGN 5)
// Is there a car/log at screen position px in a lane with this pattern and
// offset? offset and px must both be 0..639.
function occupied;
  input [19:0] pattern;
  input [9:0]  offset;
  input [9:0]  px;
  reg   [9:0]  u;
  begin
    u = (px >= offset) ? (px - offset) : (px + SCREEN_W - offset);
    occupied = pattern[u[9:5]];   // u[9:5] is 0..19
  end
endfunction
