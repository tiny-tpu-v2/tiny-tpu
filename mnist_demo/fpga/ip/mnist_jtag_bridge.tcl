# ABOUTME: Defines a minimal Platform Designer system exporting a JTAG Avalon master for host MMIO access.
# ABOUTME: Generates the bridge used by the JTAG-driven DE1-SoC MNIST top-level.
package require -exact qsys 25.1

create_system mnist_jtag_bridge
set_project_property DEVICE_FAMILY {Cyclone V}
set_project_property DEVICE {5CSEMA5F31C6}

add_instance clk_0 clock_source 25.1
set_instance_parameter_value clk_0 clockFrequency {50000000.0}

add_instance jtagm altera_jtag_avalon_master 25.1
set_instance_parameter_value jtagm FAST_VER {1}
set_instance_parameter_value jtagm PLI_PORT {50000}

add_connection clk_0.clk jtagm.clk
add_connection clk_0.clk_reset jtagm.clk_reset

set_interface_property clk EXPORT_OF clk_0.clk_in
set_interface_property reset EXPORT_OF clk_0.clk_in_reset
set_interface_property jtag_master EXPORT_OF jtagm.master

save_system mnist_jtag_bridge.qsys
