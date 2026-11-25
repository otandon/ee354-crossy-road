`timescale 1ns / 1ps
`default_nettype none
// renderer -- color of the current VGA pixel (replaces skeleton vga_bitchange).
// Combinational, like vga_bitchange. Draw priority, highest first:
// blanking, overlay text, full-screen state backgrounds, chicken, car/log,
// lane background (DESIGN 4 and 8.4).
module renderer(
  input  wire        bright,
  input  wire [9:0]  hCount, vCount,
  input  wire [2:0]  state,
  input  wire [25:0] lane_r,          // descriptor of the row being drawn
  input  wire [9:0]  off_r,           // scroll offset of the row being drawn
  input  wire [9:0]  player_x,
  input  wire [3:0]  player_row,
  input  wire        text_on,         // from text_overlay
  output wire [3:0]  row_r,           // y[8:5], to lane_engine
  output wire [9:0]  x, y,            // screen coordinates, to text_overlay
  output reg  [11:0] rgb              // {R,G,B}
);
`include "crossy_defs.vh"

  // ---------------------------------------------------------- coordinates
  assign x = hCount - H_START;        // 0..639 while bright
  assign y = vCount - V_START;        // 0..480 while bright
  wire       visible = bright && (y < SCREEN_H);   // drop the 481st line
  wire [3:0] row     = y[8:5];        // tile row 0..14
  wire [4:0] yt      = y[4:0];        // pixel row inside the tile
  assign row_r = row;

  // ---------------------------------------------------------- lane fields
  wire [1:0]  kind_r    = lane_r[25:24];
  wire [19:0] pattern_r = lane_r[19:0];

  // ---------------------------------------------------------- shapes
  wire band    = (yt >= BAND_TOP) && (yt <= BAND_BOTTOM);
  wire obj     = band && occupied(pattern_r, off_r, x);
  wire chicken = band && (row == player_row) &&
                 (x >= player_x + BODY_LEFT) && (x <= player_x + BODY_RIGHT);

  // ---------------------------------------------------------- color
  always @(*) begin
    rgb = COL_BLACK;
    if (!visible)                  rgb = COL_BLACK;
    else if (text_on)              rgb = COL_TEXT;
    else if (state == S_TITLE)     rgb = COL_BLACK;
    else if (state == S_GAME_OVER) rgb = COL_GAME_OVER;
    else if (state == S_WIN)       rgb = COL_WIN;
    else if (chicken)              rgb = (state == S_DEATH) ? COL_DEAD : COL_CHICKEN;
    else if (obj)                  rgb = (kind_r == K_ROAD) ? COL_CAR : COL_LOG;
    else begin
      case (kind_r)
        K_GRASS: rgb = COL_GRASS;
        K_ROAD:  rgb = COL_ROAD;
        K_RIVER: rgb = COL_WATER;
        K_GOAL:  rgb = COL_GOAL;
        default: rgb = COL_GRASS;
      endcase
    end
  end

endmodule
`default_nettype wire
