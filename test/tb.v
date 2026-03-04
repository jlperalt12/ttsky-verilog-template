`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump signals for waveform viewing
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
  end

  // Clock: 50 MHz (20ns period)
  reg clk = 0;
  always #10 clk = ~clk;

  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;

  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_example user_project (
    .ui_in  (ui_in),
    .uo_out (uo_out),
    .uio_in (uio_in),
    .uio_out(uio_out),
    .uio_oe (uio_oe),
    .ena    (ena),
    .clk    (clk),
    .rst_n  (rst_n)
  );

endmodule
