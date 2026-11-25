`timescale 1ns / 1ps
`default_nettype none
// debouncer -- one clean single-cycle pulse per button press (DESIGN 6).
// Two-flop synchronizer, then a new level is accepted only after it has
// differed from the stable level for 2^CNT_W consecutive cycles
// (2^21 cycles at 100 MHz is about 21 ms). Pulses on press, not on release.
// CNT_W is a parameter only so testbenches can shorten the wait.
module debouncer #(
  parameter integer CNT_W = 21          // = DEBOUNCE_BITS in crossy_defs.vh
)(
  input  wire clk,
  input  wire reset,
  input  wire btn,                      // raw, asynchronous, active high
  output reg  pulse                     // one clk cycle per accepted press
);

  reg             s0, s1;               // two-flip-flop synchronizer
  reg             stable;               // debounced level
  reg [CNT_W-1:0] cnt;

  always @(posedge clk) begin
    pulse <= 1'b0;
    if (reset) begin
      s0     <= 1'b0;
      s1     <= 1'b0;
      stable <= 1'b0;
      cnt    <= {CNT_W{1'b0}};
    end else begin
      s0 <= btn;
      s1 <= s0;
      if (s1 == stable) begin
        cnt <= {CNT_W{1'b0}};                 // no change pending
      end else begin
        cnt <= cnt + {{(CNT_W-1){1'b0}}, 1'b1};
        if (&cnt) begin                       // different for 2^CNT_W cycles: accept
          stable <= s1;
          pulse  <= s1;                       // pulse on press only
          cnt    <= {CNT_W{1'b0}};
        end
      end
    end
  end

endmodule
`default_nettype wire
