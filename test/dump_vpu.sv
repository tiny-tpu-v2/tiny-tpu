module dump();
initial begin
  $dumpfile("waveforms/vpu.vcd");
  $dumpvars(0, vpu); 
end
endmodule