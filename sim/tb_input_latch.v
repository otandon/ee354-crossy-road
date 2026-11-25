`timescale 1ns / 1ps
`default_nettype none
// tb_input_latch -- a pulse sets its request, the request survives until a
// frame tick, the consumer sees it on the tick cycle, the tick clears it, and
// a pulse on the same cycle as the tick wins (the press is not lost).
module tb_input_latch;

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg [4:0] pulse = 5'd0;              // {c, r, l, d, u}
  reg frame_tick = 1'b0;
  wire req_u, req_d, req_l, req_r, req_c;
  wire [4:0] req = {req_c, req_r, req_l, req_d, req_u};

  input_latch dut(.clk(clk), .reset(reset),
                  .pulse_u(pulse[0]), .pulse_d(pulse[1]), .pulse_l(pulse[2]),
                  .pulse_r(pulse[3]), .pulse_c(pulse[4]), .frame_tick(frame_tick),
                  .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r), .req_c(req_c));

  integer errors = 0;
  task expect_req;
    input [4:0] want;
    input [8*40-1:0] what;
    begin
      if (req !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: req=%b expected %b", what, req, want);
      end
    end
  endtask

  // Drive inputs just after a rising edge; they are sampled at the next one.
  task cycle;
    input [4:0] p;
    input       t;
    begin
      pulse = p; frame_tick = t;
      @(posedge clk); #1;
      pulse = 5'd0; frame_tick = 1'b0;
    end
  endtask

  integer i;

  initial begin
    @(posedge clk); #1;
    @(posedge clk); #1;
    reset = 1'b0;
    expect_req(5'b00000, "after reset");

    // each bit on its own: set, held, consumed on the tick cycle, cleared after
    for (i = 0; i < 5; i = i + 1) begin
      cycle(5'b00001 << i, 1'b0);
      expect_req(5'b00001 << i, "set by pulse");
      repeat (50) cycle(5'd0, 1'b0);
      expect_req(5'b00001 << i, "held with no tick");
      frame_tick = 1'b1;          // tick cycle: consumer samples req here
      expect_req(5'b00001 << i, "visible during the tick cycle");
      @(posedge clk); #1; frame_tick = 1'b0;
      expect_req(5'b00000, "cleared by tick");
    end

    // all five at once
    cycle(5'b11111, 1'b0);
    expect_req(5'b11111, "all five set");
    cycle(5'd0, 1'b1);
    expect_req(5'b00000, "all five cleared");

    // pulse and tick on the same cycle: set wins
    cycle(5'b00100, 1'b1);
    expect_req(5'b00100, "pulse on the tick cycle is kept");
    cycle(5'd0, 1'b1);
    expect_req(5'b00000, "kept press consumed by the next tick");

    // an existing request plus a new pulse on the tick: old one consumed,
    // new one kept
    cycle(5'b00001, 1'b0);
    cycle(5'b00010, 1'b1);
    expect_req(5'b00010, "old request cleared, new one kept");
    cycle(5'd0, 1'b1);

    // tick with nothing pending does nothing
    cycle(5'd0, 1'b1);
    expect_req(5'b00000, "idle tick");

    // reset clears pending requests
    cycle(5'b10101, 1'b0);
    reset = 1'b1; @(posedge clk); #1; reset = 1'b0;
    expect_req(5'b00000, "reset clears");

    if (errors == 0) $display("PASS tb_input_latch");
    else             $display("FAIL tb_input_latch");
    $finish;
  end
endmodule
`default_nettype wire
