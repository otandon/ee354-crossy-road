`timescale 1ns / 1ps
`default_nettype none
// tb_playthrough -- integration of game_fsm, player_ctrl, lane_engine and
// collision (no display, frame_tick every 10 clocks), played by a simple
// look-ahead bot. Two things are checked:
//
// 1. Every level can be cleared: starting at each level with SW2..0, the bot
//    must reach LEVEL_CLEAR within MAX_GAMES games.
// 2. The RTL agrees with an independent model of DESIGN 8.2/8.3. Before each
//    frame tick the bot predicts, from the lane data, whether the chicken
//    survives the next tick after its chosen action (road: neither body edge
//    x+4 / x+27 on a car; river: center x+16 on a log and not carried past an
//    edge; snap on non-river rows). The FSM must enter DEATH on the following
//    tick exactly when the model predicts death (timer deaths excluded).
module tb_playthrough;
`include "crossy_defs.vh"

  localparam integer MAX_GAMES   = 3;
  localparam integer HORIZON     = 60;   // frames of look-ahead
  localparam integer NEED        = 10;   // frames a new row must stay safe
  localparam integer TICK_CLOCKS = 10;
  // BLIND = 1: the bot always hops up without looking (used to check that the
  // model's death predictions agree with the RTL when deaths do happen).
  parameter integer BLIND = 0;

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg reset = 1'b1;
  reg frame_tick = 1'b0;
  reg req_u = 1'b0, req_d = 1'b0, req_l = 1'b0, req_r = 1'b0, req_c = 1'b0;
  reg [2:0] sw_level = 3'd1;

  wire [2:0]  state, level;
  wire [1:0]  lives;
  wire        play_tick, respawn, level_load;
  wire [3:0]  score_th, score_h, score_t, timer_tens, timer_ones;
  wire [9:0]  player_x;
  wire [3:0]  player_row;
  wire        at_goal, new_row, carried_off, hit_car, in_water;
  wire [25:0] lane_r, lane_p;
  wire [9:0]  off_r, off_p;

  game_fsm fsm(.clk(clk), .reset(reset), .frame_tick(frame_tick), .req_c(req_c),
               .hit_car(hit_car), .in_water(in_water), .carried_off(carried_off),
               .at_goal(at_goal), .new_row(new_row), .sw_level(sw_level),
               .state(state), .level(level), .lives(lives),
               .play_tick(play_tick), .respawn(respawn), .level_load(level_load),
               .score_th(score_th), .score_h(score_h), .score_t(score_t),
               .timer_tens(timer_tens), .timer_ones(timer_ones));
  player_ctrl pc(.clk(clk), .reset(reset), .play_tick(play_tick),
                 .respawn(respawn), .level_load(level_load),
                 .req_u(req_u), .req_d(req_d), .req_l(req_l), .req_r(req_r),
                 .lane_p(lane_p), .player_x(player_x), .player_row(player_row),
                 .at_goal(at_goal), .new_row(new_row), .carried_off(carried_off));
  lane_engine le(.clk(clk), .reset(reset), .play_tick(play_tick),
                 .level_load(level_load), .level(level),
                 .row_r(4'd0), .row_p(player_row),
                 .lane_r(lane_r), .lane_p(lane_p), .off_r(off_r), .off_p(off_p));
  collision co(.clk(clk), .reset(reset), .lane_p(lane_p), .off_p(off_p),
               .player_x(player_x), .hit_car(hit_car), .in_water(in_water));

  integer errors = 0;

  // ------------------------------------------------------------ lane snapshot
  reg [25:0] L [0:14];
  integer    O [0:14];
  integer r;
  task snapshot;
    begin
      for (r = 0; r < 15; r = r + 1) begin
        L[r] = le.lanes[26*r +: 26];
        O[r] = le.offs[10*r +: 10];
      end
    end
  endtask

  // offset of row rr after k more ticks
  function integer fut_off;
    input integer rr, k;
    integer s;
    begin
      s = L[rr][22:20];
      if (L[rr][23] == DIR_RIGHT) fut_off = (O[rr] + k * s) % 640;
      else                        fut_off = ((O[rr] - k * s) % 640 + 640) % 640;
    end
  endfunction

  function is_river;
    input integer rr;
    begin
      is_river = (L[rr][25:24] == K_RIVER);
    end
  endfunction

  function integer vel;   // signed px per tick of row rr
    input integer rr;
    begin
      vel = (L[rr][23] == DIR_RIGHT) ? L[rr][22:20] : -L[rr][22:20];
    end
  endfunction

  // chicken at (rr, p) survives the state after k ticks
  function safe_at;
    input integer rr, p, k;
    integer o;
    begin
      o = fut_off(rr, k);
      case (L[rr][25:24])
        K_ROAD:  safe_at = !occupied(L[rr][19:0], o[9:0], p[9:0] + BODY_LEFT) &&
                           !occupied(L[rr][19:0], o[9:0], p[9:0] + BODY_RIGHT);
        K_RIVER: safe_at =  occupied(L[rr][19:0], o[9:0], p[9:0] + BODY_CENTER);
        default: safe_at = 1'b1;
      endcase
    end
  endfunction

  function integer snap;
    input integer p;
    begin
      snap = ((p + 16) / 32) * 32;
    end
  endfunction

  // How many ticks the chicken survives after taking action a now and then
  // waiting. a: 0 stay, 1 up, 2 down, 3 left, 4 right. -1 = hop not possible.
  function integer horizon;
    input integer a, row0, x0;
    integer rr, p, k, v, h, alive;
    begin
      rr = row0; p = x0;
      h = 0;
      if ((a == 1 && row0 == 0) || (a == 2 && row0 == 14) ||
          (a == 3 && x0 < 32)   || (a == 4 && x0 > 576)) begin
        horizon = -1;
      end else begin
        // position after the coming tick
        case (a)
          1: rr = row0 - 1;
          2: rr = row0 + 1;
          3: p = x0 - 32;
          4: p = x0 + 32;
          default: begin
            if (is_river(row0)) p = x0 + vel(row0);   // (carried-off handled below)
            else                p = snap(x0);
          end
        endcase
        alive = 1;
        // the stay action on a river can itself be a carried-off death now
        if (a == 0 && is_river(row0) && (x0 + vel(row0) < 0 || x0 + vel(row0) > 608)) alive = 0;
        if (rr == 0) begin
          h = (alive) ? HORIZON : 0;                   // goal: level cleared next tick
          alive = 0;
        end
        for (k = 1; k <= HORIZON && alive; k = k + 1) begin
          if (!safe_at(rr, p, k)) alive = 0;
          else if (is_river(rr) && (p + vel(rr) < 0 || p + vel(rr) > 608)) begin
            h = k; alive = 0;                          // survives k, carried off next
          end else begin
            h = k;
            p = is_river(rr) ? p + vel(rr) : snap(p);
          end
        end
        horizon = h;
      end
    end
  endfunction

  // ------------------------------------------------------------ one frame
  task frame;
    input [4:0] udlrc;
    begin
      @(negedge clk);
      {req_u, req_d, req_l, req_r, req_c} = udlrc;
      frame_tick = 1'b1;
      @(negedge clk);
      frame_tick = 1'b0;
      {req_u, req_d, req_l, req_r, req_c} = 5'd0;
      repeat (TICK_CLOCKS - 2) @(negedge clk);
    end
  endtask

  integer h_act [0:4];
  integer a, best, choice, predicted;
  integer lv, games, frames_used, deaths, cleared, mismatches;
  integer predicted_deaths = 0, actual_deaths = 0;
  integer total_deaths [1:5];
  integer clear_frames [1:5];
  reg [2:0] st_before;
  reg       timer_was_zero;
  reg [4:0] keys;

  initial begin
    mismatches = 0;
    for (lv = 1; lv <= 5; lv = lv + 1) begin
      cleared = 0; deaths = 0; games = 0; frames_used = 0;
      while (!cleared && games < MAX_GAMES) begin
        games = games + 1;
        @(negedge clk); reset = 1'b1; @(negedge clk); reset = 1'b0;
        sw_level = lv[2:0];
        frame(5'b00001);                                // BtnC: start
        if (state !== S_PLAY || level !== lv[2:0]) begin
          errors = errors + 1; $display("FAIL could not start level %0d", lv);
        end
        while (state != S_GAME_OVER && state != S_LEVEL_CLEAR && frames_used < 200000) begin
          frames_used = frames_used + 1;
          keys = 5'd0;
          predicted = -2;
          if (state == S_PLAY) begin
            snapshot;
            for (a = 0; a < 5; a = a + 1)
              h_act[a] = horizon(a, player_row, player_x);
            // up if the next row stays safe long enough, else wait if safe,
            // else take whatever survives longest
            if (BLIND != 0)
              choice = (player_row != 0) ? 1 : 0;
            else if (h_act[1] >= NEED || (player_row == 1 && h_act[1] >= 1))
              choice = 1;
            else if (h_act[0] >= 2)
              choice = 0;
            else begin
              best = 0;
              for (a = 1; a < 5; a = a + 1) if (h_act[a] > h_act[best]) best = a;
              choice = best;
            end
            predicted = h_act[choice];
            case (choice)
              1: keys = 5'b10000;
              2: keys = 5'b01000;
              3: keys = 5'b00100;
              4: keys = 5'b00010;
              default: keys = 5'b00000;
            endcase
          end
          st_before = state;
          frame(keys);
          // model check: the tick after this one decides death
          if (st_before == S_PLAY && state == S_PLAY) begin
            timer_was_zero = (timer_tens == 4'd0 && timer_ones == 4'd0);
            frame(5'd0);
            frames_used = frames_used + 1;
            if (!timer_was_zero && !at_goal) begin
              if (predicted == 0) predicted_deaths = predicted_deaths + 1;
              if (state == S_DEATH) actual_deaths = actual_deaths + 1;
              if ((state == S_DEATH) != (predicted == 0)) begin
                mismatches = mismatches + 1;
                if (mismatches < 10)
                  $display("FAIL level %0d: model predicted horizon %0d for action %0d but state is %0d (row %0d x %0d)",
                           lv, predicted, choice, state, player_row, player_x);
              end
            end
          end
          if (state == S_DEATH) begin
            deaths = deaths + 1;
            while (state == S_DEATH) frame(5'd0);
          end
        end
        if (state == S_LEVEL_CLEAR) cleared = 1;
      end
      total_deaths[lv] = deaths;
      clear_frames[lv] = frames_used;
      if (cleared)
        $display("level %0d cleared in game %0d: %0d frames (%0d s of play), %0d lives lost",
                 lv, games, frames_used, frames_used / 60, deaths);
      else begin
        errors = errors + 1;
        $display("FAIL level %0d not cleared in %0d games (%0d lives lost)", lv, MAX_GAMES, deaths);
      end
    end

    $display("model check: %0d deaths predicted, %0d observed, %0d mismatches",
             predicted_deaths, actual_deaths, mismatches);
    errors = errors + mismatches;
    if (errors == 0) $display("PASS tb_playthrough");
    else             $display("FAIL tb_playthrough");
    $finish;
  end
endmodule
`default_nettype wire
