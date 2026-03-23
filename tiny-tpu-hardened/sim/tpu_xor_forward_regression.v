// ABOUTME: Self-checking ModelSim forward-pass regression for the hardened TPU top.
// ABOUTME: It drives the TPU through the host/UB interface and checks quantized XOR outputs.
`timescale 1ns/1ps
`default_nettype none

module tpu_xor_forward_regression;
    reg clk;
    reg rst;

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
    reg [3:0] vpu_data_pathway;
    reg sys_switch_in;
    reg [15:0] vpu_leak_factor_in;
    reg [15:0] inv_batch_size_times_two_in;

    wire [15:0] sys_data_out_21;
    wire [15:0] sys_data_out_22;
    wire sys_valid_out_21;
    wire sys_valid_out_22;
    wire [15:0] vpu_data_out_1;
    wire [15:0] vpu_data_out_2;
    wire vpu_valid_out_1;
    wire vpu_valid_out_2;
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

    tpu dut (
        .clk(clk),
        .rst(rst),
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
        .vpu_data_pathway(vpu_data_pathway),
        .sys_switch_in(sys_switch_in),
        .vpu_leak_factor_in(vpu_leak_factor_in),
        .inv_batch_size_times_two_in(inv_batch_size_times_two_in),
        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),
        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22),
        .vpu_data_out_1(vpu_data_out_1),
        .vpu_data_out_2(vpu_data_out_2),
        .vpu_valid_out_1(vpu_valid_out_1),
        .vpu_valid_out_2(vpu_valid_out_2),
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

    task clear_host_write;
    begin
        ub_wr_host_data_in_0 = 16'h0000;
        ub_wr_host_data_in_1 = 16'h0000;
        ub_wr_host_valid_in_0 = 1'b0;
        ub_wr_host_valid_in_1 = 1'b0;
    end
    endtask

    task clear_read_cmd;
    begin
        ub_rd_start_in = 1'b0;
        ub_rd_transpose = 1'b0;
        ub_ptr_select = 9'd0;
        ub_rd_addr_in = 16'd0;
        ub_rd_row_size = 16'd0;
        ub_rd_col_size = 16'd0;
    end
    endtask

    task clear_controls;
    begin
        clear_host_write;
        clear_read_cmd;
        learning_rate_in = 16'h00C0;
        vpu_data_pathway = 4'b0000;
        sys_switch_in = 1'b0;
        vpu_leak_factor_in = 16'h0003;
        inv_batch_size_times_two_in = 16'h0080;
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

    task step_host_write;
        input [15:0] data_0;
        input valid_0;
        input [15:0] data_1;
        input valid_1;
    begin
        ub_wr_host_data_in_0 = data_0;
        ub_wr_host_valid_in_0 = valid_0;
        ub_wr_host_data_in_1 = data_1;
        ub_wr_host_valid_in_1 = valid_1;
        @(posedge clk);
        #1;
    end
    endtask

    task step_read_cmd;
        input [8:0] ptr_sel;
        input [15:0] addr;
        input [15:0] rows;
        input [15:0] cols;
        input transpose;
    begin
        ub_rd_start_in = 1'b1;
        ub_ptr_select = ptr_sel;
        ub_rd_addr_in = addr;
        ub_rd_row_size = rows;
        ub_rd_col_size = cols;
        ub_rd_transpose = transpose;
        @(posedge clk);
        #1;
    end
    endtask

    task wait_for_vpu_done;
    begin
        wait (vpu_valid_out_1 || vpu_valid_out_2);
        while (vpu_valid_out_1 || vpu_valid_out_2) begin
            @(posedge clk);
            #1;
        end
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

    initial begin
        fail_count = 0;
        clear_controls;
        rst = 1'b0;

        $display("CHECK tpu_xor_forward_regression");
        reset_dut;

        // Load X and Y to preserve the address map used in test_tpu.py.
        step_host_write(16'h0000, 1'b1, 16'h0000, 1'b0);
        step_host_write(16'h0000, 1'b1, 16'h0000, 1'b1);
        step_host_write(16'h0100, 1'b1, 16'h0100, 1'b1);
        step_host_write(16'h0100, 1'b1, 16'h0000, 1'b1);
        step_host_write(16'h0000, 1'b1, 16'h0100, 1'b1);
        step_host_write(16'h0100, 1'b1, 16'h0000, 1'b0);
        step_host_write(16'h0100, 1'b1, 16'h0000, 1'b0);
        step_host_write(16'h0000, 1'b1, 16'h0000, 1'b0);

        // Load W1, B1, W2, B2 using the trained XOR model.
        step_host_write(16'h00E2, 1'b1, 16'h0000, 1'b0);
        step_host_write(16'hFEEF, 1'b1, 16'hFF1E, 1'b1);
        step_host_write(16'h0040, 1'b1, 16'h0111, 1'b1);
        step_host_write(16'h0126, 1'b1, 16'h0000, 1'b1);
        step_host_write(16'hFFB6, 1'b1, 16'h0137, 1'b1);
        clear_host_write;
        @(posedge clk);
        #1;

        // Stage 1 forward pass.
        step_read_cmd(9'd1, 16'd12, 16'd2, 16'd2, 1'b1);
        clear_read_cmd;
        @(posedge clk);
        #1;

        vpu_data_pathway = 4'b1100;
        step_read_cmd(9'd0, 16'd0, 16'd4, 16'd2, 1'b0);
        clear_read_cmd;
        sys_switch_in = 1'b1;
        @(posedge clk);
        #1;

        sys_switch_in = 1'b0;
        step_read_cmd(9'd2, 16'd16, 16'd4, 16'd2, 1'b0);
        clear_read_cmd;
        @(posedge clk);
        #1;

        wait_for_vpu_done;

        // Stage 2 forward pass.
        step_read_cmd(9'd1, 16'd18, 16'd1, 16'd2, 1'b1);
        clear_read_cmd;
        @(posedge clk);
        #1;

        vpu_data_pathway = 4'b1100;
        step_read_cmd(9'd0, 16'd21, 16'd4, 16'd2, 1'b0);
        clear_read_cmd;
        sys_switch_in = 1'b1;
        @(posedge clk);
        #1;

        sys_switch_in = 1'b0;
        step_read_cmd(9'd2, 16'd20, 16'd4, 16'd1, 1'b0);
        clear_read_cmd;
        @(posedge clk);
        #1;

        wait_for_vpu_done;

        expect_equal(dut.ub_inst.ub_memory[29], 16'hFFFF, "H2[0]");
        expect_equal(dut.ub_inst.ub_memory[30], 16'h00FE, "H2[1]");
        expect_equal(dut.ub_inst.ub_memory[31], 16'h00FE, "H2[2]");
        expect_equal(dut.ub_inst.ub_memory[32], 16'hFFFF, "H2[3]");

        if (fail_count == 0) begin
            $display("REGRESSION PASS");
        end else begin
            $display("REGRESSION FAIL count=%0d", fail_count);
        end

        $finish;
    end
endmodule
