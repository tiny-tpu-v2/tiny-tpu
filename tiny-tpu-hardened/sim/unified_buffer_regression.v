// ABOUTME: Self-checking ModelSim regression for unified_buffer dual-lane behavior.
// ABOUTME: It validates write and read sequencing at the module boundary.
`timescale 1ns/1ps
`default_nettype none

module unified_buffer_regression;
    reg clk;
    reg rst;

    reg [15:0] ub_wr_data_in_0;
    reg [15:0] ub_wr_data_in_1;
    reg ub_wr_valid_in_0;
    reg ub_wr_valid_in_1;

    reg [15:0] ub_wr_host_data_in_0;
    reg [15:0] ub_wr_host_data_in_1;
    reg ub_wr_host_valid_in_0;
    reg ub_wr_host_valid_in_1;

    reg ub_rd_start_in;
    reg ub_rd_transpose;
    reg [8:0] ub_ptr_select;
    reg [15:0] ub_rd_addr_in;
    reg [15:0] ub_rd_row_size;
    reg [15:0] ub_rd_col_size;
    reg [15:0] learning_rate_in;

    wire [15:0] ub_rd_input_data_out_0;
    wire [15:0] ub_rd_input_data_out_1;
    wire ub_rd_input_valid_out_0;
    wire ub_rd_input_valid_out_1;
    wire [15:0] ub_rd_weight_data_out_0;
    wire [15:0] ub_rd_weight_data_out_1;
    wire ub_rd_weight_valid_out_0;
    wire ub_rd_weight_valid_out_1;
    wire [15:0] ub_rd_bias_data_out_0;
    wire [15:0] ub_rd_bias_data_out_1;
    wire [15:0] ub_rd_Y_data_out_0;
    wire [15:0] ub_rd_Y_data_out_1;
    wire [15:0] ub_rd_H_data_out_0;
    wire [15:0] ub_rd_H_data_out_1;
    wire [15:0] ub_rd_col_size_out;
    wire ub_rd_col_size_valid_out;

    integer fail_count;

    unified_buffer dut (
        .clk(clk),
        .rst(rst),
        .ub_wr_data_in_0(ub_wr_data_in_0),
        .ub_wr_data_in_1(ub_wr_data_in_1),
        .ub_wr_valid_in_0(ub_wr_valid_in_0),
        .ub_wr_valid_in_1(ub_wr_valid_in_1),
        .ub_wr_host_data_in_0(ub_wr_host_data_in_0),
        .ub_wr_host_data_in_1(ub_wr_host_data_in_1),
        .ub_wr_host_valid_in_0(ub_wr_host_valid_in_0),
        .ub_wr_host_valid_in_1(ub_wr_host_valid_in_1),
        .ub_rd_start_in(ub_rd_start_in),
        .ub_rd_transpose(ub_rd_transpose),
        .ub_ptr_select(ub_ptr_select),
        .ub_rd_addr_in(ub_rd_addr_in),
        .ub_rd_row_size(ub_rd_row_size),
        .ub_rd_col_size(ub_rd_col_size),
        .learning_rate_in(learning_rate_in),
        .ub_rd_input_data_out_0(ub_rd_input_data_out_0),
        .ub_rd_input_data_out_1(ub_rd_input_data_out_1),
        .ub_rd_input_valid_out_0(ub_rd_input_valid_out_0),
        .ub_rd_input_valid_out_1(ub_rd_input_valid_out_1),
        .ub_rd_weight_data_out_0(ub_rd_weight_data_out_0),
        .ub_rd_weight_data_out_1(ub_rd_weight_data_out_1),
        .ub_rd_weight_valid_out_0(ub_rd_weight_valid_out_0),
        .ub_rd_weight_valid_out_1(ub_rd_weight_valid_out_1),
        .ub_rd_bias_data_out_0(ub_rd_bias_data_out_0),
        .ub_rd_bias_data_out_1(ub_rd_bias_data_out_1),
        .ub_rd_Y_data_out_0(ub_rd_Y_data_out_0),
        .ub_rd_Y_data_out_1(ub_rd_Y_data_out_1),
        .ub_rd_H_data_out_0(ub_rd_H_data_out_0),
        .ub_rd_H_data_out_1(ub_rd_H_data_out_1),
        .ub_rd_col_size_out(ub_rd_col_size_out),
        .ub_rd_col_size_valid_out(ub_rd_col_size_valid_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task clear_controls;
    begin
        ub_wr_data_in_0 = 16'h0000;
        ub_wr_data_in_1 = 16'h0000;
        ub_wr_valid_in_0 = 1'b0;
        ub_wr_valid_in_1 = 1'b0;
        ub_wr_host_data_in_0 = 16'h0000;
        ub_wr_host_data_in_1 = 16'h0000;
        ub_wr_host_valid_in_0 = 1'b0;
        ub_wr_host_valid_in_1 = 1'b0;
        ub_rd_start_in = 1'b0;
        ub_rd_transpose = 1'b0;
        ub_ptr_select = 9'd0;
        ub_rd_addr_in = 16'd0;
        ub_rd_row_size = 16'd0;
        ub_rd_col_size = 16'd0;
        learning_rate_in = 16'h0100;
    end
    endtask

    task reset_dut;
    begin
        clear_controls;
        rst = 1'b1;
        @(posedge clk);
        #1;
        rst = 1'b0;
        @(posedge clk);
        #1;
    end
    endtask

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

    task expect_bit;
        input actual;
        input expected;
        input [255:0] label;
    begin
        if (actual !== expected) begin
            fail_count = fail_count + 1;
            $display("FAIL %0s expected=%0d actual=%0d", label, expected, actual);
        end
    end
    endtask

    task preload_word;
        input integer addr;
        input [15:0] value;
    begin
        dut.ub_memory[addr] = value;
    end
    endtask

    task host_dual_write_check;
    begin
        $display("CHECK host_dual_write_check");
        reset_dut;

        ub_wr_host_data_in_1 = 16'h1111;
        ub_wr_host_valid_in_1 = 1'b1;
        ub_wr_host_data_in_0 = 16'h2222;
        ub_wr_host_valid_in_0 = 1'b1;
        @(posedge clk);
        #1;

        clear_controls;
        @(posedge clk);
        #1;

        expect_equal(dut.ub_memory[0], 16'h1111, "host mem[0]");
        expect_equal(dut.ub_memory[1], 16'h2222, "host mem[1]");
        expect_equal(dut.wr_ptr, 16'd2, "host wr_ptr");
    end
    endtask

    task input_read_untransposed_check;
    begin
        $display("CHECK input_read_untransposed_check");
        reset_dut;

        preload_word(16, 16'h0101);
        preload_word(17, 16'h0102);
        preload_word(18, 16'h0103);
        preload_word(19, 16'h0104);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd0;
        ub_rd_addr_in = 16'd16;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        ub_rd_transpose = 1'b0;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b1, "input u0 valid t0");
        expect_equal(ub_rd_input_data_out_0, 16'h0101, "input u0 data t0");
        expect_bit(ub_rd_input_valid_out_1, 1'b0, "input u1 valid t0");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b1, "input u0 valid t1");
        expect_equal(ub_rd_input_data_out_0, 16'h0103, "input u0 data t1");
        expect_bit(ub_rd_input_valid_out_1, 1'b1, "input u1 valid t1");
        expect_equal(ub_rd_input_data_out_1, 16'h0102, "input u1 data t1");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b0, "input u0 valid t2");
        expect_bit(ub_rd_input_valid_out_1, 1'b1, "input u1 valid t2");
        expect_equal(ub_rd_input_data_out_1, 16'h0104, "input u1 data t2");
    end
    endtask

    task input_read_transposed_check;
    begin
        $display("CHECK input_read_transposed_check");
        reset_dut;

        preload_word(20, 16'h0201);
        preload_word(21, 16'h0202);
        preload_word(22, 16'h0203);
        preload_word(23, 16'h0204);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd0;
        ub_rd_addr_in = 16'd20;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        ub_rd_transpose = 1'b1;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b1, "input t0 valid t0");
        expect_equal(ub_rd_input_data_out_0, 16'h0201, "input t0 data t0");
        expect_bit(ub_rd_input_valid_out_1, 1'b0, "input t1 valid t0");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b1, "input t0 valid t1");
        expect_equal(ub_rd_input_data_out_0, 16'h0202, "input t0 data t1");
        expect_bit(ub_rd_input_valid_out_1, 1'b1, "input t1 valid t1");
        expect_equal(ub_rd_input_data_out_1, 16'h0203, "input t1 data t1");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_input_valid_out_0, 1'b0, "input t0 valid t2");
        expect_bit(ub_rd_input_valid_out_1, 1'b1, "input t1 valid t2");
        expect_equal(ub_rd_input_data_out_1, 16'h0204, "input t1 data t2");
    end
    endtask

    task weight_read_untransposed_check;
    begin
        $display("CHECK weight_read_untransposed_check");
        reset_dut;

        preload_word(24, 16'h0301);
        preload_word(25, 16'h0302);
        preload_word(26, 16'h0303);
        preload_word(27, 16'h0304);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd1;
        ub_rd_addr_in = 16'd24;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        ub_rd_transpose = 1'b0;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b1, "weight u0 valid t0");
        expect_equal(ub_rd_weight_data_out_0, 16'h0303, "weight u0 data t0");
        expect_bit(ub_rd_weight_valid_out_1, 1'b0, "weight u1 valid t0");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b1, "weight u0 valid t1");
        expect_equal(ub_rd_weight_data_out_0, 16'h0301, "weight u0 data t1");
        expect_bit(ub_rd_weight_valid_out_1, 1'b1, "weight u1 valid t1");
        expect_equal(ub_rd_weight_data_out_1, 16'h0304, "weight u1 data t1");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b0, "weight u0 valid t2");
        expect_bit(ub_rd_weight_valid_out_1, 1'b1, "weight u1 valid t2");
        expect_equal(ub_rd_weight_data_out_1, 16'h0302, "weight u1 data t2");
    end
    endtask

    task weight_read_transposed_check;
    begin
        $display("CHECK weight_read_transposed_check");
        reset_dut;

        preload_word(28, 16'h0401);
        preload_word(29, 16'h0402);
        preload_word(30, 16'h0403);
        preload_word(31, 16'h0404);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd1;
        ub_rd_addr_in = 16'd28;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        ub_rd_transpose = 1'b1;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b1, "weight t0 valid t0");
        expect_equal(ub_rd_weight_data_out_0, 16'h0402, "weight t0 data t0");
        expect_bit(ub_rd_weight_valid_out_1, 1'b0, "weight t1 valid t0");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b1, "weight t0 valid t1");
        expect_equal(ub_rd_weight_data_out_0, 16'h0401, "weight t0 data t1");
        expect_bit(ub_rd_weight_valid_out_1, 1'b1, "weight t1 valid t1");
        expect_equal(ub_rd_weight_data_out_1, 16'h0404, "weight t1 data t1");

        @(posedge clk);
        #1;
        expect_bit(ub_rd_weight_valid_out_0, 1'b0, "weight t0 valid t2");
        expect_bit(ub_rd_weight_valid_out_1, 1'b1, "weight t1 valid t2");
        expect_equal(ub_rd_weight_data_out_1, 16'h0403, "weight t1 data t2");
    end
    endtask

    task y_read_check;
    begin
        $display("CHECK y_read_check");
        reset_dut;

        preload_word(32, 16'h0501);
        preload_word(33, 16'h0502);
        preload_word(34, 16'h0503);
        preload_word(35, 16'h0504);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd3;
        ub_rd_addr_in = 16'd32;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_equal(ub_rd_Y_data_out_0, 16'h0501, "Y data t0 lane0");
        expect_equal(ub_rd_Y_data_out_1, 16'h0000, "Y data t0 lane1");

        @(posedge clk);
        #1;
        expect_equal(ub_rd_Y_data_out_0, 16'h0503, "Y data t1 lane0");
        expect_equal(ub_rd_Y_data_out_1, 16'h0502, "Y data t1 lane1");

        @(posedge clk);
        #1;
        expect_equal(ub_rd_Y_data_out_0, 16'h0000, "Y data t2 lane0");
        expect_equal(ub_rd_Y_data_out_1, 16'h0504, "Y data t2 lane1");
    end
    endtask

    task h_read_check;
    begin
        $display("CHECK h_read_check");
        reset_dut;

        preload_word(36, 16'h0601);
        preload_word(37, 16'h0602);
        preload_word(38, 16'h0603);
        preload_word(39, 16'h0604);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd4;
        ub_rd_addr_in = 16'd36;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_equal(ub_rd_H_data_out_0, 16'h0601, "H data t0 lane0");
        expect_equal(ub_rd_H_data_out_1, 16'h0000, "H data t0 lane1");

        @(posedge clk);
        #1;
        expect_equal(ub_rd_H_data_out_0, 16'h0603, "H data t1 lane0");
        expect_equal(ub_rd_H_data_out_1, 16'h0602, "H data t1 lane1");

        @(posedge clk);
        #1;
        expect_equal(ub_rd_H_data_out_0, 16'h0000, "H data t2 lane0");
        expect_equal(ub_rd_H_data_out_1, 16'h0604, "H data t2 lane1");
    end
    endtask

    task grad_weight_read_check;
    begin
        $display("CHECK grad_weight_read_check");
        reset_dut;

        preload_word(40, 16'h0701);
        preload_word(41, 16'h0702);
        preload_word(42, 16'h0703);
        preload_word(43, 16'h0704);

        ub_rd_start_in = 1'b1;
        ub_ptr_select = 9'd6;
        ub_rd_addr_in = 16'd40;
        ub_rd_row_size = 16'd2;
        ub_rd_col_size = 16'd2;
        @(posedge clk);
        #1;

        clear_controls;

        @(posedge clk);
        #1;
        expect_equal(dut.value_old_in_0, 16'h0701, "grad weight data t0 lane0");
        expect_equal(dut.value_old_in_1, 16'h0000, "grad weight data t0 lane1");

        @(posedge clk);
        #1;
        expect_equal(dut.value_old_in_0, 16'h0703, "grad weight data t1 lane0");
        expect_equal(dut.value_old_in_1, 16'h0702, "grad weight data t1 lane1");

        @(posedge clk);
        #1;
        expect_equal(dut.value_old_in_0, 16'h0000, "grad weight data t2 lane0");
        expect_equal(dut.value_old_in_1, 16'h0704, "grad weight data t2 lane1");
    end
    endtask

    task grad_weight_writeback_check;
    begin
        $display("CHECK grad_weight_writeback_check");
        reset_dut;

        dut.grad_bias_or_weight = 1'b1;
        dut.grad_descent_ptr = 16'd48;
        force dut.grad_descent_done_out_1 = 1'b1;
        force dut.grad_descent_done_out_0 = 1'b1;
        force dut.value_updated_out_1 = 16'h0801;
        force dut.value_updated_out_0 = 16'h0802;

        @(posedge clk);
        #1;

        release dut.grad_descent_done_out_1;
        release dut.grad_descent_done_out_0;
        release dut.value_updated_out_1;
        release dut.value_updated_out_0;

        clear_controls;
        @(posedge clk);
        #1;

        expect_equal(dut.ub_memory[48], 16'h0801, "grad write mem[48]");
        expect_equal(dut.ub_memory[49], 16'h0802, "grad write mem[49]");
        expect_equal(dut.grad_descent_ptr, 16'd50, "grad write ptr");
    end
    endtask

    initial begin
        fail_count = 0;
        clear_controls;
        rst = 1'b0;

        host_dual_write_check;
        input_read_untransposed_check;
        input_read_transposed_check;
        weight_read_untransposed_check;
        weight_read_transposed_check;
        y_read_check;
        h_read_check;
        grad_weight_read_check;
        grad_weight_writeback_check;

        if (fail_count == 0) begin
            $display("REGRESSION PASS");
        end else begin
            $display("REGRESSION FAIL count=%0d", fail_count);
        end

        $finish;
    end
endmodule
