  module dump();
  initial begin
    $dumpfile("waveforms/unified_buffer.vcd");
    $dumpvars(0, unified_buffer); 
  end
  endmodule