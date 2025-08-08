module dump();
  initial begin
    $dumpfile("waveforms/input_acc.vcd");
    $dumpvars(0, input_acc); 
  end
endmodule