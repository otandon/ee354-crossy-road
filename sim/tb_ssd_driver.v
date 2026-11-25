`timescale 1ns / 1ps
`default_nettype none
// tb_ssd_driver -- over full scans: exactly one anode low at a time, all
// eight visited in order An0..An7, each for 2^17 clocks, and each digit shows
// the right value with counter.v's segment codes plus the letter L. Two input
// sets together cover every digit 0..9.
module tb_ssd_driver;

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg [2:0] level = 3'd0;
  reg [3:0] timer_tens = 4'd0, timer_ones = 4'd0, score_th = 4'd0, score_h = 4'd0, score_t = 4'd0;
  wire [7:0] an;
  wire [6:0] seg;

  ssd_driver dut(.clk(clk), .reset(reset), .level(level),
                 .timer_tens(timer_tens), .timer_ones(timer_ones),
                 .score_th(score_th), .score_h(score_h), .score_t(score_t),
                 .an(an), .seg(seg));

  // counter.v's table, {Ca..Cg}, active low
  function [6:0] seg_of;
    input [3:0] d;
    begin
      case (d)
        4'd0: seg_of = 7'b0000001;
        4'd1: seg_of = 7'b1001111;
        4'd2: seg_of = 7'b0010010;
        4'd3: seg_of = 7'b0000110;
        4'd4: seg_of = 7'b1001100;
        4'd5: seg_of = 7'b0100100;
        4'd6: seg_of = 7'b0100000;
        4'd7: seg_of = 7'b0001111;
        4'd8: seg_of = 7'b0000000;
        4'd9: seg_of = 7'b0000100;
        default: seg_of = 7'bxxxxxxx;
      endcase
    end
  endfunction
  localparam [6:0] SEG_L = 7'b1110001;

  integer errors = 0;

  // Expected segments for anode position p (0 = An0).
  function [6:0] expected_seg;
    input integer p;
    begin
      case (p)
        0: expected_seg = seg_of(4'd0);
        1: expected_seg = seg_of(score_t);
        2: expected_seg = seg_of(score_h);
        3: expected_seg = seg_of(score_th);
        4: expected_seg = seg_of(timer_ones);
        5: expected_seg = seg_of(timer_tens);
        6: expected_seg = seg_of({1'b0, level});
        7: expected_seg = SEG_L;
        default: expected_seg = 7'bxxxxxxx;
      endcase
    end
  endfunction

  integer p, count, lit, k;
  integer dwell [0:7];
  reg [7:0] last_an;
  integer order_pos;

  // Watch one full scan (2^20 clocks) and check every cycle.
  task scan;
    begin
      for (k = 0; k < 8; k = k + 1) dwell[k] = 0;
      order_pos = 0;
      last_an = 8'hFF;
      for (count = 0; count < (1 << 20); count = count + 1) begin
        @(negedge clk);
        lit = 0;
        for (k = 0; k < 8; k = k + 1) if (an[k] == 1'b0) begin lit = lit + 1; p = k; end
        if (lit != 1) begin
          errors = errors + 1;
          if (errors < 10) $display("FAIL %0d anodes low (an=%b)", lit, an);
        end else begin
          dwell[p] = dwell[p] + 1;
          if (seg !== expected_seg(p)) begin
            errors = errors + 1;
            if (errors < 10) $display("FAIL An%0d shows %b, expected %b", p, seg, expected_seg(p));
          end
          if (an !== last_an) begin
            if (p != order_pos) begin
              errors = errors + 1;
              $display("FAIL scan order: An%0d lit where An%0d was expected", p, order_pos);
            end
            order_pos = (order_pos + 1) % 8;
          end
        end
        last_an = an;
      end
      for (k = 0; k < 8; k = k + 1)
        if (dwell[k] != (1 << 17)) begin
          errors = errors + 1;
          $display("FAIL An%0d lit for %0d clocks, expected %0d", k, dwell[k], 1 << 17);
        end
    end
  endtask

  initial begin
    @(negedge clk); @(negedge clk);
    // Set A: digits 1..6 in use; L1, timer 23, score 4560
    level = 3'd1; timer_tens = 4'd2; timer_ones = 4'd3;
    score_th = 4'd4; score_h = 4'd5; score_t = 4'd6;
    reset = 1'b0;
    scan;
    // Set B: digits 0, 5, 7, 8, 9, 1; L5, timer 78, score 9010
    level = 3'd5; timer_tens = 4'd7; timer_ones = 4'd8;
    score_th = 4'd9; score_h = 4'd0; score_t = 4'd1;
    scan;
    // reset restarts the scan at An0
    @(negedge clk); reset = 1'b1; @(negedge clk); reset = 1'b0;
    if (an !== 8'b1111_1110) begin
      errors = errors + 1; $display("FAIL after reset an=%b, expected An0", an);
    end

    if (errors == 0) $display("PASS tb_ssd_driver");
    else             $display("FAIL tb_ssd_driver");
    $finish;
  end
endmodule
`default_nettype wire
