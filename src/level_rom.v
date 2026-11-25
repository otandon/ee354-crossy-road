`timescale 1ns / 1ps
`default_nettype none
// level_rom -- (level, row) -> 26-bit lane descriptor {kind, dir, speed, pattern}.
// Purely combinational. Rows without an entry are grass. Layouts, patterns
// and speeds are tunable (DESIGN 5).
//
// Direction rule: odd rows move right (DIR_RIGHT), even rows move left.
module level_rom(
  input  wire [2:0]  level,
  input  wire [3:0]  row,
  output reg  [25:0] lane
);
`include "crossy_defs.vh"

  // ---------------------------------------------------------- speeds (tunable)
  // Pixels per frame, 0..4.
  localparam [2:0] L1_ROAD  = 3'd1;
  localparam [2:0] L1_RIVER = 3'd1;

  always @(*) begin
    lane = LANE_GRASS;
    case ({level, row})
      // ------------------------------------------------ level 1
      //  row  0 1 2 3 4 5 6 7 8 9 10 11 12 13 14
      //       Y G G G G W G G G G R  G  R  G  G
      {3'd1, 4'd0 }: lane = LANE_GOAL;
      {3'd1, 4'd5 }: lane = {K_RIVER, DIR_RIGHT, L1_RIVER, LOG_A};
      {3'd1, 4'd10}: lane = {K_ROAD,  DIR_LEFT,  L1_ROAD,  CAR_A};
      {3'd1, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L1_ROAD,  CAR_B};
      default:       lane = LANE_GRASS;
    endcase
  end

endmodule
`default_nettype wire
