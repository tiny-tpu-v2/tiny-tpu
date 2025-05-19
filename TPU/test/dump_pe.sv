module dump();
    initial begin
        // Write waveform data to "dut.vcd"
        $dumpfile("pe.vcd");
        // Dump all signals in the DUT hierarchy
        $dumpvars(0, pe);
        // Let one time unit pass to capture initial state
        #1;
    end
endmodule
