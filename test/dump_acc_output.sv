  module dump();
  initial begin
    $dumpfile("waveforms/acc_output.vcd");
    $dumpvars(0, acc_output); 
  end
  endmodule