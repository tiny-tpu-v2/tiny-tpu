module dump();
  initial begin
    $dumpfile("waveforms/unified_buffer.vcd");
    $dumpvars(0, unified_buffer);  // dumps module-level signals
    
    // dump memory array elements for visibility
    // for (int i = 0; i < unified_buffer.UNIFIED_BUFFER_WIDTH; i++) begin
    //     $dumpvars(0, unified_buffer.ub_memory[i]);
    // end
  end
endmodule