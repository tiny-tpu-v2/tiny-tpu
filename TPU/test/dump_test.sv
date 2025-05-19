module dump();
    initial begin
        // Write waveform data to "dut.vcd"
        $dumpfile("test.vcd");
        // Dump all signals in the DUT hierarchy
        $dumpvars(0, test);
        // Let one time unit pass to capture initial state
        #1;
    end
endmodule
