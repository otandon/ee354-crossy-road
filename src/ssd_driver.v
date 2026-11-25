`timescale 1ns / 1ps
`default_nettype none
// ssd_driver -- scans the eight seven-segment digits (adapted from the
// skeleton's counter.v). Left to right, An7..An0:
//     L  level  timer-tens  timer-ones  score-th  score-h  score-t  0
// Changes from counter.v (DESIGN 6): eight digits selected by
// refresh[19:17] (about 1.3 ms each, 95 Hz full refresh); BCD digits fed
// straight in, so no / or % dividers; the letter L added; all eight anodes
// driven; a reset instead of an uninitialized counter.
module ssd_driver(
  input  wire       clk,
  input  wire       reset,
  input  wire [2:0] level,
  input  wire [3:0] timer_tens, timer_ones,
  input  wire [3:0] score_th, score_h, score_t,
  output reg  [7:0] an,                 // {An7..An0}, active low
  output reg  [6:0] seg                 // {Ca,Cb,Cc,Cd,Ce,Cf,Cg}, active low
);

  localparam [3:0] DIGIT_L     = 4'hA;  // codes above 9 used only here
  localparam [3:0] DIGIT_BLANK = 4'hF;

  reg [19:0] refresh;
  always @(posedge clk) begin
    if (reset) refresh <= 20'd0;
    else       refresh <= refresh + 20'd1;
  end
  wire [2:0] sel = refresh[19:17];

  reg [3:0] digit;
  always @(*) begin
    an    = 8'hFF;
    digit = DIGIT_BLANK;
    case (sel)
      3'd0: begin an = 8'b1111_1110; digit = 4'd0;           end   // An0: constant 0
      3'd1: begin an = 8'b1111_1101; digit = score_t;        end   // An1
      3'd2: begin an = 8'b1111_1011; digit = score_h;        end   // An2
      3'd3: begin an = 8'b1111_0111; digit = score_th;       end   // An3
      3'd4: begin an = 8'b1110_1111; digit = timer_ones;     end   // An4
      3'd5: begin an = 8'b1101_1111; digit = timer_tens;     end   // An5
      3'd6: begin an = 8'b1011_1111; digit = {1'b0, level};  end   // An6
      3'd7: begin an = 8'b0111_1111; digit = DIGIT_L;        end   // An7
      default: begin an = 8'hFF; digit = DIGIT_BLANK; end
    endcase
  end

  // Digit-to-segment table from counter.v, plus L and blank.
  always @(*) begin
    seg = 7'b1111111;
    case (digit)
      4'd0:    seg = 7'b0000001;
      4'd1:    seg = 7'b1001111;
      4'd2:    seg = 7'b0010010;
      4'd3:    seg = 7'b0000110;
      4'd4:    seg = 7'b1001100;
      4'd5:    seg = 7'b0100100;
      4'd6:    seg = 7'b0100000;
      4'd7:    seg = 7'b0001111;
      4'd8:    seg = 7'b0000000;
      4'd9:    seg = 7'b0000100;
      DIGIT_L: seg = 7'b1110001;
      default: seg = 7'b1111111;   // blank
    endcase
  end

endmodule
`default_nettype wire
