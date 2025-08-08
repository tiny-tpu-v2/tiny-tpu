  module dump();
  initial begin
    $dumpfile("waveforms/weight_acc.vcd");
    $dumpvars(0, weight_acc); 
  end
  endmodule