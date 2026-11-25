`timescale 1ns / 1ps
`default_nettype none
// level_rom -- (level, row) -> 26-bit lane descriptor {kind, dir, speed, pattern}.
// Purely combinational. Rows without an entry are grass; levels outside 1..5
// are all grass. Layouts, patterns and speeds are tunable (DESIGN 5).
//
// Direction rule: odd rows move right, even rows move left.
// "Alternating by row" speeds: even rows take the first value, odd rows the
// second.
//
//  row      0 1 2 3 4 5 6 7 8 9 10 11 12 13 14     roads rivers
//  Level 1  Y G G G G W G G G G R  G  R  G  G        2     1
//  Level 2  Y G G W W G G G R R G  R  R  G  G        4     2
//  Level 3  Y G W W W W G R R G R  R  R  G  G        5     4
//  Level 4  Y G W W W W G R R R G  R  R  R  G        6     4
//  Level 5  Y W W W W W G R R R R  R  R  R  G        7     5
module level_rom(
  input  wire [2:0]  level,
  input  wire [3:0]  row,
  output reg  [25:0] lane
);
`include "crossy_defs.vh"

  // ---------------------------------------------------------- speeds (tunable)
  // Pixels per frame, 0..4. *_EVEN applies to even rows, *_ODD to odd rows.
  localparam [2:0] L1_ROAD       = 3'd1;
  localparam [2:0] L1_RIVER      = 3'd1;
  localparam [2:0] L2_ROAD_EVEN  = 3'd1;
  localparam [2:0] L2_ROAD_ODD   = 3'd2;
  localparam [2:0] L2_RIVER      = 3'd1;
  localparam [2:0] L3_ROAD       = 3'd2;
  localparam [2:0] L3_RIVER      = 3'd2;
  localparam [2:0] L4_ROAD_EVEN  = 3'd2;
  localparam [2:0] L4_ROAD_ODD   = 3'd3;
  localparam [2:0] L4_RIVER      = 3'd2;
  localparam [2:0] L5_ROAD_EVEN  = 3'd3;
  localparam [2:0] L5_ROAD_ODD   = 3'd4;
  localparam [2:0] L5_RIVER      = 3'd3;

  always @(*) begin
    lane = LANE_GRASS;
    case ({level, row})
      // ------------------------------------------------ level 1
      {3'd1, 4'd0 }: lane = LANE_GOAL;
      {3'd1, 4'd5 }: lane = {K_RIVER, DIR_RIGHT, L1_RIVER,     LOG_A};
      {3'd1, 4'd10}: lane = {K_ROAD,  DIR_LEFT,  L1_ROAD,      CAR_A};
      {3'd1, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L1_ROAD,      CAR_B};
      // ------------------------------------------------ level 2
      {3'd2, 4'd0 }: lane = LANE_GOAL;
      {3'd2, 4'd3 }: lane = {K_RIVER, DIR_RIGHT, L2_RIVER,     LOG_A};
      {3'd2, 4'd4 }: lane = {K_RIVER, DIR_LEFT,  L2_RIVER,     LOG_B};
      {3'd2, 4'd8 }: lane = {K_ROAD,  DIR_LEFT,  L2_ROAD_EVEN, CAR_A};
      {3'd2, 4'd9 }: lane = {K_ROAD,  DIR_RIGHT, L2_ROAD_ODD,  CAR_A};
      {3'd2, 4'd11}: lane = {K_ROAD,  DIR_RIGHT, L2_ROAD_ODD,  CAR_B};
      {3'd2, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L2_ROAD_EVEN, CAR_B};
      // ------------------------------------------------ level 3
      {3'd3, 4'd0 }: lane = LANE_GOAL;
      {3'd3, 4'd2 }: lane = {K_RIVER, DIR_LEFT,  L3_RIVER,     LOG_B};
      {3'd3, 4'd3 }: lane = {K_RIVER, DIR_RIGHT, L3_RIVER,     LOG_B};
      {3'd3, 4'd4 }: lane = {K_RIVER, DIR_LEFT,  L3_RIVER,     LOG_B};
      {3'd3, 4'd5 }: lane = {K_RIVER, DIR_RIGHT, L3_RIVER,     LOG_B};
      {3'd3, 4'd7 }: lane = {K_ROAD,  DIR_RIGHT, L3_ROAD,      CAR_A};
      {3'd3, 4'd8 }: lane = {K_ROAD,  DIR_LEFT,  L3_ROAD,      CAR_B};
      {3'd3, 4'd10}: lane = {K_ROAD,  DIR_LEFT,  L3_ROAD,      CAR_A};
      {3'd3, 4'd11}: lane = {K_ROAD,  DIR_RIGHT, L3_ROAD,      CAR_B};
      {3'd3, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L3_ROAD,      CAR_A};
      // ------------------------------------------------ level 4
      {3'd4, 4'd0 }: lane = LANE_GOAL;
      {3'd4, 4'd2 }: lane = {K_RIVER, DIR_LEFT,  L4_RIVER,     LOG_B};
      {3'd4, 4'd3 }: lane = {K_RIVER, DIR_RIGHT, L4_RIVER,     LOG_C};
      {3'd4, 4'd4 }: lane = {K_RIVER, DIR_LEFT,  L4_RIVER,     LOG_B};
      {3'd4, 4'd5 }: lane = {K_RIVER, DIR_RIGHT, L4_RIVER,     LOG_C};
      {3'd4, 4'd7 }: lane = {K_ROAD,  DIR_RIGHT, L4_ROAD_ODD,  CAR_C};
      {3'd4, 4'd8 }: lane = {K_ROAD,  DIR_LEFT,  L4_ROAD_EVEN, CAR_B};
      {3'd4, 4'd9 }: lane = {K_ROAD,  DIR_RIGHT, L4_ROAD_ODD,  CAR_A};
      {3'd4, 4'd11}: lane = {K_ROAD,  DIR_RIGHT, L4_ROAD_ODD,  CAR_C};
      {3'd4, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L4_ROAD_EVEN, CAR_B};
      {3'd4, 4'd13}: lane = {K_ROAD,  DIR_RIGHT, L4_ROAD_ODD,  CAR_A};
      // ------------------------------------------------ level 5
      {3'd5, 4'd0 }: lane = LANE_GOAL;
      {3'd5, 4'd1 }: lane = {K_RIVER, DIR_RIGHT, L5_RIVER,     LOG_C};
      {3'd5, 4'd2 }: lane = {K_RIVER, DIR_LEFT,  L5_RIVER,     LOG_B};
      {3'd5, 4'd3 }: lane = {K_RIVER, DIR_RIGHT, L5_RIVER,     LOG_C};
      {3'd5, 4'd4 }: lane = {K_RIVER, DIR_LEFT,  L5_RIVER,     LOG_B};
      {3'd5, 4'd5 }: lane = {K_RIVER, DIR_RIGHT, L5_RIVER,     LOG_C};
      {3'd5, 4'd7 }: lane = {K_ROAD,  DIR_RIGHT, L5_ROAD_ODD,  CAR_C};
      {3'd5, 4'd8 }: lane = {K_ROAD,  DIR_LEFT,  L5_ROAD_EVEN, CAR_B};
      {3'd5, 4'd9 }: lane = {K_ROAD,  DIR_RIGHT, L5_ROAD_ODD,  CAR_C};
      {3'd5, 4'd10}: lane = {K_ROAD,  DIR_LEFT,  L5_ROAD_EVEN, CAR_A};
      {3'd5, 4'd11}: lane = {K_ROAD,  DIR_RIGHT, L5_ROAD_ODD,  CAR_C};
      {3'd5, 4'd12}: lane = {K_ROAD,  DIR_LEFT,  L5_ROAD_EVEN, CAR_B};
      {3'd5, 4'd13}: lane = {K_ROAD,  DIR_RIGHT, L5_ROAD_ODD,  CAR_C};
      default:       lane = LANE_GRASS;
    endcase
  end

endmodule
`default_nettype wire
