`timescale 1ns / 1ps
`default_nettype none
// tb_lane_engine -- for every level: lane_r matches level_rom for each row,
// every row's offset follows an integer model (x + speed) mod 640 moving
// right and (x - speed) mod 640 moving left for 700 ticks (so every moving
// row crosses the wrap point), nothing moves without play_tick, level_load
// and reset clear the offsets, lane_p/off_p are the chicken row's values one
// cycle later, and row 15 reads as grass with offset 0.
module tb_lane_engine;
`include "crossy_defs.vh"

  localparam integer TICKS = 700;

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg play_tick = 1'b0, level_load = 1'b0;
  reg [2:0] level = 3'd1;
  reg [3:0] row_r = 4'd0, row_p = 4'd0;
  wire [25:0] lane_r, lane_p;
  wire [9:0]  off_r, off_p;

  lane_engine dut(.clk(clk), .reset(reset), .play_tick(play_tick),
                  .level_load(level_load), .level(level),
                  .row_r(row_r), .row_p(row_p),
                  .lane_r(lane_r), .lane_p(lane_p), .off_r(off_r), .off_p(off_p));

  // Reference descriptor for row_r (level_rom has its own testbench).
  wire [25:0] ref_lane;
  level_rom ref_rom(.level(level), .row(row_r), .lane(ref_lane));

  integer errors = 0;
  integer expected [0:14];
  integer r, t, lv, spd;
  integer wraps_right, wraps_left;
  reg [25:0] lanes_seen [0:14];

  // Read every row through the lane_r/off_r port and compare to the model.
  task check_all;
    input [8*32-1:0] what;
    begin
      for (r = 0; r < 15; r = r + 1) begin
        row_r = r[3:0]; #1;
        if (lane_r !== ref_lane) begin
          errors = errors + 1;
          $display("FAIL %0s: level %0d row %0d lane_r %h, level_rom says %h", what, level, r, lane_r, ref_lane);
        end
        if (off_r !== expected[r]) begin
          errors = errors + 1;
          if (errors < 30)
            $display("FAIL %0s: level %0d row %0d offset %0d, expected %0d", what, level, r, off_r, expected[r]);
        end
      end
    end
  endtask

  task do_tick;
    begin
      @(negedge clk); play_tick = 1'b1;
      @(negedge clk); play_tick = 1'b0;
      @(negedge clk);
    end
  endtask

  task do_level_load;
    begin
      @(negedge clk); level_load = 1'b1;
      @(negedge clk); level_load = 1'b0;
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    reset = 1'b0;

    for (lv = 1; lv <= 5; lv = lv + 1) begin
      level = lv[2:0];
      do_level_load;
      for (r = 0; r < 15; r = r + 1) expected[r] = 0;
      check_all("after level_load");
      for (r = 0; r < 15; r = r + 1) begin
        row_r = r[3:0]; #1; lanes_seen[r] = lane_r;
      end

      wraps_right = 0; wraps_left = 0;
      for (t = 0; t < TICKS; t = t + 1) begin
        do_tick;
        for (r = 0; r < 15; r = r + 1) begin
          spd = lanes_seen[r][22:20];
          if (lanes_seen[r][23] == DIR_RIGHT) begin
            if (expected[r] + spd >= 640) wraps_right = wraps_right + 1;
            expected[r] = (expected[r] + spd) % 640;
          end else begin
            if (expected[r] - spd < 0 && spd != 0) wraps_left = wraps_left + 1;
            expected[r] = (expected[r] - spd + 640) % 640;
          end
        end
        check_all("after a tick");
      end
      $display("level %0d: %0d right wraps, %0d left wraps checked", lv, wraps_right, wraps_left);
      if (lv == 1 && (wraps_right == 0 || wraps_left == 0)) begin
        errors = errors + 1;
        $display("FAIL level 1 never crossed the wrap point in both directions");
      end

      // nothing moves without play_tick
      repeat (100) @(negedge clk);
      check_all("100 clocks without play_tick");

      // chicken-row port: registered copy of the same row
      for (r = 0; r < 16; r = r + 1) begin
        @(negedge clk); row_p = r[3:0];
        @(negedge clk);
        row_r = r[3:0]; #1;
        if (lane_p !== lane_r || off_p !== off_r) begin
          errors = errors + 1;
          $display("FAIL level %0d row_p %0d: lane_p/off_p %h/%0d, lane_r/off_r %h/%0d",
                   lv, r, lane_p, off_p, lane_r, off_r);
        end
      end
    end

    // row 15 is grass with offset 0 on both ports
    row_r = 4'd15; row_p = 4'd15;
    @(negedge clk); @(negedge clk);
    if (lane_r !== LANE_GRASS || off_r !== 10'd0 || lane_p !== LANE_GRASS || off_p !== 10'd0) begin
      errors = errors + 1; $display("FAIL row 15 is not grass at offset 0");
    end

    // registered lane_p: lags row_p by exactly one clock
    level = 3'd1;
    @(negedge clk); row_p = 4'd14;
    @(negedge clk); row_p = 4'd10;
    #1;
    if (lane_p[25:24] !== K_GRASS) begin
      errors = errors + 1; $display("FAIL lane_p changed before the clock edge");
    end
    @(negedge clk);
    if (lane_p[25:24] !== K_ROAD) begin
      errors = errors + 1; $display("FAIL lane_p did not follow row_p after one clock");
    end

    // reset clears offsets
    repeat (37) do_tick;
    @(negedge clk); reset = 1'b1; @(negedge clk); reset = 1'b0;
    for (r = 0; r < 15; r = r + 1) expected[r] = 0;
    check_all("after reset");

    if (errors == 0) $display("PASS tb_lane_engine");
    else             $display("FAIL tb_lane_engine");
    $finish;
  end
endmodule
`default_nettype wire
