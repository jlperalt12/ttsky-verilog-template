/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// ============================================================================
// TinyTapeout Top — Coin Flip
// ============================================================================
// ui_in[0]     = flip button (active-high)
// uo_out[6:0]  = 7-seg segments {a,b,c,d,e,f,g} (active-HIGH, common cathode)
// uo_out[7]    = CAT digit select (directly directly directly directly directly -- always 0, right digit)
//
// Press button → display shows H (heads) or t (tails).
// Blank until first press.
// ============================================================================

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire reset = ~rst_n;  // TT is active-low reset; our modules use active-high

  wire [6:0] seg;
  wire       cat;

  coin_flip #(
    .DEBOUNCE_DELAY(250000)   // ~5 ms at 50 MHz
  ) u_coin (
    .clk_i     (clk),
    .reset_i   (reset),
    .btn_flip_i(ui_in[0]),
    .seg_o     (seg),
    .cat_o     (cat)
  );

  assign uo_out = {cat, seg};

  // Unused bidirectional IOs — set to input mode
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Suppress unused-input warnings
  wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule

// ============================================================================
// Coin Flip Module
// ============================================================================
module coin_flip #(
    parameter DEBOUNCE_DELAY = 250000
)(
    input  wire       clk_i,
    input  wire       reset_i,
    input  wire       btn_flip_i,
    output reg  [6:0] seg_o,
    output wire       cat_o
);

  // 7-seg patterns (active-HIGH, common cathode)
  //   seg = {a, b, c, d, e, f, g}
  localparam SEG_H     = 7'b0110111; // H: segments b,c,e,f,g
  localparam SEG_t     = 7'b0001111; // t: segments d,e,f,g
  localparam SEG_BLANK = 7'b0000000;

  // Debounce + edge detect
  wire btn_db, btn_pulse, btn_unp;

  debounce #(.min_delay_p(DEBOUNCE_DELAY)) u_db (
    .clk_i(clk_i), .reset_i(reset_i),
    .button_i(btn_flip_i), .button_o(btn_db)
  );

  detect_edge u_edge (
    .clk_i(clk_i), .reset_i(reset_i),
    .button_i(btn_db), .button_o(btn_pulse), .unbutton_o(btn_unp)
  );

  // Free-running toggle (flips every clock cycle)
  reg toggle_r;
  always @(posedge clk_i) begin
    if (reset_i)
      toggle_r <= 1'b0;
    else
      toggle_r <= ~toggle_r;
  end

  // Latch result on button press
  reg result_r;      // 0 = tails (t), 1 = heads (H)
  reg has_result_r;  // 1 after first flip

  always @(posedge clk_i) begin
    if (reset_i) begin
      result_r     <= 1'b0;
      has_result_r <= 1'b0;
    end else if (btn_pulse) begin
      result_r     <= toggle_r;
      has_result_r <= 1'b1;
    end
  end

  // Only use right digit
  assign cat_o = 1'b0;

  // Segment output
  always @(*) begin
    if (!has_result_r)
      seg_o = SEG_BLANK;
    else if (result_r)
      seg_o = SEG_H;
    else
      seg_o = SEG_t;
  end

endmodule

// ============================================================================
// Debouncer — counts consecutive high samples, outputs high when saturated
// ============================================================================
module debounce #(
    parameter min_delay_p = 4
)(
    input  wire clk_i,
    input  wire reset_i,
    input  wire button_i,
    output reg  button_o
);

  reg [$clog2(min_delay_p):0] count_r;
  localparam [$clog2(min_delay_p):0] MAX_COUNT = min_delay_p[$clog2(min_delay_p):0];

  always @(posedge clk_i) begin
    if (reset_i) begin
      count_r  <= 0;
      button_o <= 1'b0;
    end else if (!button_i) begin
      count_r  <= 0;
      button_o <= 1'b0;
    end else if (count_r < MAX_COUNT) begin
      count_r <= count_r + 1;
    end else begin
      button_o <= 1'b1;
    end
  end

endmodule

// ============================================================================
// Edge Detector — produces one-cycle pulse on rising/falling edge
// ============================================================================
module detect_edge (
    input  wire clk_i,
    input  wire reset_i,
    input  wire button_i,
    output wire button_o,
    output wire unbutton_o
);

  reg state_l, prev_state_l;

  always @(posedge clk_i or posedge reset_i) begin
    if (reset_i) begin
      state_l      <= 1'b0;
      prev_state_l <= 1'b0;
    end else begin
      state_l      <= button_i;
      prev_state_l <= state_l;
    end
  end

  assign button_o   = ~prev_state_l & state_l;
  assign unbutton_o = prev_state_l & ~state_l;

endmodule
