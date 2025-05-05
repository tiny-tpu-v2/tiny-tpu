// dump_dut.sv
// Generates a VCD dump for the DUT module

module dump();
    initial begin
        // Write waveform data to "dut.vcd"
        $dumpfile("dut.vcd");
        // Dump all signals in the DUT hierarchy
        $dumpvars(0, dut);
        // Let one time unit pass to capture initial state
        #1;
    end
endmodule
