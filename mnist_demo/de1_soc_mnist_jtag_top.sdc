# ABOUTME: Defines the primary 50 MHz board clock for the JTAG-driven MNIST top-level.
# ABOUTME: Keeps timing constraints aligned with the DE1-SoC CLOCK_50 oscillator.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
