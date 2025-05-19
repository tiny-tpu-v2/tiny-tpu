  module dump();
  initial begin
    $dumpfile("waveforms/layer1.vcd");
    $dumpvars(0, layer1); 
  end
  endmodule