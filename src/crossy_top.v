`timescale 1ns / 1ps
`default_nettype none
// crossy_top -- replaces skeleton/vga_top.v and keeps its port names.
// Milestone 2: reset synchronizer, frame_tick, and the static level 1
// playfield drawn by renderer + level_rom.
module crossy_top(
  input  wire ClkPort,                       // 100 MHz
  input  wire CPU_RESETN,                    // active low
  input  wire BtnC, BtnU, BtnD, BtnL, BtnR,
  input  wire Sw0, Sw1, Sw2,
  output wire hSync, vSync,
  output wire [3:0] vgaR, vgaG, vgaB,
  output wire An0, An1, An2, An3, An4, An5, An6, An7,
  output wire Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
  output wire Ld0, Ld1, Ld2,
  output wire LD9, LD10, LD11, LD12, LD13, LD14, LD15,
  output wire QuadSpiFlashCS                 // held at 1, as in vga_top
);
`include "crossy_defs.vh"

  // ------------------------------------------------------------ reset
  // CPU_RESETN is asynchronous and active low: invert and synchronize.
  reg r0, r1;
  always @(posedge ClkPort) begin
    r0 <= ~CPU_RESETN;
    r1 <= r0;
  end
  wire reset = r1;

  // ------------------------------------------------------------ VGA timing
  wire       bright;
  wire [9:0] hc, vc;
  display_controller dc(.clk(ClkPort), .hSync(hSync), .vSync(vSync),
                        .bright(bright), .hCount(hc), .vCount(vc));

  // ------------------------------------------------------------ frame_tick
  // vCount 516..524 is vertical blanking. vCount holds each value for four
  // ClkPort cycles, so edge-detect to get exactly one cycle per frame.
  reg vb0, vb1, vb2;
  always @(posedge ClkPort) begin
    vb0 <= (vc >= VBLANK_START);
    vb1 <= vb0;
    vb2 <= vb1;
  end
  wire frame_tick = vb1 & ~vb2;

  // ------------------------------------------------------------ picture
  // Milestone 2: static level 1 playfield. One level_rom answers for the row
  // being drawn; offsets are 0 and there is no chicken yet (row 15 is never
  // drawn).
  wire [3:0]  row_r;
  wire [9:0]  x, y;
  wire [25:0] lane_r;
  wire [11:0] rgb;

  level_rom rom_r(.level(FIRST_LEVEL), .row(row_r), .lane(lane_r));

  renderer rend(.bright(bright), .hCount(hc), .vCount(vc), .state(S_PLAY),
                .lane_r(lane_r), .off_r(10'd0), .player_x(START_X),
                .player_row(4'd15), .text_on(1'b0),
                .row_r(row_r), .x(x), .y(y), .rgb(rgb));

  // Heartbeat on LD15: toggles every 60 frame ticks (about once a second),
  // which shows on the board that frame_tick runs at 60 Hz.
  reg [5:0] beat_cnt;
  reg       beat;
  always @(posedge ClkPort) begin
    if (reset) begin
      beat_cnt <= 6'd0;
      beat     <= 1'b0;
    end else if (frame_tick) begin
      if (beat_cnt == FRAMES_PER_S - 6'd1) begin
        beat_cnt <= 6'd0;
        beat     <= ~beat;
      end else begin
        beat_cnt <= beat_cnt + 6'd1;
      end
    end
  end

  // ------------------------------------------------------------ outputs
  assign {vgaR, vgaG, vgaB} = rgb;
  assign {An7, An6, An5, An4, An3, An2, An1, An0} = 8'hFF;   // display off
  assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg} = 7'h7F;
  assign Dp = 1'b1;
  assign {Ld2, Ld1, Ld0} = 3'b000;
  assign {LD14, LD13, LD12, LD11, LD10, LD9} = 6'b000000;
  assign LD15 = beat;
  assign QuadSpiFlashCS = 1'b1;

endmodule
`default_nettype wire
