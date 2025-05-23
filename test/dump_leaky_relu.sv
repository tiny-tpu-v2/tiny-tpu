  module dump();
  initial begin
    $dumpfile("waveforms/leaky_relu.vcd");
    $dumpvars(0, leaky_relu); 
  end
  endmodule