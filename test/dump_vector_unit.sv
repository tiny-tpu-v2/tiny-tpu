module dump();
initial begin
  $dumpfile("waveforms/vector_unit.vcd");
  $dumpvars(0, vector_unit); 
end
endmodule