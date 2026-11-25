`timescale 1ns / 1ps
`default_nettype none
// player_ctrl -- chicken position, hops, furthest row reached (DESIGN 8.2).
// At most one action per play_tick, in priority order: hop (up, down, left,
// right), else ride the log, else snap to the tile grid. A hop into a screen
// edge is ignored (G-3) and falls through to the ride/snap step.
module player_ctrl(
  input  wire        clk,
  input  wire        reset,
  input  wire        play_tick,
  input  wire        respawn,
  input  wire        level_load,
  input  wire        req_u, req_d, req_l, req_r,
  input  wire [25:0] lane_p,             // lane under the chicken
  output reg  [9:0]  player_x,           // 0..608, pixels
  output reg  [3:0]  player_row,         // 0..14
  output wire        at_goal,            // player_row == 0
  output wire        new_row,            // first time on this row this level
  output wire        carried_off         // log would push the chicken past an edge
);
`include "crossy_defs.vh"

  reg [3:0] best_row;                    // lowest row number reached this level

  wire [1:0] kind     = lane_p[25:24];
  wire       dir      = lane_p[23];
  wire [9:0] speed    = {7'd0, lane_p[22:20]};
  wire       on_river = (kind == K_RIVER);
  wire [9:0] snapped  = {player_x[9:5] + {4'd0, player_x[4]}, 5'd0};   // nearest tile

  wire hop_up = req_u && (player_row != GOAL_ROW);

  assign at_goal     = (player_row == GOAL_ROW);
  // High only during the play_tick on which a forward hop lands on a row
  // above best_row; game_fsm adds 10 on play_tick && new_row.
  assign new_row     = play_tick && hop_up && ((player_row - 4'd1) < best_row);
  // The log would carry the chicken past a screen edge on this tick (G-6).
  assign carried_off = on_river &&
                       ((dir == DIR_LEFT) ? (player_x < speed)
                                          : (player_x + speed > MAX_X));

  always @(posedge clk) begin
    if (reset || respawn) begin
      player_x   <= START_X;
      player_row <= START_ROW;
    end else if (play_tick) begin
      if      (hop_up)                              player_row <= player_row - 4'd1;
      else if (req_d && player_row != START_ROW)    player_row <= player_row + 4'd1;
      else if (req_l && player_x >= TILE)           player_x   <= player_x - TILE;
      else if (req_r && player_x <= MAX_HOP_R)      player_x   <= player_x + TILE;
      else if (on_river && !carried_off)            player_x   <= (dir == DIR_LEFT) ? player_x - speed
                                                                                    : player_x + speed;
      else if (!on_river)                           player_x   <= snapped;
    end
  end

  always @(posedge clk) begin
    if (reset || level_load)
      best_row <= START_ROW;
    else if (new_row)
      best_row <= player_row - 4'd1;
  end

endmodule
`default_nettype wire
