`timescale 1ns / 1ps
`default_nettype none
// game_fsm -- game state, level, lives (DESIGN 7).
// Every transition except reset happens on a frame tick. Inside PLAY the
// priority is goal, then death, then pause.
// Milestone 6: states, lives, respawn, level progression. Score and timer
// outputs are held at 0 until milestone 7, and the timer cannot yet kill.
module game_fsm(
  input  wire       clk,
  input  wire       reset,
  input  wire       frame_tick,
  input  wire       req_c,
  input  wire       hit_car, in_water, carried_off,   // from collision / player_ctrl
  input  wire       at_goal, new_row,                 // from player_ctrl
  input  wire [2:0] sw_level,                         // SW[2:0], debug start level
  output reg  [2:0] state,
  output reg  [2:0] level,
  output reg  [1:0] lives,
  output wire       play_tick,
  output reg        respawn,
  output reg        level_load,
  output wire [3:0] score_th, score_h, score_t,       // BCD
  output wire [3:0] timer_tens, timer_ones            // BCD seconds
);
`include "crossy_defs.vh"

  reg [6:0] hold_cnt;                 // frames left in DEATH or LEVEL_CLEAR

  // ---------------------------------------------------------- events
  // Each is high for the single frame-tick cycle on which it happens.
  wire [2:0] start_level = (sw_level >= FIRST_LEVEL && sw_level <= LAST_LEVEL)
                           ? sw_level : FIRST_LEVEL;
  wire timer_zero = 1'b0;             // milestone 7
  wire dying      = hit_car || in_water || carried_off || timer_zero;

  wire tick_title = frame_tick && (state == S_TITLE);
  wire tick_play  = frame_tick && (state == S_PLAY);
  wire tick_pause = frame_tick && (state == S_PAUSE);
  wire tick_death = frame_tick && (state == S_DEATH);
  wire tick_clear = frame_tick && (state == S_LEVEL_CLEAR);
  wire tick_end   = frame_tick && (state == S_GAME_OVER || state == S_WIN);

  wire start_evt  = tick_title && req_c;
  wire goal_evt   = tick_play && at_goal;
  wire death_evt  = tick_play && !at_goal && dying;
  wire pause_evt  = tick_play && !at_goal && !dying && req_c;
  wire resume_evt = tick_pause && req_c;
  wire death_done = tick_death && (hold_cnt == 7'd0);
  wire clear_done = tick_clear && (hold_cnt == 7'd0);
  wire respawn_evt    = death_done && (lives != 2'd0);
  wire game_over_evt  = death_done && (lives == 2'd0);
  wire next_level_evt = clear_done && (level < LAST_LEVEL);
  wire win_evt        = clear_done && (level >= LAST_LEVEL);
  wire title_evt      = tick_end && req_c;

  assign play_tick = tick_play;

  // ---------------------------------------------------------- state, level, lives, hold
  always @(posedge clk) begin
    respawn    <= 1'b0;
    level_load <= 1'b0;
    if (reset) begin
      state    <= S_TITLE;
      level    <= FIRST_LEVEL;
      lives    <= 2'd0;
      hold_cnt <= 7'd0;
    end else begin
      if (start_evt) begin
        state      <= S_PLAY;
        level      <= start_level;
        lives      <= START_LIVES;
        level_load <= 1'b1;
        respawn    <= 1'b1;
      end
      if (goal_evt) begin
        state    <= S_LEVEL_CLEAR;
        hold_cnt <= HOLD_CLEAR;
      end
      if (death_evt) begin
        state    <= S_DEATH;
        lives    <= lives - 2'd1;
        hold_cnt <= HOLD_DEATH;
      end
      if (pause_evt)  state <= S_PAUSE;
      if (resume_evt) state <= S_PLAY;
      if ((tick_death || tick_clear) && hold_cnt != 7'd0)
        hold_cnt <= hold_cnt - 7'd1;
      if (respawn_evt) begin
        state   <= S_PLAY;
        respawn <= 1'b1;
      end
      if (game_over_evt) state <= S_GAME_OVER;
      if (next_level_evt) begin
        state      <= S_PLAY;
        level      <= level + 3'd1;
        level_load <= 1'b1;
        respawn    <= 1'b1;
      end
      if (win_evt)   state <= S_WIN;
      if (title_evt) state <= S_TITLE;
      if (frame_tick && state > S_WIN) state <= S_TITLE;   // unused code 7: recover
    end
  end

  // ---------------------------------------------------------- score and timer
  assign score_th   = 4'd0;
  assign score_h    = 4'd0;
  assign score_t    = 4'd0;
  assign timer_tens = 4'd0;
  assign timer_ones = 4'd0;

endmodule
`default_nettype wire
