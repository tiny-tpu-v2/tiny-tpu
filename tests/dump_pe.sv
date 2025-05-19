module dump();
initial begin
    $dumpfile("pe.vcd");
    $dumpvars(0, pe);
end
endmodule