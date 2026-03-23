# ABOUTME: Defines the primary 50 MHz board clock for the DE1-SoC MNIST demo.
# ABOUTME: Keeps the Quartus timing model aligned with the board top-level clock input.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
