`timescale 1ns / 1ps
`default_nettype none
// tb_text_overlay -- every pixel of the 640x480 screen in all seven states
// is compared with a model built from the message strings and a 5x7 font:
// text lines at y 128..191 and 256..319, 64x64 cells, the glyph in cell
// columns 1..5 and rows 0..6 at 8x scale. PLAY and DEATH have no text.
// Also checks that every message lights some pixels on its line(s).
module tb_text_overlay;
`include "crossy_defs.vh"

  reg  [9:0] x, y;
  reg  [2:0] state;
  wire       text_on;
  text_overlay dut(.x(x), .y(y), .state(state), .text_on(text_on));

  // Expected message, ten characters per line.
  function [8*10-1:0] message;
    input [2:0] st;
    input       line;
    begin
      case ({st, line})
        {S_TITLE, 1'b0}:       message = "  CROSSY  ";
        {S_TITLE, 1'b1}:       message = "   ROAD   ";
        {S_PAUSE, 1'b0}:       message = "  PAUSED  ";
        {S_LEVEL_CLEAR, 1'b0}: message = "   LEVEL  ";
        {S_LEVEL_CLEAR, 1'b1}: message = "   CLEAR  ";
        {S_GAME_OVER, 1'b0}:   message = "   GAME   ";
        {S_GAME_OVER, 1'b1}:   message = "   OVER   ";
        {S_WIN, 1'b0}:         message = "    YOU   ";
        {S_WIN, 1'b1}:         message = "    WIN   ";
        default:               message = "          ";
      endcase
    end
  endfunction

  // 5x7 font, row 0 first, leftmost column is the MSB of each 5-bit row.
  function [34:0] font;
    input [7:0] ch;
    begin
      case (ch)
        "A": font = 35'b01110_10001_10001_11111_10001_10001_10001;
        "C": font = 35'b01110_10001_10000_10000_10000_10001_01110;
        "D": font = 35'b11110_10001_10001_10001_10001_10001_11110;
        "E": font = 35'b11111_10000_10000_11110_10000_10000_11111;
        "G": font = 35'b01110_10001_10000_10111_10001_10001_01111;
        "I": font = 35'b01110_00100_00100_00100_00100_00100_01110;
        "L": font = 35'b10000_10000_10000_10000_10000_10000_11111;
        "M": font = 35'b10001_11011_10101_10101_10001_10001_10001;
        "N": font = 35'b10001_10001_11001_10101_10011_10001_10001;
        "O": font = 35'b01110_10001_10001_10001_10001_10001_01110;
        "P": font = 35'b11110_10001_10001_11110_10000_10000_10000;
        "R": font = 35'b11110_10001_10001_11110_10100_10010_10001;
        "S": font = 35'b01111_10000_10000_01110_00001_00001_11110;
        "U": font = 35'b10001_10001_10001_10001_10001_10001_01110;
        "V": font = 35'b10001_10001_10001_10001_10001_01010_00100;
        "W": font = 35'b10001_10001_10001_10101_10101_10101_01010;
        "Y": font = 35'b10001_10001_01010_00100_00100_00100_00100;
        default: font = 35'd0;
      endcase
    end
  endfunction

  function expected;
    input integer px, py;
    input [2:0] st;
    integer line, cidx, gx, gy;
    reg [8*10-1:0] msg;
    reg [7:0] ch;
    reg [34:0] f;
    begin
      expected = 1'b0;
      line = (py >= 128 && py < 192) ? 0 : (py >= 256 && py < 320) ? 1 : -1;
      if (line >= 0) begin
        msg  = message(st, line[0]);
        cidx = px / 64;
        ch   = msg[8*(9 - cidx) +: 8];
        gx   = (px % 64) / 8;
        gy   = (py % 64) / 8;
        f    = font(ch);
        if (gy < 7 && gx >= 1 && gx <= 5)
          expected = f[34 - (gy * 5 + (gx - 1))];
      end
    end
  endfunction

  integer errors = 0;
  integer s, px, py, lit0, lit1;

  initial begin
    for (s = 0; s < 8; s = s + 1) begin
      state = s[2:0];
      lit0 = 0; lit1 = 0;
      for (py = 0; py < 480; py = py + 1) begin
        for (px = 0; px < 640; px = px + 1) begin
          x = px[9:0]; y = py[9:0];
          #1;
          if (text_on !== expected(px, py, state)) begin
            errors = errors + 1;
            if (errors < 20)
              $display("FAIL state %0d pixel (%0d,%0d): text_on=%b expected %b",
                       s, px, py, text_on, expected(px, py, state));
          end
          if (text_on === 1'b1 && py < 200) lit0 = lit0 + 1;
          if (text_on === 1'b1 && py >= 200) lit1 = lit1 + 1;
        end
      end
      $display("state %0d: %0d lit pixels on line 1, %0d on line 2", s, lit0, lit1);
      // messages must actually be drawn
      if ((s == S_TITLE || s == S_PAUSE || s == S_LEVEL_CLEAR || s == S_GAME_OVER || s == S_WIN) && lit0 == 0) begin
        errors = errors + 1; $display("FAIL state %0d draws nothing on line 1", s);
      end
      if ((s == S_TITLE || s == S_LEVEL_CLEAR || s == S_GAME_OVER || s == S_WIN) && lit1 == 0) begin
        errors = errors + 1; $display("FAIL state %0d draws nothing on line 2", s);
      end
      if ((s == S_PLAY || s == S_DEATH || s == 7) && (lit0 + lit1) != 0) begin
        errors = errors + 1; $display("FAIL state %0d draws text", s);
      end
    end

    // off-screen x (640..1023) and y (480..1023) never draw text
    state = S_TITLE;
    for (px = 640; px < 1024; px = px + 7) begin
      x = px[9:0]; y = 10'd150; #1;
      if (text_on !== 1'b0) begin errors = errors + 1; $display("FAIL text at x=%0d", px); end
    end
    for (py = 480; py < 1024; py = py + 3) begin
      x = 10'd200; y = py[9:0]; #1;
      if (text_on !== 1'b0) begin errors = errors + 1; $display("FAIL text at y=%0d", py); end
    end

    if (errors == 0) $display("PASS tb_text_overlay");
    else             $display("FAIL tb_text_overlay");
    $finish;
  end
endmodule
`default_nettype wire
