`timescale 1ns / 1ps
`default_nettype none
// game_fsm -- game state, level, lives, timer and score (DESIGN 7, 8.5, 8.6).
// Every transition except reset happens on a frame tick. Inside PLAY the
// priority is goal, then death, then pause. Score and timer are BCD.
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
  output reg  [3:0] score_th, score_h, score_t,       // BCD; ones digit is always 0
  output reg  [3:0] timer_tens, timer_ones            // BCD seconds
);
`include "crossy_defs.vh"

  reg [6:0] hold_cnt;                 // frames left in DEATH or LEVEL_CLEAR
  reg [5:0] frame_cnt;                // play_ticks within the current second

  // ---------------------------------------------------------- events
  // Each is high for the single frame-tick cycle on which it happens.
  wire [2:0] start_level = (sw_level >= FIRST_LEVEL && sw_level <= LAST_LEVEL)
                           ? sw_level : FIRST_LEVEL;
  wire timer_zero = (timer_tens == 4'd0) && (timer_ones == 4'd0);
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

  // ---------------------------------------------------------- timer (8.5)
  // Loads the level's time on game start, on respawn and on a new level;
  // counts down one second per FRAMES_PER_S play_ticks; stops at 00. Frozen
  // whenever play_tick is low (pause, death, level clear).
  function [7:0] level_time;
    input [2:0] lv;
    begin
      case (lv)
        3'd1:    level_time = TIME_L1;
        3'd2:    level_time = TIME_L2;
        3'd3:    level_time = TIME_L3;
        3'd4:    level_time = TIME_L4;
        3'd5:    level_time = TIME_L5;
        default: level_time = TIME_L1;
      endcase
    end
  endfunction

  wire       timer_load = start_evt || respawn_evt || next_level_evt;
  wire [2:0] load_level = start_evt      ? start_level :
                          next_level_evt ? level + 3'd1 : level;

  always @(posedge clk) begin
    if (reset) begin
      timer_tens <= 4'd0;
      timer_ones <= 4'd0;
      frame_cnt  <= 6'd0;
    end else if (timer_load) begin
      {timer_tens, timer_ones} <= level_time(load_level);
      frame_cnt <= 6'd0;
    end else if (play_tick) begin
      if (frame_cnt == FRAMES_PER_S - 6'd1) begin
        frame_cnt <= 6'd0;
        if (!timer_zero) begin
          if (timer_ones == 4'd0) begin
            timer_ones <= 4'd9;
            timer_tens <= timer_tens - 4'd1;
          end else begin
            timer_ones <= timer_ones - 4'd1;
          end
        end
      end else begin
        frame_cnt <= frame_cnt + 6'd1;
      end
    end
  end

  // ---------------------------------------------------------- score (8.6)
  // +10 for a new row (play_tick && new_row), +100 for a cleared level, as
  // BCD increments with carry. Cleared when a game starts. The two never
  // coincide (a hop up from row 0 is impossible), but both are handled.
  wire add_ten     = play_tick && new_row;
  wire add_hundred = goal_evt;

  reg [3:0] t_next, h_next, th_next;
  reg [4:0] t_sum, h_sum;
  reg       t_carry, h_carry;
  always @(*) begin
    t_sum   = {1'b0, score_t} + {4'd0, add_ten};
    t_carry = (t_sum >= 5'd10);
    t_next  = t_carry ? (t_sum[3:0] - 4'd10) : t_sum[3:0];
    h_sum   = {1'b0, score_h} + {4'd0, add_hundred} + {4'd0, t_carry};
    h_carry = (h_sum >= 5'd10);
    h_next  = h_carry ? (h_sum[3:0] - 4'd10) : h_sum[3:0];
    th_next = (h_carry && score_th == 4'd9) ? 4'd0 : score_th + {3'd0, h_carry};
  end

  always @(posedge clk) begin
    if (reset || start_evt) begin
      score_th <= 4'd0;
      score_h  <= 4'd0;
      score_t  <= 4'd0;
    end else if (add_ten || add_hundred) begin
      score_th <= th_next;
      score_h  <= h_next;
      score_t  <= t_next;
    end
  end

endmodule
`default_nettype wire
