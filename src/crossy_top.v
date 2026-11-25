`timescale 1ns / 1ps
`default_nettype none
// crossy_top -- replaces skeleton/vga_top.v and keeps its port names.
// Milestone 3: static level 1 playfield, plus buttons (debouncer x5,
// input_latch) and a chicken that hops (player_ctrl) on every frame tick.
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

  // ------------------------------------------------------------ buttons
  wire pulse_u, pulse_d, pulse_l, pulse_r, pulse_c;
  debouncer #(.CNT_W(DEBOUNCE_BITS)) db_u(.clk(ClkPort), .reset(reset), .btn(BtnU), .pulse(pulse_u));
  debouncer #(.CNT_W(DEBOUNCE_BITS)) db_d(.clk(ClkPort), .reset(reset), .btn(BtnD), .pulse(pulse_d));
  debouncer #(.CNT_W(DEBOUNCE_BITS)) db_l(.clk(ClkPort), .reset(reset), .btn(BtnL), .pulse(pulse_l));
  debouncer #(.CNT_W(DEBOUNCE_BITS)) db_r(.clk(ClkPort), .reset(reset), .btn(BtnR), .pulse(pulse_r));
  debouncer #(.CNT_W(DEBOUNCE_BITS)) db_c(.clk(ClkPort), .reset(reset), .btn(BtnC), .pulse(pulse_c));

  wire req_u, req_d, req_l, req_r, req_c;
  input_latch latch(.clk(ClkPort), .reset(reset),
                    .pulse_u(pulse_u), .pulse_d(pulse_d), .pulse_l(pulse_l),
                    .pulse_r(pulse_r), .pulse_c(pulse_c), .frame_tick(frame_tick),
                    .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r),
                    .req_c(req_c));

  // ------------------------------------------------------------ game logic
  // Milestone 3: no state machine yet, so every frame tick is a play tick.
  wire        play_tick = frame_tick;
  wire [9:0]  player_x;
  wire [3:0]  player_row;
  wire        at_goal, new_row, carried_off;

  player_ctrl player(.clk(ClkPort), .reset(reset), .play_tick(play_tick),
                     .respawn(1'b0), .level_load(1'b0),
                     .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r),
                     .lane_p(LANE_GRASS),
                     .player_x(player_x), .player_row(player_row),
                     .at_goal(at_goal), .new_row(new_row), .carried_off(carried_off));

  // ------------------------------------------------------------ picture
  // Static level 1 playfield: one level_rom answers for the row being drawn,
  // offsets are 0.
  wire [3:0]  row_r;
  wire [9:0]  x, y;
  wire [25:0] lane_r;
  wire [11:0] rgb;

  level_rom rom_r(.level(FIRST_LEVEL), .row(row_r), .lane(lane_r));

  renderer rend(.bright(bright), .hCount(hc), .vCount(vc), .state(S_PLAY),
                .lane_r(lane_r), .off_r(10'd0), .player_x(player_x),
                .player_row(player_row), .text_on(1'b0),
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
