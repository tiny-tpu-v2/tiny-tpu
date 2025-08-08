  module dump();
  initial begin
    $dumpfile("waveforms/nn.vcd");
    $dumpvars(0, nn); 
  end
  endmodule