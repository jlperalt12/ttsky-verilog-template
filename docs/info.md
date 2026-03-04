<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a digital coin flip on a 7-segment display. A  toggle flips between 0 and 1 every clock cycle. When the user presses the flip button, the current toggle value is latched and displayed as either **H** (heads) or **t** (tails) on the 7-segment display.

### Pin mapping


 ui_in[0]:   Flip button (active-high)                
 uo_out[6:0]:7-segment segments {a,b,c,d,e,f,g}      
 uo_out[7]: Cathode select (always 0 = right digit)  

## How to test

1. Apply reset (active-low `rst_n`), then release. The display should be blank.
2. Press the flip button (`ui_in[0]` high). After releasing, the display shows **H** or **t**.
3. Press the button again for another coin flip. Each press produces a new random result.

## External hardware

[Digilent Pmod SSD](https://digilent.com/reference/pmod/pmodssd/reference-manual) — two-digit seven-segment display (active-HIGH, common cathode). Only the right digit is used.

## AI Implementation 
I wrote the system verilog implementation and had verilog adjust it to verilog. I also had it create the test benches
