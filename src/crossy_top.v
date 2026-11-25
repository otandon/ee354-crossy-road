`timescale 1ns / 1ps
`default_nettype none
// crossy_top -- replaces skeleton/vga_top.v and keeps its port names.
// Pins, reset, frame_tick, and the wiring between the input, game-logic and
// output modules (DESIGN 3 and 6).
// Milestone 7: full game loop with lives, score, level timer, the
// seven-segment display and the LEDs.
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

  // ------------------------------------------------------------ switches
  // Asynchronous; read only on TITLE -> PLAY. Two flip-flops first.
  reg [2:0] sw_s0, sw_s1;
  always @(posedge ClkPort) begin
    if (reset) begin
      sw_s0 <= 3'd0;
      sw_s1 <= 3'd0;
    end else begin
      sw_s0 <= {Sw2, Sw1, Sw0};
      sw_s1 <= sw_s0;
    end
  end

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
  wire [2:0]  state, level;
  wire [1:0]  lives;
  wire        play_tick, respawn, level_load;
  wire [3:0]  score_th, score_h, score_t, timer_tens, timer_ones;
  wire [9:0]  player_x;
  wire [3:0]  player_row;
  wire        at_goal, new_row, carried_off;
  wire        hit_car, in_water;
  wire [3:0]  row_r;
  wire [25:0] lane_r, lane_p;
  wire [9:0]  off_r, off_p;

  game_fsm fsm(.clk(ClkPort), .reset(reset), .frame_tick(frame_tick), .req_c(req_c),
               .hit_car(hit_car), .in_water(in_water), .carried_off(carried_off),
               .at_goal(at_goal), .new_row(new_row), .sw_level(sw_s1),
               .state(state), .level(level), .lives(lives),
               .play_tick(play_tick), .respawn(respawn), .level_load(level_load),
               .score_th(score_th), .score_h(score_h), .score_t(score_t),
               .timer_tens(timer_tens), .timer_ones(timer_ones));

  player_ctrl player(.clk(ClkPort), .reset(reset), .play_tick(play_tick),
                     .respawn(respawn), .level_load(level_load),
                     .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r),
                     .lane_p(lane_p),
                     .player_x(player_x), .player_row(player_row),
                     .at_goal(at_goal), .new_row(new_row), .carried_off(carried_off));

  lane_engine lanes(.clk(ClkPort), .reset(reset), .play_tick(play_tick),
                    .level_load(level_load), .level(level),
                    .row_r(row_r), .row_p(player_row),
                    .lane_r(lane_r), .lane_p(lane_p), .off_r(off_r), .off_p(off_p));

  collision coll(.clk(ClkPort), .reset(reset), .lane_p(lane_p), .off_p(off_p),
                 .player_x(player_x), .hit_car(hit_car), .in_water(in_water));

  // ------------------------------------------------------------ picture
  wire [9:0]  x, y;
  wire [11:0] rgb;

  renderer rend(.bright(bright), .hCount(hc), .vCount(vc), .state(state),
                .lane_r(lane_r), .off_r(off_r), .player_x(player_x),
                .player_row(player_row), .text_on(1'b0),
                .row_r(row_r), .x(x), .y(y), .rgb(rgb));

  // ------------------------------------------------------------ seven-segment display
  wire [7:0] an;
  wire [6:0] seg;
  ssd_driver ssd(.clk(ClkPort), .reset(reset), .level(level),
                 .timer_tens(timer_tens), .timer_ones(timer_ones),
                 .score_th(score_th), .score_h(score_h), .score_t(score_t),
                 .an(an), .seg(seg));

  // ------------------------------------------------------------ outputs
  assign {vgaR, vgaG, vgaB} = rgb;
  assign {An7, An6, An5, An4, An3, An2, An1, An0} = an;
  assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg} = seg;
  assign Dp = 1'b1;

  // Lives: Ld0 = lives >= 1, Ld1 = lives >= 2, Ld2 = lives == 3.
  assign Ld0 = (lives >= 2'd1);
  assign Ld1 = (lives >= 2'd2);
  assign Ld2 = (lives == 2'd3);

  // Game state, one-hot, for debugging (DESIGN 7).
  assign LD15 = (state == S_TITLE);
  assign LD14 = (state == S_PLAY);
  assign LD13 = (state == S_PAUSE);
  assign LD12 = (state == S_DEATH);
  assign LD11 = (state == S_LEVEL_CLEAR);
  assign LD10 = (state == S_GAME_OVER);
  assign LD9  = (state == S_WIN);

  assign QuadSpiFlashCS = 1'b1;

endmodule
`default_nettype wire
