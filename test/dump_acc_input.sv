module dump();
initial begin
    $dumpfile("waveforms/acc_input.vcd");
    $dumpvars(0, acc_input); 
end
endmodule