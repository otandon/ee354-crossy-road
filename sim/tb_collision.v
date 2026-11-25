`timescale 1ns / 1ps
`default_nettype none
// tb_collision -- DESIGN 12: a car touching only the left sample point, only
// the right one, narrowly missing; the chicken centered on a log end and just
// off it; offsets and the wrap point; grass/goal never hit; the result is
// registered (one clock late).
module tb_collision;
`include "crossy_defs.vh"

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg [25:0] lane_p = 26'd0;
  reg [9:0]  off_p = 10'd0, player_x = 10'd0;
  wire hit_car, in_water;

  collision dut(.clk(clk), .reset(reset), .lane_p(lane_p), .off_p(off_p),
                .player_x(player_x), .hit_car(hit_car), .in_water(in_water));

  integer errors = 0;

  // Apply inputs, let one clock register the result, then check.
  task probe;
    input [25:0] lane;
    input [9:0]  off;
    input [9:0]  px;
    input        want_hit, want_water;
    input [8*48-1:0] what;
    begin
      @(negedge clk);
      lane_p = lane; off_p = off; player_x = px;
      @(negedge clk);
      if (hit_car !== want_hit || in_water !== want_water) begin
        errors = errors + 1;
        $display("FAIL %0s: x=%0d off=%0d hit=%b water=%b, expected hit=%b water=%b",
                 what, px, off, hit_car, in_water, want_hit, want_water);
      end
    end
  endtask

  // A car on tile 9 only (x 288..319 at offset 0).
  localparam [25:0] CAR9  = {K_ROAD,  DIR_LEFT,  3'd1, 20'h00200};
  // A car on tile 11 only (x 352..383).
  localparam [25:0] CAR11 = {K_ROAD,  DIR_LEFT,  3'd1, 20'h00800};
  // A log on tiles 4..9 (x 128..319).
  localparam [25:0] LOG49 = {K_RIVER, DIR_RIGHT, 3'd1, 20'h003F0};

  initial begin
    @(negedge clk); @(negedge clk);
    reset = 1'b0;

    // ---- cars: sample points are x+4 (left) and x+27 (right)
    probe(CAR9, 10'd0, 10'd300, 1'b1, 1'b0, "car under the left sample point only");
    probe(CAR9, 10'd0, 10'd315, 1'b1, 1'b0, "left sample point on the car's last pixel");
    probe(CAR9, 10'd0, 10'd316, 1'b0, 1'b0, "car just left of the chicken");
    probe(CAR11, 10'd0, 10'd330, 1'b1, 1'b0, "car under the right sample point only");
    probe(CAR11, 10'd0, 10'd325, 1'b1, 1'b0, "right sample point on the car's first pixel");
    probe(CAR11, 10'd0, 10'd324, 1'b0, 1'b0, "car just right of the chicken");
    probe(CAR9, 10'd0, 10'd288, 1'b1, 1'b0, "chicken fully inside a car");
    probe(CAR9, 10'd0, 10'd100, 1'b0, 1'b0, "car far away");
    // offset moves the car: tile 9 at offset 5 covers 293..324
    probe(CAR9, 10'd5, 10'd320, 1'b1, 1'b0, "shifted car, left sample at 324");
    probe(CAR9, 10'd5, 10'd321, 1'b0, 1'b0, "shifted car, left sample at 325");
    // across the wrap: tile 19 at offset 20 covers 628..639 and 0..19
    probe({K_ROAD, DIR_RIGHT, 3'd1, 20'h80000}, 10'd20, 10'd0,   1'b1, 1'b0, "wrapped car at the left edge");
    probe({K_ROAD, DIR_RIGHT, 3'd1, 20'h80000}, 10'd20, 10'd608, 1'b1, 1'b0, "wrapped car at the right edge");
    probe({K_ROAD, DIR_RIGHT, 3'd1, 20'h80000}, 10'd20, 10'd16,  1'b0, 1'b0, "just past the wrapped car");
    probe({K_ROAD, DIR_RIGHT, 3'd1, 20'h80000}, 10'd20, 10'd596, 1'b0, 1'b0, "just before the wrapped car");
    // a car lane never reports water
    probe({K_ROAD, DIR_LEFT, 3'd1, 20'h00000}, 10'd0, 10'd320, 1'b0, 1'b0, "empty road");

    // ---- logs: only the center (x+16) matters
    probe(LOG49, 10'd0, 10'd303, 1'b0, 1'b0, "centered on the log's right end (center 319)");
    probe(LOG49, 10'd0, 10'd304, 1'b0, 1'b1, "just off the log's right end (center 320)");
    probe(LOG49, 10'd0, 10'd112, 1'b0, 1'b0, "centered on the log's left end (center 128)");
    probe(LOG49, 10'd0, 10'd111, 1'b0, 1'b1, "just off the log's left end (center 127)");
    probe(LOG49, 10'd0, 10'd200, 1'b0, 1'b0, "middle of the log");
    probe(LOG49, 10'd0, 10'd500, 1'b0, 1'b1, "open water");
    probe(LOG49, 10'd7, 10'd310, 1'b0, 1'b0, "log shifted by 7: center 326 on log");
    probe(LOG49, 10'd7, 10'd311, 1'b0, 1'b1, "log shifted by 7: center 327 in water");
    // a river lane never reports a car hit
    probe({K_RIVER, DIR_RIGHT, 3'd1, 20'hFFFFF}, 10'd0, 10'd320, 1'b0, 1'b0, "all log");

    // ---- grass and goal are always safe, even with a nonzero pattern
    probe({K_GRASS, DIR_RIGHT, 3'd0, 20'hFFFFF}, 10'd0, 10'd320, 1'b0, 1'b0, "grass");
    probe({K_GOAL,  DIR_RIGHT, 3'd0, 20'h00000}, 10'd0, 10'd320, 1'b0, 1'b0, "goal");

    // ---- registered: output changes one clock after the input
    @(negedge clk);
    lane_p = CAR9; off_p = 10'd0; player_x = 10'd300;
    #1;
    if (hit_car !== 1'b0) begin errors = errors + 1; $display("FAIL hit_car changed before the clock"); end
    @(negedge clk);
    if (hit_car !== 1'b1) begin errors = errors + 1; $display("FAIL hit_car not set one clock later"); end
    reset = 1'b1; @(negedge clk); reset = 1'b0;
    lane_p = LANE_GRASS; #1;
    if (hit_car !== 1'b0 || in_water !== 1'b0) begin errors = errors + 1; $display("FAIL reset did not clear"); end

    if (errors == 0) $display("PASS tb_collision");
    else             $display("FAIL tb_collision");
    $finish;
  end
endmodule
`default_nettype wire
