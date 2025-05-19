  module dump();
  initial begin
    $dumpfile("waveforms/pe.vcd");
    $dumpvars(0, pe); 
  end
  endmodule