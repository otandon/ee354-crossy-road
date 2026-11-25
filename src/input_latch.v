`timescale 1ns / 1ps
`default_nettype none
// input_latch -- holds each debounced press until the next frame tick
// consumes it (DESIGN 6). A pulse sets its request bit; frame_tick clears all
// five. If a pulse and frame_tick arrive in the same cycle the set wins, so
// the press is kept for the next frame and never lost (P-2).
module input_latch(
  input  wire clk,
  input  wire reset,
  input  wire pulse_u, pulse_d, pulse_l, pulse_r, pulse_c,
  input  wire frame_tick,
  output reg  req_u, req_d, req_l, req_r, req_c
);

  always @(posedge clk) begin
    if (reset) begin
      req_u <= 1'b0;
      req_d <= 1'b0;
      req_l <= 1'b0;
      req_r <= 1'b0;
      req_c <= 1'b0;
    end else begin
      req_u <= pulse_u | (req_u & ~frame_tick);
      req_d <= pulse_d | (req_d & ~frame_tick);
      req_l <= pulse_l | (req_l & ~frame_tick);
      req_r <= pulse_r | (req_r & ~frame_tick);
      req_c <= pulse_c | (req_c & ~frame_tick);
    end
  end

endmodule
`default_nettype wire
