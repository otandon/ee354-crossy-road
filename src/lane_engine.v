`timescale 1ns / 1ps
`default_nettype none
// lane_engine -- one scroll offset per row, advanced every play_tick
// (DESIGN 6 and 8.1), plus the descriptor/offset lookups for the row being
// drawn (lane_r/off_r, combinational) and the chicken's row (lane_p/off_p,
// registered to shorten the path into collision).
//
// 15 level_rom instances, one per row with a constant row input, so each
// reduces to a few gates. Row 15 (the unused 481st line) reads as grass with
// offset 0.
module lane_engine(
  input  wire        clk,
  input  wire        reset,
  input  wire        play_tick,
  input  wire        level_load,
  input  wire [2:0]  level,
  input  wire [3:0]  row_r,            // row being drawn
  input  wire [3:0]  row_p,            // chicken's row
  output reg  [25:0] lane_r,
  output reg  [25:0] lane_p,
  output reg  [9:0]  off_r,
  output reg  [9:0]  off_p
);
`include "crossy_defs.vh"

  // Flattened per-row data: row i occupies lanes[26*i +: 26], offs[10*i +: 10].
  wire [15*26-1:0] lanes;
  wire [15*10-1:0] offs;

  genvar i;
  generate
    for (i = 0; i < 15; i = i + 1) begin : g_row
      localparam [3:0] ROW = i;
      wire [25:0] lane;
      reg  [9:0]  offset;

      level_rom rom(.level(level), .row(ROW), .lane(lane));

      wire       dir   = lane[23];
      wire [9:0] speed = {7'd0, lane[22:20]};

      // Both directions wrap at 640 (DESIGN 8.1).
      always @(posedge clk) begin
        if (reset || level_load)
          offset <= 10'd0;
        else if (play_tick) begin
          if (dir == DIR_RIGHT)
            offset <= (offset + speed >= SCREEN_W) ? (offset + speed - SCREEN_W)
                                                   : (offset + speed);
          else
            offset <= (offset < speed) ? (offset + SCREEN_W - speed)
                                       : (offset - speed);
        end
      end

      assign lanes[26*i +: 26] = lane;
      assign offs[10*i +: 10]  = offset;
    end
  endgenerate

  // ---------------------------------------------------------- row being drawn
  always @(*) begin
    lane_r = LANE_GRASS;
    off_r  = 10'd0;
    if (row_r < NUM_ROWS) begin
      lane_r = lanes[row_r * 9'd26 +: 26];
      off_r  = offs[row_r * 8'd10 +: 10];
    end
  end

  // ---------------------------------------------------------- chicken's row
  reg [25:0] lane_p_next;
  reg [9:0]  off_p_next;
  always @(*) begin
    lane_p_next = LANE_GRASS;
    off_p_next  = 10'd0;
    if (row_p < NUM_ROWS) begin
      lane_p_next = lanes[row_p * 9'd26 +: 26];
      off_p_next  = offs[row_p * 8'd10 +: 10];
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      lane_p <= LANE_GRASS;
      off_p  <= 10'd0;
    end else begin
      lane_p <= lane_p_next;
      off_p  <= off_p_next;
    end
  end

endmodule
`default_nettype wire
