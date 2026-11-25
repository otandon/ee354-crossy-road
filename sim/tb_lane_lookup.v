`timescale 1ns / 1ps
`default_nettype none
// tb_lane_lookup -- checks the shared occupied() function in crossy_defs.vh.
// Spot checks from DESIGN 12 (offsets 0, 31, 32, 639; pattern bits 0 and 19),
// then an exhaustive sweep against an independent model: a single tile i at
// offset o covers screen x in [(32*i + o) mod 640, +32), wrapping at 640.
// Sweeping every offset 0..639 covers both motion directions across the wrap
// point, since moving left is the same offsets visited in reverse.
module tb_lane_lookup;
`include "crossy_defs.vh"

  integer errors = 0;
  integer checks = 0;

  task check;
    input [19:0] pattern;
    input [9:0]  offset;
    input [9:0]  px;
    input        expected;
    begin
      checks = checks + 1;
      if (occupied(pattern, offset, px) !== expected) begin
        errors = errors + 1;
        $display("FAIL occupied(%h, %0d, %0d) = %b, expected %b",
                 pattern, offset, px, occupied(pattern, offset, px), expected);
      end
    end
  endtask

  integer i, o, x, e, d;
  reg [19:0] p;
  reg exp_occ;

  initial begin
    // ---- bit 0 only
    check(20'h00001, 10'd0,   10'd0,   1'b1);
    check(20'h00001, 10'd0,   10'd31,  1'b1);
    check(20'h00001, 10'd0,   10'd32,  1'b0);
    check(20'h00001, 10'd0,   10'd639, 1'b0);
    check(20'h00001, 10'd31,  10'd30,  1'b0);
    check(20'h00001, 10'd31,  10'd31,  1'b1);
    check(20'h00001, 10'd31,  10'd62,  1'b1);
    check(20'h00001, 10'd31,  10'd63,  1'b0);
    check(20'h00001, 10'd32,  10'd31,  1'b0);
    check(20'h00001, 10'd32,  10'd32,  1'b1);
    check(20'h00001, 10'd32,  10'd63,  1'b1);
    check(20'h00001, 10'd32,  10'd64,  1'b0);
    check(20'h00001, 10'd639, 10'd638, 1'b0);  // tile split across the wrap
    check(20'h00001, 10'd639, 10'd639, 1'b1);
    check(20'h00001, 10'd639, 10'd0,   1'b1);
    check(20'h00001, 10'd639, 10'd30,  1'b1);
    check(20'h00001, 10'd639, 10'd31,  1'b0);
    // ---- bit 19 only
    check(20'h80000, 10'd0,   10'd607, 1'b0);
    check(20'h80000, 10'd0,   10'd608, 1'b1);
    check(20'h80000, 10'd0,   10'd639, 1'b1);
    check(20'h80000, 10'd0,   10'd0,   1'b0);
    check(20'h80000, 10'd31,  10'd638, 1'b0);  // tile now spans 639, 0..30
    check(20'h80000, 10'd31,  10'd639, 1'b1);
    check(20'h80000, 10'd31,  10'd0,   1'b1);  // moving right, wrapped to x=0
    check(20'h80000, 10'd31,  10'd30,  1'b1);
    check(20'h80000, 10'd31,  10'd31,  1'b0);
    check(20'h80000, 10'd32,  10'd639, 1'b0);  // fully wrapped to tile 0
    check(20'h80000, 10'd32,  10'd0,   1'b1);
    check(20'h80000, 10'd32,  10'd31,  1'b1);
    check(20'h80000, 10'd32,  10'd32,  1'b0);
    check(20'h80000, 10'd639, 10'd606, 1'b0);  // moving left from offset 0
    check(20'h80000, 10'd639, 10'd607, 1'b1);
    check(20'h80000, 10'd639, 10'd638, 1'b1);
    check(20'h80000, 10'd639, 10'd639, 1'b0);
    // ---- all tiles / no tiles
    check(20'hFFFFF, 10'd317, 10'd0,   1'b1);
    check(20'hFFFFF, 10'd317, 10'd639, 1'b1);
    check(20'h00000, 10'd317, 10'd100, 1'b0);

    // ---- exhaustive sweep, single-tile patterns 0, 1, 10, 18, 19
    for (i = 0; i < 20; i = i + 1) begin
      if (i == 0 || i == 1 || i == 10 || i == 18 || i == 19) begin
        p = 20'h00001 << i;
        for (o = 0; o < 640; o = o + 1) begin
          e = (32 * i + o) % 640;          // left edge of the object on screen
          for (x = 0; x < 640; x = x + 1) begin
            d = (x - e + 640) % 640;
            exp_occ = (d < 32);
            checks = checks + 1;
            if (occupied(p, o[9:0], x[9:0]) !== exp_occ) begin
              errors = errors + 1;
              if (errors < 20)
                $display("FAIL sweep tile=%0d off=%0d x=%0d got %b expected %b",
                         i, o, x, occupied(p, o[9:0], x[9:0]), exp_occ);
            end
          end
        end
      end
    end

    // ---- library patterns at offset 0: each tile reads its own bit
    for (i = 0; i < 20; i = i + 1) begin
      check(CAR_C, 10'd0, i * 32 + 5, CAR_C[i]);
      check(LOG_C, 10'd0, i * 32 + 5, LOG_C[i]);
    end

    $display("%0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("PASS tb_lane_lookup");
    else             $display("FAIL tb_lane_lookup");
    $finish;
  end
endmodule
`default_nettype wire
