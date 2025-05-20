  module dump();
  initial begin
    $dumpfile("waveforms/accumulator.vcd");
    $dumpvars(0, accumulator); 
  end
  endmodule