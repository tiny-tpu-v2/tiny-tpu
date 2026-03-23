// ABOUTME: Self-checking ModelSim regression for the simplified fixed-point math blocks.
// ABOUTME: It validates the Q8.8 multiplier scaling used by the hardened TPU RTL.
`timescale 1ns/1ps
`default_nettype none

module fixedpoint_simple_regression;
    reg [15:0] mul_ina;
    reg [15:0] mul_inb;
    wire [15:0] mul_out;
    wire mul_overflow;

    integer fail_count;

    fxp_mul mul_dut (
        .ina(mul_ina),
        .inb(mul_inb),
        .out(mul_out),
        .overflow(mul_overflow)
    );

    task expect_equal;
        input [15:0] actual;
        input [15:0] expected;
        input [255:0] label;
    begin
        if (actual !== expected) begin
            fail_count = fail_count + 1;
            $display("FAIL %0s expected=%h actual=%h", label, expected, actual);
        end
    end
    endtask

    initial begin
        fail_count = 0;

        mul_ina = 16'h0100;
        mul_inb = 16'h0100;
        #1;
        expect_equal(mul_out, 16'h0100, "1.0 * 1.0");

        mul_ina = 16'h0200;
        mul_inb = 16'h0300;
        #1;
        expect_equal(mul_out, 16'h0600, "2.0 * 3.0");

        mul_ina = 16'hFF00;
        mul_inb = 16'h0200;
        #1;
        expect_equal(mul_out, 16'hFE00, "-1.0 * 2.0");

        if (fail_count == 0) begin
            $display("REGRESSION PASS");
        end else begin
            $display("REGRESSION FAIL count=%0d", fail_count);
        end

        $finish;
    end
endmodule
