module dump();
initial begin
  $dumpfile("waveforms/bias_parent.vcd");
  $dumpvars(0, bias_parent); 
end
endmodule