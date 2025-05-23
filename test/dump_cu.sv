  module dump();
  initial begin
    $dumpfile("waveforms/control_unit.vcd");
    $dumpvars(0, control_unit); 
  end
  endmodule