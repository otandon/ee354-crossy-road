`timescale 1ns / 1ps
`default_nettype none
// tb_level_rom -- checks every (level, row) descriptor against the DESIGN 5
// layout table, the direction rule (odd rows right, even rows left), the
// speed table, the pattern rules (road/river rows non-empty, grass/goal rows
// empty) and G-10 (each level has at least as many roads and rivers, and
// speeds at least as high, as the level before).
module tb_level_rom;
`include "crossy_defs.vh"

  // Levels checked so far (milestone 2: level 1 only; milestone 8: all five).
  localparam integer LEVELS_CHECKED = 1;

  reg  [2:0]  level;
  reg  [3:0]  row;
  wire [25:0] lane;
  level_rom dut(.level(level), .row(row), .lane(lane));

  wire [1:0]  kind    = lane[25:24];
  wire        dir     = lane[23];
  wire [2:0]  speed   = lane[22:20];
  wire [19:0] pattern = lane[19:0];

  // DESIGN 5 layout table, row 0 first: Y goal, G grass, R road, W river.
  function [8*15-1:0] layout;
    input integer lv;
    begin
      case (lv)
        1: layout = "YGGGGWGGGGRGRGG";
        2: layout = "YGGWWGGGRRGRRGG";
        3: layout = "YGWWWWGRRGRRRGG";
        4: layout = "YGWWWWGRRRGRRRG";
        5: layout = "YWWWWWGRRRRRRRG";
        default: layout = "GGGGGGGGGGGGGGG";
      endcase
    end
  endfunction

  function [7:0] layout_char;
    input integer lv;
    input integer r;
    reg [8*15-1:0] s;
    begin
      s = layout(lv);
      layout_char = s[8*(14 - r) +: 8];
    end
  endfunction

  // DESIGN 5 speed table. "Alternating by row": even rows take the first
  // value, odd rows the second.
  function [2:0] road_speed;
    input integer lv;
    input integer r;
    begin
      case (lv)
        1: road_speed = 3'd1;
        2: road_speed = (r % 2 == 0) ? 3'd1 : 3'd2;
        3: road_speed = 3'd2;
        4: road_speed = (r % 2 == 0) ? 3'd2 : 3'd3;
        5: road_speed = (r % 2 == 0) ? 3'd3 : 3'd4;
        default: road_speed = 3'd0;
      endcase
    end
  endfunction

  function [2:0] river_speed;
    input integer lv;
    begin
      case (lv)
        1: river_speed = 3'd1;
        2: river_speed = 3'd1;
        3: river_speed = 3'd2;
        4: river_speed = 3'd2;
        5: river_speed = 3'd3;
        default: river_speed = 3'd0;
      endcase
    end
  endfunction

  integer errors = 0;
  integer lv, r;
  integer roads, rivers, min_spd, max_spd;
  integer prev_roads, prev_rivers, prev_min, prev_max;
  reg [7:0] c;
  reg [1:0] exp_kind;

  initial begin
    prev_roads = 0; prev_rivers = 0; prev_min = 0; prev_max = 0;
    for (lv = 1; lv <= LEVELS_CHECKED; lv = lv + 1) begin
      roads = 0; rivers = 0; min_spd = 7; max_spd = 0;
      for (r = 0; r < 16; r = r + 1) begin
        level = lv[2:0];
        row   = r[3:0];
        #1;
        c = (r < 15) ? layout_char(lv, r) : "G";
        case (c)
          "Y": exp_kind = K_GOAL;
          "R": exp_kind = K_ROAD;
          "W": exp_kind = K_RIVER;
          default: exp_kind = K_GRASS;
        endcase
        if (kind !== exp_kind) begin
          errors = errors + 1;
          $display("FAIL level %0d row %0d: kind %0d, expected %0d ('%s')", lv, r, kind, exp_kind, c);
        end
        if (exp_kind == K_ROAD || exp_kind == K_RIVER) begin
          if (exp_kind == K_ROAD)  roads  = roads + 1;
          if (exp_kind == K_RIVER) rivers = rivers + 1;
          if (pattern == 20'd0) begin
            errors = errors + 1;
            $display("FAIL level %0d row %0d: moving lane with empty pattern", lv, r);
          end
          if (dir !== ((r % 2 == 1) ? DIR_RIGHT : DIR_LEFT)) begin
            errors = errors + 1;
            $display("FAIL level %0d row %0d: dir %b breaks the odd-right/even-left rule", lv, r, dir);
          end
          if (speed > 3'd4 || speed == 3'd0) begin
            errors = errors + 1;
            $display("FAIL level %0d row %0d: speed %0d outside 1..4", lv, r, speed);
          end
          if (exp_kind == K_ROAD && speed !== road_speed(lv, r)) begin
            errors = errors + 1;
            $display("FAIL level %0d row %0d: road speed %0d, expected %0d", lv, r, speed, road_speed(lv, r));
          end
          if (exp_kind == K_RIVER && speed !== river_speed(lv)) begin
            errors = errors + 1;
            $display("FAIL level %0d row %0d: river speed %0d, expected %0d", lv, r, speed, river_speed(lv));
          end
          if (speed < min_spd) min_spd = speed;
          if (speed > max_spd) max_spd = speed;
        end else if (pattern !== 20'd0 || speed !== 3'd0) begin
          errors = errors + 1;
          $display("FAIL level %0d row %0d: grass/goal row has pattern %h speed %0d", lv, r, pattern, speed);
        end
      end
      $display("level %0d: %0d roads, %0d rivers, speeds %0d..%0d", lv, roads, rivers, min_spd, max_spd);
      if (roads < prev_roads || rivers < prev_rivers || min_spd < prev_min || max_spd < prev_max) begin
        errors = errors + 1;
        $display("FAIL level %0d is easier than level %0d (G-10)", lv, lv - 1);
      end
      prev_roads = roads; prev_rivers = rivers; prev_min = min_spd; prev_max = max_spd;
    end

    // Levels 0, 6, 7 are never used; they must read as plain grass.
    for (lv = 0; lv < 8; lv = lv + 1) begin
      for (r = 0; r < 16; r = r + 1) begin
        level = lv[2:0]; row = r[3:0]; #1;
        if ((lv == 0 || lv >= 6) && lane !== LANE_GRASS) begin
          errors = errors + 1;
          $display("FAIL unused level %0d row %0d is not grass", lv, r);
        end
      end
    end

    if (errors == 0) $display("PASS tb_level_rom");
    else             $display("FAIL tb_level_rom");
    $finish;
  end
endmodule
`default_nettype wire
