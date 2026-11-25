`timescale 1ns / 1ps
`default_nettype none
// collision -- hit by a car / standing in water, from the chicken's position
// in its own row (DESIGN 8.3). Three sample points on the 24 px body: left
// edge (x+4), right edge (x+27) and center (x+16). Cars kill on any overlap
// of the edges; a log only has to be under the center.
// The rule is combinational and registered once: its inputs change only at a
// frame tick and game_fsm samples the result at the next one.
module collision(
  input  wire        clk,
  input  wire        reset,
  input  wire [25:0] lane_p,           // lane under the chicken
  input  wire [9:0]  off_p,
  input  wire [9:0]  player_x,
  output reg         hit_car,
  output reg         in_water
);
`include "crossy_defs.vh"

  wire [1:0]  kind    = lane_p[25:24];
  wire [19:0] pattern = lane_p[19:0];

  wire left   = occupied(pattern, off_p, player_x + BODY_LEFT);
  wire right  = occupied(pattern, off_p, player_x + BODY_RIGHT);
  wire center = occupied(pattern, off_p, player_x + BODY_CENTER);

  wire hit_now   = (kind == K_ROAD)  && (left || right);
  wire water_now = (kind == K_RIVER) && !center;

  always @(posedge clk) begin
    if (reset) begin
      hit_car  <= 1'b0;
      in_water <= 1'b0;
    end else begin
      hit_car  <= hit_now;
      in_water <= water_now;
    end
  end

endmodule
`default_nettype wire
