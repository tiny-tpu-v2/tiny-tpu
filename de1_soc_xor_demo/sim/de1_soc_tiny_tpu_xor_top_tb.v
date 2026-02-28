// ABOUTME: Self-checking ModelSim testbench for the DE1-SoC tiny-tpu XOR top-level.
// ABOUTME: It verifies one-press execution and latched display behavior across all XOR inputs.
`timescale 1ns/1ps
`default_nettype none

module de1_soc_tiny_tpu_xor_top_tb;
    reg CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;
    wire [6:0] HEX0;
    wire [6:0] HEX1;
    wire [6:0] HEX2;
    wire [6:0] HEX3;
    wire [6:0] HEX4;
    wire [6:0] HEX5;
    wire [9:0] LEDR;

    integer fail_count;

    localparam [6:0] SEG_0 = 7'b1000000;
    localparam [6:0] SEG_1 = 7'b1111001;
    localparam [6:0] SEG_BLANK = 7'b1111111;

    de1_soc_tiny_tpu_xor_top #(
        .DEBOUNCE_LIMIT(4)
    ) dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR)
    );

    initial begin
        CLOCK_50 = 1'b0;
        forever #10 CLOCK_50 = ~CLOCK_50;
    end

    task expect_equal;
        input [6:0] actual;
        input [6:0] expected;
        input [255:0] label;
    begin
        if (actual !== expected) begin
            fail_count = fail_count + 1;
            $display("FAIL %0s expected=%b actual=%b", label, expected, actual);
        end
    end
    endtask

    task wait_for_idle;
        integer guard;
    begin
        guard = 0;
        while (LEDR[0] !== 1'b0 && guard < 2000) begin
            @(posedge CLOCK_50);
            guard = guard + 1;
        end

        if (guard >= 2000) begin
            fail_count = fail_count + 1;
            $display("FAIL wait_for_idle timed out");
        end
    end
    endtask

    task press_start;
    begin
        KEY[0] = 1'b0;
        repeat (8) @(posedge CLOCK_50);
        KEY[0] = 1'b1;
        repeat (8) @(posedge CLOCK_50);
    end
    endtask

    task run_case;
        input [1:0] xy;
        input [6:0] expected_seg;
        input [255:0] label;
    begin
        SW[1:0] = xy;
        press_start;
        wait_for_idle;
        expect_equal(HEX0, expected_seg, label);
    end
    endtask

    initial begin
        fail_count = 0;
        KEY = 4'b1111;
        SW = 10'b0;

        KEY[3] = 1'b0;
        repeat (4) @(posedge CLOCK_50);
        KEY[3] = 1'b1;
        repeat (8) @(posedge CLOCK_50);

        expect_equal(HEX0, SEG_BLANK, "initial HEX0");

        run_case(2'b00, SEG_0, "xor 00");

        SW[1:0] = 2'b01;
        repeat (16) @(posedge CLOCK_50);
        expect_equal(HEX0, SEG_0, "hold before rerun");

        run_case(2'b01, SEG_1, "xor 01");
        run_case(2'b10, SEG_1, "xor 10");
        run_case(2'b11, SEG_0, "xor 11");

        if (fail_count == 0) begin
            $display("REGRESSION PASS");
        end else begin
            $display("REGRESSION FAIL count=%0d", fail_count);
        end

        $finish;
    end
endmodule
