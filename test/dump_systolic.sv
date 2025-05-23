  module dump();
  initial begin
    $dumpfile("waveforms/systolic.vcd");
    $dumpvars(0, systolic); 
  end
  endmodule