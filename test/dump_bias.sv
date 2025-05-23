  module dump();
  initial begin
    $dumpfile("waveforms/bias.vcd");
    $dumpvars(0, bias); 
  end
  endmodule