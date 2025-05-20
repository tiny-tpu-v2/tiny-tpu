module dump();
initial begin
    $dumpfile("systolic_array.vcd");
    $dumpvars(0, systolic_array);
end
endmodule