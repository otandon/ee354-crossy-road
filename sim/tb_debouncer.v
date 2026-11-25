`timescale 1ns / 1ps
`default_nettype none
// tb_debouncer -- one pulse per press, none on release, none for glitches
// shorter than the settle time, no repeat while held, bounces filtered.
// The settle time is shortened to 2^4 = 16 cycles.
module tb_debouncer;

  localparam integer W = 4;
  localparam integer SETTLE = 1 << W;

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg btn = 1'b0;
  wire pulse;

  debouncer #(.CNT_W(W)) dut(.clk(clk), .reset(reset), .btn(btn), .pulse(pulse));

  integer errors = 0;
  integer pulses = 0;
  integer width = 0;
  always @(posedge clk) begin
    if (pulse === 1'b1) begin
      width = width + 1;
      if (width > 1) begin
        errors = errors + 1;
        $display("FAIL pulse wider than one cycle at %0t", $time);
      end
    end else begin
      width = 0;
    end
    if (pulse === 1'b1) pulses = pulses + 1;
  end

  task expect_pulses;
    input integer n;
    input [8*40-1:0] what;
    begin
      if (pulses !== n) begin
        errors = errors + 1;
        $display("FAIL %0s: %0d pulses, expected %0d", what, pulses, n);
      end
      pulses = 0;
    end
  endtask

  task hold;   // keep btn at v for n cycles
    input v;
    input integer n;
    begin
      btn = v;
      repeat (n) @(posedge clk);
    end
  endtask

  task bounce; // toggle btn every 3 cycles, n toggles
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) begin
        btn = ~btn;
        repeat (3) @(posedge clk);
      end
    end
  endtask

  integer t0, lat;

  initial begin
    repeat (5) @(posedge clk);
    reset = 1'b0;
    repeat (5) @(posedge clk);
    pulses = 0;
    if (pulse !== 1'b0) begin errors = errors + 1; $display("FAIL pulse not 0 after reset"); end

    // ---- clean press, held a long time: exactly one pulse, no repeat
    hold(1'b1, 20 * SETTLE);
    expect_pulses(1, "clean press held 20x settle time");
    hold(1'b0, 4 * SETTLE);
    expect_pulses(0, "clean release");

    // ---- latency: pulse arrives about settle time + 3 sync cycles later
    btn = 1'b1; t0 = $time;
    @(posedge pulse); lat = ($time - t0) / 10;
    if (lat < SETTLE || lat > SETTLE + 5) begin
      errors = errors + 1; $display("FAIL press-to-pulse latency %0d cycles", lat);
    end
    hold(1'b1, 2 * SETTLE);
    pulses = 0;
    hold(1'b0, 4 * SETTLE);

    // ---- glitches shorter than the settle time are ignored
    hold(1'b1, SETTLE - 4);
    hold(1'b0, 4 * SETTLE);
    expect_pulses(0, "high glitch shorter than settle time");
    hold(1'b1, 1);
    hold(1'b0, 4 * SETTLE);
    expect_pulses(0, "one-cycle spike");

    // ---- bouncy press then bouncy release: one pulse total
    btn = 1'b0;
    bounce(9);                 // ends high (odd number of toggles)
    hold(1'b1, 4 * SETTLE);
    expect_pulses(1, "bouncy press");
    bounce(9);                 // ends low
    hold(1'b0, 4 * SETTLE);
    expect_pulses(0, "bouncy release");

    // ---- low glitch while held does not cause a second pulse
    hold(1'b1, 4 * SETTLE);
    pulses = 0;
    hold(1'b0, SETTLE - 4);
    hold(1'b1, 4 * SETTLE);
    expect_pulses(0, "short dropout while held");
    hold(1'b0, 4 * SETTLE);

    // ---- ten separate presses give ten pulses
    repeat (10) begin
      hold(1'b1, 3 * SETTLE);
      hold(1'b0, 3 * SETTLE);
    end
    expect_pulses(10, "ten presses");

    // ---- reset while held: no pulse during reset, stable level cleared
    hold(1'b1, 3 * SETTLE);
    pulses = 0;
    reset = 1'b1; repeat (3) @(posedge clk); reset = 1'b0;
    hold(1'b1, 3 * SETTLE);
    expect_pulses(1, "held through reset is seen as a new press");
    hold(1'b0, 3 * SETTLE);

    if (errors == 0) $display("PASS tb_debouncer");
    else             $display("FAIL tb_debouncer");
    $finish;
  end
endmodule
`default_nettype wire
