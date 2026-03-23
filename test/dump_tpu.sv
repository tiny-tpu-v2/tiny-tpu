module dump();
initial begin
  $dumpfile("waveforms/tpu.vcd");
  $dumpvars(0, tpu); 
end
endmodule