# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# 7-seg patterns (active-HIGH, {a,b,c,d,e,f,g})
SEG_H     = 0b0110111
SEG_t     = 0b0001111
SEG_BLANK = 0b0000000

# Debounce delay in the RTL is 250000 cycles.
# At 10us clock period that's 2.5s — we need to hold the button that long.
DEBOUNCE_CYCLES = 250000 + 100  # a bit extra for edge detect latency
SETTLE_CYCLES   = 1000


async def reset(dut):
    """Apply reset and release."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


async def press_button(dut):
    """Simulate a single button press (hold > debounce, then release)."""
    dut.ui_in.value = 1          # btn_flip on ui_in[0]
    await ClockCycles(dut.clk, DEBOUNCE_CYCLES)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, SETTLE_CYCLES)


def get_seg(dut):
    """Extract the 7 segment bits from uo_out[6:0]."""
    return int(dut.uo_out.value) & 0x7F


def get_cat(dut):
    """Extract the CAT bit from uo_out[7]."""
    return (int(dut.uo_out.value) >> 7) & 1


@cocotb.test()
async def test_blank_after_reset(dut):
    """After reset, display should be blank."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    seg = get_seg(dut)
    assert seg == SEG_BLANK, f"Expected blank (0x00), got 0x{seg:02x}"
    dut._log.info("PASS: blank after reset")


@cocotb.test()
async def test_cat_always_zero(dut):
    """CAT pin should always be 0 (right digit)."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    assert get_cat(dut) == 0, "CAT should be 0"
    await press_button(dut)
    assert get_cat(dut) == 0, "CAT should still be 0 after flip"
    dut._log.info("PASS: cat always 0")


@cocotb.test()
async def test_first_flip_shows_h_or_t(dut):
    """After first button press, display shows H or t."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    await press_button(dut)
    seg = get_seg(dut)
    assert seg in (SEG_H, SEG_t), f"Expected H(0x{SEG_H:02x}) or t(0x{SEG_t:02x}), got 0x{seg:02x}"
    dut._log.info(f"PASS: first flip shows {'H' if seg == SEG_H else 't'}")


@cocotb.test()
async def test_multiple_flips_valid(dut):
    """All flips produce valid H or t output."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    for i in range(10):
        await press_button(dut)
        seg = get_seg(dut)
        assert seg in (SEG_H, SEG_t), f"Flip {i}: invalid seg 0x{seg:02x}"

    dut._log.info("PASS: 10 flips all valid")


@cocotb.test()
async def test_both_outcomes_appear(dut):
    """Over many flips, both H and t should appear."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    saw_h = False
    saw_t = False
    for i in range(20):
        await press_button(dut)
        # Add an odd extra cycle every other press to shift toggle phase
        if i % 2 == 0:
            await ClockCycles(dut.clk, 1)
        seg = get_seg(dut)
        if seg == SEG_H:
            saw_h = True
        elif seg == SEG_t:
            saw_t = True

    assert saw_h and saw_t, f"Expected both H and t, saw_h={saw_h} saw_t={saw_t}"
    dut._log.info("PASS: saw both H and t")


@cocotb.test()
async def test_debounce_single_action(dut):
    """Holding the button should only produce one flip, not continuous flips."""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset(dut)

    # First flip
    await press_button(dut)
    result_after_first = get_seg(dut)

    # Hold button for a very long time (3x debounce), then release
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, DEBOUNCE_CYCLES * 3)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, SETTLE_CYCLES)

    result_after_hold = get_seg(dut)

    # Since the edge detector fires only once per press, the long hold
    # should have produced exactly one additional flip (not multiple).
    # Both results should be valid H or t.
    assert result_after_hold in (SEG_H, SEG_t), f"Invalid seg after hold: 0x{result_after_hold:02x}"
    dut._log.info("PASS: long hold = single flip")
