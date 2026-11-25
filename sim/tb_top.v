`timescale 1ns / 1ps
`default_nettype none
// tb_top -- runs crossy_top with the real display_controller for two frames.
// Checks, from the end of reset onward:
//   * hSync and vSync toggle,
//   * RGB is zero whenever bright is low,
//   * no output is X or Z,
//   * frame_tick is high for exactly one clock per frame, in vertical blanking,
//   * a few probe pixels show the expected colors (the wiring from level_rom
//     through the renderer to the VGA pins),
//   * BtnC starts the game: frame 1 is the title screen, frame 2 is level 1.
// BtnC's debouncer is shortened with defparam so a press fits in a frame;
// the other four keep the real 21 ms settle time.
module tb_top;
`include "crossy_defs.vh"

  localparam integer CYCLES_PER_FRAME = 800 * 525 * 4;   // 25 MHz pixel clock
  localparam integer RESET_CYCLES     = 100;

  reg ClkPort = 1'b0;
  always #5 ClkPort = ~ClkPort;                         // 100 MHz

  reg CPU_RESETN = 1'b0;
  reg BtnC = 1'b0, BtnU = 1'b0, BtnD = 1'b0, BtnL = 1'b0, BtnR = 1'b0;
  reg Sw0 = 1'b0, Sw1 = 1'b0, Sw2 = 1'b0;

  wire hSync, vSync;
  wire [3:0] vgaR, vgaG, vgaB;
  wire An0, An1, An2, An3, An4, An5, An6, An7;
  wire Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
  wire Ld0, Ld1, Ld2;
  wire LD9, LD10, LD11, LD12, LD13, LD14, LD15;
  wire QuadSpiFlashCS;

  crossy_top dut(
    .ClkPort(ClkPort), .CPU_RESETN(CPU_RESETN),
    .BtnC(BtnC), .BtnU(BtnU), .BtnD(BtnD), .BtnL(BtnL), .BtnR(BtnR),
    .Sw0(Sw0), .Sw1(Sw1), .Sw2(Sw2),
    .hSync(hSync), .vSync(vSync), .vgaR(vgaR), .vgaG(vgaG), .vgaB(vgaB),
    .An0(An0), .An1(An1), .An2(An2), .An3(An3), .An4(An4), .An5(An5), .An6(An6), .An7(An7),
    .Ca(Ca), .Cb(Cb), .Cc(Cc), .Cd(Cd), .Ce(Ce), .Cf(Cf), .Cg(Cg), .Dp(Dp),
    .Ld0(Ld0), .Ld1(Ld1), .Ld2(Ld2),
    .LD9(LD9), .LD10(LD10), .LD11(LD11), .LD12(LD12), .LD13(LD13), .LD14(LD14), .LD15(LD15),
    .QuadSpiFlashCS(QuadSpiFlashCS));

  defparam dut.db_c.CNT_W = 4;

  wire [11:0] rgb = {vgaR, vgaG, vgaB};
  wire [53:0] outs = {hSync, vSync, vgaR, vgaG, vgaB,
                      An7, An6, An5, An4, An3, An2, An1, An0,
                      Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
                      Ld2, Ld1, Ld0, LD15, LD14, LD13, LD12, LD11, LD10, LD9,
                      QuadSpiFlashCS, 22'd0};

  // ------------------------------------------------------------ probe pixels
  // Each probe is checked every time the beam is on it while the game is in
  // the probe's state.
  localparam integer NPROBE = 12;
  integer probe_x   [0:NPROBE-1];
  integer probe_y   [0:NPROBE-1];
  reg [11:0] probe_c [0:NPROBE-1];
  reg [2:0]  probe_s [0:NPROBE-1];
  integer probe_hits[0:NPROBE-1];
  integer pi;
  initial begin
    // Level 1 at offset 0, state PLAY (frame 2).
    probe_x[0] = 5;   probe_y[0] = 0*32 + 16;  probe_c[0] = COL_GOAL;   // goal row
    probe_x[1] = 5;   probe_y[1] = 5*32 + 16;  probe_c[1] = COL_LOG;    // LOG_A tile 0
    probe_x[2] = 200; probe_y[2] = 5*32 + 16;  probe_c[2] = COL_WATER;  // LOG_A tile 6
    probe_x[3] = 5;   probe_y[3] = 10*32 + 16; probe_c[3] = COL_CAR;    // CAR_A tile 0
    probe_x[4] = 170; probe_y[4] = 10*32 + 16; probe_c[4] = COL_ROAD;   // CAR_A tile 5
    probe_x[5] = 5;   probe_y[5] = 10*32 + 2;  probe_c[5] = COL_ROAD;   // above the car band
    probe_x[6] = 5;   probe_y[6] = 14*32 + 16; probe_c[6] = COL_GRASS;  // start row
    probe_x[7] = 639; probe_y[7] = 479;        probe_c[7] = COL_GRASS;  // last visible pixel
    probe_x[8] = 336; probe_y[8] = 14*32 + 16; probe_c[8] = COL_CHICKEN; // chicken on its start tile
    for (pi = 0; pi < 9; pi = pi + 1) probe_s[pi] = S_PLAY;
    // Title screen (frame 1): black where the playfield would be.
    probe_x[9]  = 5;   probe_y[9]  = 0*32 + 16;  probe_c[9]  = COL_BLACK; probe_s[9]  = S_TITLE;
    probe_x[10] = 336; probe_y[10] = 14*32 + 16; probe_c[10] = COL_BLACK; probe_s[10] = S_TITLE;
    probe_x[11] = 5;   probe_y[11] = 10*32 + 16; probe_c[11] = COL_BLACK; probe_s[11] = S_TITLE;
    for (pi = 0; pi < NPROBE; pi = pi + 1) probe_hits[pi] = 0;
  end

  integer errors = 0;
  integer xz_errors = 0, rgb_errors = 0;
  integer h_toggles = 0, v_toggles = 0;
  integer ticks = 0;
  reg     checking = 1'b0;
  reg     last_h, last_v, last_tick;

  // All checks sample on the falling edge, half a cycle after any change.
  always @(negedge ClkPort) begin
    if (checking) begin
      if (^outs === 1'bx) begin
        xz_errors = xz_errors + 1;
        if (xz_errors < 10) $display("FAIL X/Z on an output at %0t: %b", $time, outs);
      end
      if (!dut.bright && rgb !== 12'h000) begin
        rgb_errors = rgb_errors + 1;
        if (rgb_errors < 10)
          $display("FAIL rgb=%h while bright=0 at hc=%0d vc=%0d", rgb, dut.hc, dut.vc);
      end
      if (dut.bright) begin
        for (pi = 0; pi < NPROBE; pi = pi + 1) begin
          if (dut.hc == probe_x[pi] + 145 && dut.vc == probe_y[pi] + 35 &&
              dut.state == probe_s[pi]) begin
            probe_hits[pi] = probe_hits[pi] + 1;
            if (rgb !== probe_c[pi]) begin
              errors = errors + 1;
              $display("FAIL probe %0d at x=%0d y=%0d: rgb=%h expected %h",
                       pi, probe_x[pi], probe_y[pi], rgb, probe_c[pi]);
            end
          end
        end
      end
      if (hSync !== last_h) h_toggles = h_toggles + 1;
      if (vSync !== last_v) v_toggles = v_toggles + 1;
      if (dut.frame_tick === 1'b1) begin
        ticks = ticks + 1;
        if (last_tick === 1'b1) begin
          errors = errors + 1;
          $display("FAIL frame_tick high for more than one cycle at %0t", $time);
        end
        if (dut.vc < VBLANK_START) begin
          errors = errors + 1;
          $display("FAIL frame_tick outside vertical blanking, vc=%0d", dut.vc);
        end
      end
    end
    last_h    = hSync;
    last_v    = vSync;
    last_tick = dut.frame_tick;
  end

  initial begin
    repeat (RESET_CYCLES) @(posedge ClkPort);
    CPU_RESETN = 1'b1;
    repeat (4) @(posedge ClkPort);
    checking = 1'b1;
    if (!LD15 || Ld0) begin
      errors = errors + 1;
      $display("FAIL after reset: expected TITLE (LD15) and no lives, LD15=%b Ld0=%b", LD15, Ld0);
    end
    // Press BtnC early in frame 1; the game starts at frame 1's tick.
    repeat (1000) @(posedge ClkPort);
    BtnC = 1'b1;
    repeat (200) @(posedge ClkPort);
    BtnC = 1'b0;
    repeat (2 * CYCLES_PER_FRAME - 1200) @(posedge ClkPort);
    checking = 1'b0;

    if (!LD14 || LD15 || {Ld2, Ld1, Ld0} !== 3'b111) begin
      errors = errors + 1;
      $display("FAIL after BtnC: expected PLAY (LD14) with 3 lives, LD15..9=%b Ld2..0=%b",
               {LD15, LD14, LD13, LD12, LD11, LD10, LD9}, {Ld2, Ld1, Ld0});
    end

    if (h_toggles < 2 * 2 * 525 - 4) begin
      errors = errors + 1;
      $display("FAIL hSync toggled only %0d times in two frames", h_toggles);
    end
    if (v_toggles < 3) begin
      errors = errors + 1;
      $display("FAIL vSync toggled only %0d times in two frames", v_toggles);
    end
    if (ticks != 2) begin
      errors = errors + 1;
      $display("FAIL saw %0d frame_ticks in two frames, expected 2", ticks);
    end
    for (pi = 0; pi < NPROBE; pi = pi + 1)
      if (probe_hits[pi] == 0) begin
        errors = errors + 1;
        $display("FAIL probe %0d was never reached", pi);
      end
    errors = errors + xz_errors + rgb_errors;
    $display("hSync toggles %0d, vSync toggles %0d, frame_ticks %0d", h_toggles, v_toggles, ticks);
    if (errors == 0) $display("PASS tb_top");
    else             $display("FAIL tb_top");
    $finish;
  end
endmodule
`default_nettype wire
