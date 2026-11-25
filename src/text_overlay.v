`timescale 1ns / 1ps
`default_nettype none
// text_overlay -- block-letter messages for the title, pause, level-clear,
// game-over and win screens (DESIGN 4).
// 8x8 glyphs drawn at 8x scale: each character cell is 64x64 px, ten cells
// per line. Character index x[9:6], glyph pixel column x[5:3], glyph pixel
// row y[5:3]. Two text lines: y[8:6] == 2 (y 128..191) and y[8:6] == 4
// (y 256..319). Combinational: message ROM (state, line, index) -> glyph,
// then glyph ROM (glyph, row) -> 8 pixel bits, MSB = leftmost column.
// Glyphs are a 5x7 font in columns 1..5 and rows 0..6 of the 8x8 cell, so
// neighboring letters are 24 px apart.
module text_overlay(
  input  wire [9:0] x, y,
  input  wire [2:0] state,
  output wire       text_on          // this pixel is part of a letter
);
`include "crossy_defs.vh"

  // ---------------------------------------------------------- glyph numbers
  localparam [4:0] G_SP = 5'd0;
  localparam [4:0] G_A  = 5'd1;
  localparam [4:0] G_C  = 5'd2;
  localparam [4:0] G_D  = 5'd3;
  localparam [4:0] G_E  = 5'd4;
  localparam [4:0] G_G  = 5'd5;
  localparam [4:0] G_I  = 5'd6;
  localparam [4:0] G_L  = 5'd7;
  localparam [4:0] G_M  = 5'd8;
  localparam [4:0] G_N  = 5'd9;
  localparam [4:0] G_O  = 5'd10;
  localparam [4:0] G_P  = 5'd11;
  localparam [4:0] G_R  = 5'd12;
  localparam [4:0] G_S  = 5'd13;
  localparam [4:0] G_U  = 5'd14;
  localparam [4:0] G_V  = 5'd15;
  localparam [4:0] G_W  = 5'd16;
  localparam [4:0] G_Y  = 5'd17;

  // ---------------------------------------------------------- position
  wire [3:0] idx   = x[9:6];          // character cell 0..9 (10..15 off screen)
  wire [2:0] gx    = x[5:3];          // glyph column
  wire [2:0] gy    = y[5:3];          // glyph row
  wire       line0 = (y[9] == 1'b0) && (y[8:6] == 3'd2);
  wire       line1 = (y[9] == 1'b0) && (y[8:6] == 3'd4);

  // ---------------------------------------------------------- message ROM
  // Centered: an n-letter word starts at cell (10 - n + 1) / 2.
  reg [4:0] glyph;
  always @(*) begin
    glyph = G_SP;
    case ({state, line1, idx})
      // TITLE: "CROSSY" / "ROAD"
      {S_TITLE, 1'b0, 4'd2}: glyph = G_C;
      {S_TITLE, 1'b0, 4'd3}: glyph = G_R;
      {S_TITLE, 1'b0, 4'd4}: glyph = G_O;
      {S_TITLE, 1'b0, 4'd5}: glyph = G_S;
      {S_TITLE, 1'b0, 4'd6}: glyph = G_S;
      {S_TITLE, 1'b0, 4'd7}: glyph = G_Y;
      {S_TITLE, 1'b1, 4'd3}: glyph = G_R;
      {S_TITLE, 1'b1, 4'd4}: glyph = G_O;
      {S_TITLE, 1'b1, 4'd5}: glyph = G_A;
      {S_TITLE, 1'b1, 4'd6}: glyph = G_D;
      // PAUSE: "PAUSED"
      {S_PAUSE, 1'b0, 4'd2}: glyph = G_P;
      {S_PAUSE, 1'b0, 4'd3}: glyph = G_A;
      {S_PAUSE, 1'b0, 4'd4}: glyph = G_U;
      {S_PAUSE, 1'b0, 4'd5}: glyph = G_S;
      {S_PAUSE, 1'b0, 4'd6}: glyph = G_E;
      {S_PAUSE, 1'b0, 4'd7}: glyph = G_D;
      // LEVEL_CLEAR: "LEVEL" / "CLEAR"
      {S_LEVEL_CLEAR, 1'b0, 4'd3}: glyph = G_L;
      {S_LEVEL_CLEAR, 1'b0, 4'd4}: glyph = G_E;
      {S_LEVEL_CLEAR, 1'b0, 4'd5}: glyph = G_V;
      {S_LEVEL_CLEAR, 1'b0, 4'd6}: glyph = G_E;
      {S_LEVEL_CLEAR, 1'b0, 4'd7}: glyph = G_L;
      {S_LEVEL_CLEAR, 1'b1, 4'd3}: glyph = G_C;
      {S_LEVEL_CLEAR, 1'b1, 4'd4}: glyph = G_L;
      {S_LEVEL_CLEAR, 1'b1, 4'd5}: glyph = G_E;
      {S_LEVEL_CLEAR, 1'b1, 4'd6}: glyph = G_A;
      {S_LEVEL_CLEAR, 1'b1, 4'd7}: glyph = G_R;
      // GAME_OVER: "GAME" / "OVER"
      {S_GAME_OVER, 1'b0, 4'd3}: glyph = G_G;
      {S_GAME_OVER, 1'b0, 4'd4}: glyph = G_A;
      {S_GAME_OVER, 1'b0, 4'd5}: glyph = G_M;
      {S_GAME_OVER, 1'b0, 4'd6}: glyph = G_E;
      {S_GAME_OVER, 1'b1, 4'd3}: glyph = G_O;
      {S_GAME_OVER, 1'b1, 4'd4}: glyph = G_V;
      {S_GAME_OVER, 1'b1, 4'd5}: glyph = G_E;
      {S_GAME_OVER, 1'b1, 4'd6}: glyph = G_R;
      // WIN: "YOU" / "WIN"
      {S_WIN, 1'b0, 4'd4}: glyph = G_Y;
      {S_WIN, 1'b0, 4'd5}: glyph = G_O;
      {S_WIN, 1'b0, 4'd6}: glyph = G_U;
      {S_WIN, 1'b1, 4'd4}: glyph = G_W;
      {S_WIN, 1'b1, 4'd5}: glyph = G_I;
      {S_WIN, 1'b1, 4'd6}: glyph = G_N;
      default: glyph = G_SP;
    endcase
  end

  // ---------------------------------------------------------- glyph ROM
  // Eight rows, row 0 first; bit 7 of each row is the leftmost column.
  reg [63:0] bits;
  always @(*) begin
    bits = 64'd0;
    case (glyph)
      G_A: bits = {8'b00111000, 8'b01000100, 8'b01000100, 8'b01111100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b00000000};
      G_C: bits = {8'b00111000, 8'b01000100, 8'b01000000, 8'b01000000, 8'b01000000, 8'b01000100, 8'b00111000, 8'b00000000};
      G_D: bits = {8'b01111000, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01111000, 8'b00000000};
      G_E: bits = {8'b01111100, 8'b01000000, 8'b01000000, 8'b01111000, 8'b01000000, 8'b01000000, 8'b01111100, 8'b00000000};
      G_G: bits = {8'b00111000, 8'b01000100, 8'b01000000, 8'b01011100, 8'b01000100, 8'b01000100, 8'b00111100, 8'b00000000};
      G_I: bits = {8'b00111000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00111000, 8'b00000000};
      G_L: bits = {8'b01000000, 8'b01000000, 8'b01000000, 8'b01000000, 8'b01000000, 8'b01000000, 8'b01111100, 8'b00000000};
      G_M: bits = {8'b01000100, 8'b01101100, 8'b01010100, 8'b01010100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b00000000};
      G_N: bits = {8'b01000100, 8'b01000100, 8'b01100100, 8'b01010100, 8'b01001100, 8'b01000100, 8'b01000100, 8'b00000000};
      G_O: bits = {8'b00111000, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b00111000, 8'b00000000};
      G_P: bits = {8'b01111000, 8'b01000100, 8'b01000100, 8'b01111000, 8'b01000000, 8'b01000000, 8'b01000000, 8'b00000000};
      G_R: bits = {8'b01111000, 8'b01000100, 8'b01000100, 8'b01111000, 8'b01010000, 8'b01001000, 8'b01000100, 8'b00000000};
      G_S: bits = {8'b00111100, 8'b01000000, 8'b01000000, 8'b00111000, 8'b00000100, 8'b00000100, 8'b01111000, 8'b00000000};
      G_U: bits = {8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b00111000, 8'b00000000};
      G_V: bits = {8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b01000100, 8'b00101000, 8'b00010000, 8'b00000000};
      G_W: bits = {8'b01000100, 8'b01000100, 8'b01000100, 8'b01010100, 8'b01010100, 8'b01010100, 8'b00101000, 8'b00000000};
      G_Y: bits = {8'b01000100, 8'b01000100, 8'b00101000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00010000, 8'b00000000};
      default: bits = 64'd0;   // space
    endcase
  end

  wire [7:0] row_bits = bits[6'd63 - {gy, 3'b000} -: 8];
  assign text_on = (line0 || line1) && row_bits[3'd7 - gx];

endmodule
`default_nettype wire
