// TODO: get rid of the mixing of non blocking and blocking assignments

`timescale 1ns/1ps
`default_nettype none

module unified_buffer #(
    parameter UNIFIED_BUFFER_WIDTH = 128,
    parameter SYSTOLIC_ARRAY_WIDTH = 2
)(
    input wire clk,
    input wire rst,

    // Write ports from VPU to UB
    input wire [15:0] ub_wr_data_in_0,
    input wire [15:0] ub_wr_data_in_1,
    input wire ub_wr_valid_in_0,
    input wire ub_wr_valid_in_1,

    // Write ports from host to UB (for loading in parameters)
    input wire [15:0] ub_wr_host_data_in_0,
    input wire [15:0] ub_wr_host_data_in_1,
    input wire ub_wr_host_valid_in_0,
    input wire ub_wr_host_valid_in_1,

    // Read instruction input from instruction memory
    input wire ub_rd_start_in,
    input wire ub_rd_transpose,
    input wire [8:0] ub_ptr_select,
    input wire [15:0] ub_rd_addr_in,
    input wire [15:0] ub_rd_row_size,
    input wire [15:0] ub_rd_col_size,

    // Learning rate input
    input wire [15:0] learning_rate_in,

    // Read ports from UB to left side of systolic array
    output reg [15:0] ub_rd_input_data_out_0,
    output reg [15:0] ub_rd_input_data_out_1,
    output reg ub_rd_input_valid_out_0,
    output reg ub_rd_input_valid_out_1,

    // Read ports from UB to top of systolic array
    output reg [15:0] ub_rd_weight_data_out_0,
    output reg [15:0] ub_rd_weight_data_out_1,
    output reg ub_rd_weight_valid_out_0,
    output reg ub_rd_weight_valid_out_1,

    // Read ports from UB to bias modules in VPU
    output reg [15:0] ub_rd_bias_data_out_0,
    output reg [15:0] ub_rd_bias_data_out_1,

    // Read ports from UB to loss modules (Y matrices) in VPU
    output reg [15:0] ub_rd_Y_data_out_0,
    output reg [15:0] ub_rd_Y_data_out_1,

    // Read ports from UB to activation derivative modules (H matrices) in VPU
    output reg [15:0] ub_rd_H_data_out_0,
    output reg [15:0] ub_rd_H_data_out_1,

    // Outputs to send number of columns to systolic array
    output reg [15:0] ub_rd_col_size_out,
    output reg ub_rd_col_size_valid_out
);

    reg [15:0] ub_memory [0:UNIFIED_BUFFER_WIDTH-1];

    reg [15:0] wr_ptr;

    // Internal logic for reading inputs from UB to left side of systolic array
    reg [15:0] rd_input_ptr;
    reg [15:0] rd_input_row_size;
    reg [15:0] rd_input_col_size;
    reg [15:0] rd_input_time_counter;
    reg rd_input_transpose;

    // Internal logic for reading weights from UB to left side of systolic array
    reg signed [15:0] rd_weight_ptr;
    reg [15:0] rd_weight_row_size;
    reg [15:0] rd_weight_col_size;
    reg [15:0] rd_weight_time_counter;
    reg rd_weight_transpose;
    reg [15:0] rd_weight_skip_size;

    // Internal logic for bias inputs from UB to bias modules in VPU
    reg [15:0] rd_bias_ptr;
    reg [15:0] rd_bias_row_size;
    reg [15:0] rd_bias_col_size;
    reg [15:0] rd_bias_time_counter;

    // Internal logic for Y inputs from UB to loss modules in VPU
    reg [15:0] rd_Y_ptr;
    reg [15:0] rd_Y_row_size;
    reg [15:0] rd_Y_col_size;
    reg [15:0] rd_Y_time_counter;

    // Internal logic for bias inputs from UB to activation derivative modules in VPU
    reg [15:0] rd_H_ptr;
    reg [15:0] rd_H_row_size;
    reg [15:0] rd_H_col_size;
    reg [15:0] rd_H_time_counter;

    // Internal logic for bias gradient descent inputs from UB to gradient descent modules
    reg [15:0] rd_grad_bias_ptr;
    reg [15:0] rd_grad_bias_row_size;
    reg [15:0] rd_grad_bias_col_size;
    reg [15:0] rd_grad_bias_time_counter;

    // Internal logic for weight gradient descent inputs from UB to gradient descent modules
    reg [15:0] rd_grad_weight_ptr;
    reg [15:0] rd_grad_weight_row_size;
    reg [15:0] rd_grad_weight_col_size;
    reg [15:0] rd_grad_weight_time_counter;

    // Internal logic for gradient descent inputs from UB to gradient descent modules
    reg [15:0] value_old_in_0;
    reg [15:0] value_old_in_1;
    reg grad_descent_valid_in_0;
    reg grad_descent_valid_in_1;
    wire [15:0] value_updated_out_0;
    wire [15:0] value_updated_out_1;
    wire grad_descent_done_out_0;
    wire grad_descent_done_out_1;

    // Where to write gradients to UB
    reg [15:0] grad_descent_ptr;

    // Whether the gradients are biases or weights (0 for biases, 1 for weights)
    reg grad_bias_or_weight;

    gradient_descent gradient_descent_inst_0 (
        .clk(clk),
        .rst(rst),
        .lr_in(learning_rate_in),
        .grad_in(ub_wr_data_in_0),
        .value_old_in(value_old_in_0),
        .grad_descent_valid_in(grad_descent_valid_in_0),
        .grad_bias_or_weight(grad_bias_or_weight),
        .value_updated_out(value_updated_out_0),
        .grad_descent_done_out(grad_descent_done_out_0)
    );

    gradient_descent gradient_descent_inst_1 (
        .clk(clk),
        .rst(rst),
        .lr_in(learning_rate_in),
        .grad_in(ub_wr_data_in_1),
        .value_old_in(value_old_in_1),
        .grad_descent_valid_in(grad_descent_valid_in_1),
        .grad_bias_or_weight(grad_bias_or_weight),
        .value_updated_out(value_updated_out_1),
        .grad_descent_done_out(grad_descent_done_out_1)
    );

    // Removed combinational block - all register initialization moved to sequential block

    always @(*) begin   // Automatically turn on gradient descent modules when bias or weight gradient descent pointers have been set by a read command
        if (
            rd_grad_bias_time_counter < rd_grad_bias_row_size + rd_grad_bias_col_size ||
            rd_grad_weight_time_counter < rd_grad_weight_row_size + rd_grad_weight_col_size
        ) begin
            grad_descent_valid_in_0 = ub_wr_valid_in_0;
            grad_descent_valid_in_1 = ub_wr_valid_in_1;
        end else begin
            grad_descent_valid_in_0 = 1'b0;
            grad_descent_valid_in_1 = 1'b0;
        end
    end

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset all memory to 0
            for (i = 0; i < UNIFIED_BUFFER_WIDTH; i = i + 1) begin
                ub_memory[i] = 16'b0;
            end

            // set internal registers to 0
            ub_rd_input_data_out_0 <= 16'b0;
            ub_rd_input_data_out_1 <= 16'b0;
            ub_rd_input_valid_out_0 <= 1'b0;
            ub_rd_input_valid_out_1 <= 1'b0;
            ub_rd_weight_data_out_0 <= 16'b0;
            ub_rd_weight_data_out_1 <= 16'b0;
            ub_rd_weight_valid_out_0 <= 1'b0;
            ub_rd_weight_valid_out_1 <= 1'b0;
            ub_rd_bias_data_out_0 <= 16'b0;
            ub_rd_bias_data_out_1 <= 16'b0;
            ub_rd_Y_data_out_0 <= 16'b0;
            ub_rd_Y_data_out_1 <= 16'b0;
            ub_rd_H_data_out_0 <= 16'b0;
            ub_rd_H_data_out_1 <= 16'b0;

            wr_ptr <= 16'b0;

            rd_input_ptr <= 16'b0;
            rd_input_row_size <= 16'b0;
            rd_input_col_size <= 16'b0;
            rd_input_time_counter <= 16'b0;
            rd_input_transpose <= 1'b0;

            rd_weight_ptr <= 16'b0;
            rd_weight_row_size <= 16'b0;
            rd_weight_col_size <= 16'b0;
            rd_weight_time_counter <= 16'b0;
            rd_weight_transpose <= 1'b0;

            rd_bias_ptr <= 16'b0;
            rd_bias_row_size <= 16'b0;
            rd_bias_col_size <= 16'b0;
            rd_bias_time_counter <= 16'b0;

            rd_Y_ptr <= 16'b0;
            rd_Y_row_size <= 16'b0;
            rd_Y_col_size <= 16'b0;
            rd_Y_time_counter <= 16'b0;

            rd_H_ptr <= 16'b0;
            rd_H_row_size <= 16'b0;
            rd_H_col_size <= 16'b0;
            rd_H_time_counter <= 16'b0;

            rd_grad_bias_ptr <= 16'b0;
            rd_grad_bias_row_size <= 16'b0;
            rd_grad_bias_col_size <= 16'b0;
            rd_grad_bias_time_counter <= 16'b0;

            rd_grad_weight_ptr <= 16'b0;
            rd_grad_weight_row_size <= 16'b0;
            rd_grad_weight_col_size <= 16'b0;
            rd_grad_weight_time_counter <= 16'b0;

            ub_rd_col_size_out <= 16'b0;
            ub_rd_col_size_valid_out <= 1'b0;
            grad_bias_or_weight <= 1'b0;
            grad_descent_ptr <= 16'b0;
            rd_weight_skip_size <= 16'b0;
        end else begin
            // Initialize read pointers based on ub_rd_start_in signal
            if (ub_rd_start_in) begin
                case (ub_ptr_select)
                    0: begin
                        rd_input_transpose <= ub_rd_transpose;
                        rd_input_ptr <= ub_rd_addr_in;

                        if(ub_rd_transpose) begin
                            rd_input_row_size <= ub_rd_col_size;
                            rd_input_col_size <= ub_rd_row_size;
                        end else begin
                            rd_input_row_size <= ub_rd_row_size;
                            rd_input_col_size <= ub_rd_col_size;
                        end

                        rd_input_time_counter <= 16'b0;
                    end
                    1: begin
                        rd_weight_transpose <= ub_rd_transpose;

                        if(ub_rd_transpose) begin
                            rd_weight_row_size <= ub_rd_col_size;
                            rd_weight_col_size <= ub_rd_row_size;
                            rd_weight_ptr <= ub_rd_addr_in + ub_rd_col_size - 1;
                            ub_rd_col_size_out <= ub_rd_row_size;
                        end else begin
                            rd_weight_row_size <= ub_rd_row_size;
                            rd_weight_col_size <= ub_rd_col_size;
                            rd_weight_ptr <= ub_rd_addr_in + ub_rd_row_size*ub_rd_col_size - ub_rd_col_size;
                            ub_rd_col_size_out <= ub_rd_col_size;
                        end

                        rd_weight_skip_size <= ub_rd_col_size + 1;
                        rd_weight_time_counter <= 16'b0;
                        ub_rd_col_size_valid_out <= 1'b1;
                    end
                    2: begin
                        rd_bias_ptr <= ub_rd_addr_in;
                        rd_bias_row_size <= ub_rd_row_size;
                        rd_bias_col_size <= ub_rd_col_size;
                        rd_bias_time_counter <= 16'b0;
                    end
                    3: begin
                        rd_Y_ptr <= ub_rd_addr_in;
                        rd_Y_row_size <= ub_rd_row_size;
                        rd_Y_col_size <= ub_rd_col_size;
                        rd_Y_time_counter <= 16'b0;
                    end
                    4: begin
                        rd_H_ptr <= ub_rd_addr_in;
                        rd_H_row_size <= ub_rd_row_size;
                        rd_H_col_size <= ub_rd_col_size;
                        rd_H_time_counter <= 16'b0;
                    end
                    5: begin
                        rd_grad_bias_ptr <= ub_rd_addr_in;
                        rd_grad_bias_row_size <= ub_rd_row_size;
                        rd_grad_bias_col_size <= ub_rd_col_size;
                        rd_grad_bias_time_counter <= 16'b0;
                        grad_bias_or_weight <= 1'b0;
                        grad_descent_ptr <= ub_rd_addr_in;
                    end
                    6: begin
                        rd_grad_weight_ptr <= ub_rd_addr_in;
                        rd_grad_weight_row_size <= ub_rd_row_size;
                        rd_grad_weight_col_size <= ub_rd_col_size;
                        rd_grad_weight_time_counter <= 16'b0;
                        grad_bias_or_weight <= 1'b1;
                        grad_descent_ptr <= ub_rd_addr_in;
                    end
                endcase
            end

            // WRITING LOGIC
            // matrices are stored in row major format
            // if there are two columns, the first column will be stored at even indices and the second column will be stored at odd indices
            if (ub_wr_valid_in_1 || ub_wr_host_valid_in_1) begin
                ub_memory[wr_ptr] <= ub_wr_valid_in_1 ? ub_wr_data_in_1 : ub_wr_host_data_in_1;

                if (ub_wr_valid_in_0 || ub_wr_host_valid_in_0) begin
                    ub_memory[wr_ptr + 16'd1] <= ub_wr_valid_in_0 ? ub_wr_data_in_0 : ub_wr_host_data_in_0;
                    wr_ptr <= wr_ptr + 16'd2;
                end else begin
                    wr_ptr <= wr_ptr + 16'd1;
                end
            end else if (ub_wr_valid_in_0 || ub_wr_host_valid_in_0) begin
                ub_memory[wr_ptr] <= ub_wr_valid_in_0 ? ub_wr_data_in_0 : ub_wr_host_data_in_0;
                wr_ptr <= wr_ptr + 16'd1;
            end

            //WRITING LOGIC (for gradient descent modules to UB)
            if (grad_bias_or_weight) begin
                if (grad_descent_done_out_1) begin
                    ub_memory[grad_descent_ptr] <= value_updated_out_1;

                    if (grad_descent_done_out_0) begin
                        ub_memory[grad_descent_ptr + 16'd1] <= value_updated_out_0;
                        grad_descent_ptr <= grad_descent_ptr + 16'd2;
                    end else begin
                        grad_descent_ptr <= grad_descent_ptr + 16'd1;
                    end
                end else if (grad_descent_done_out_0) begin
                    ub_memory[grad_descent_ptr] <= value_updated_out_0;
                    grad_descent_ptr <= grad_descent_ptr + 16'd1;
                end
            end else begin
                if (grad_descent_done_out_1) begin
                    ub_memory[grad_descent_ptr + 1] <= value_updated_out_1;
                end
                if (grad_descent_done_out_0) begin
                    ub_memory[grad_descent_ptr + 0] <= value_updated_out_0;
                end
            end

            // READING LOGIC (for input from UB to left side of systolic array)
            if (ub_rd_start_in && ub_ptr_select == 9'd0) begin
                ub_rd_input_valid_out_0 <= 1'b0;
                ub_rd_input_data_out_0 <= 16'b0;
                ub_rd_input_valid_out_1 <= 1'b0;
                ub_rd_input_data_out_1 <= 16'b0;
            end else if (rd_input_time_counter + 16'd1 < rd_input_row_size + rd_input_col_size) begin
                if(rd_input_transpose) begin
                    // For transposed matrices (for loop should increment)
                    if(rd_input_time_counter < rd_input_row_size && 16'd0 < rd_input_col_size) begin
                        ub_rd_input_valid_out_0 <= 1'b1;
                        ub_rd_input_data_out_0 <= ub_memory[rd_input_ptr];

                        if(rd_input_time_counter >= 16'd1 && rd_input_time_counter < rd_input_row_size + 16'd1 && 16'd1 < rd_input_col_size) begin
                            ub_rd_input_valid_out_1 <= 1'b1;
                            ub_rd_input_data_out_1 <= ub_memory[rd_input_ptr + 16'd1];
                            rd_input_ptr <= rd_input_ptr + 16'd2;
                        end else begin
                            ub_rd_input_valid_out_1 <= 1'b0;
                            ub_rd_input_data_out_1 <= 16'b0;
                            rd_input_ptr <= rd_input_ptr + 16'd1;
                        end
                    end else begin
                        ub_rd_input_valid_out_0 <= 1'b0;
                        ub_rd_input_data_out_0 <= 16'b0;

                        if(rd_input_time_counter >= 16'd1 && rd_input_time_counter < rd_input_row_size + 16'd1 && 16'd1 < rd_input_col_size) begin
                            ub_rd_input_valid_out_1 <= 1'b1;
                            ub_rd_input_data_out_1 <= ub_memory[rd_input_ptr];
                            rd_input_ptr <= rd_input_ptr + 16'd1;
                        end else begin
                            ub_rd_input_valid_out_1 <= 1'b0;
                            ub_rd_input_data_out_1 <= 16'b0;
                        end
                    end
                end else begin
                    // For untransposed matrices (for loop should decrement)
                    if(rd_input_time_counter >= 16'd1 && rd_input_time_counter < rd_input_row_size + 16'd1 && 16'd1 < rd_input_col_size) begin
                        ub_rd_input_valid_out_1 <= 1'b1;
                        ub_rd_input_data_out_1 <= ub_memory[rd_input_ptr];

                        if(rd_input_time_counter < rd_input_row_size && 16'd0 < rd_input_col_size) begin
                            ub_rd_input_valid_out_0 <= 1'b1;
                            ub_rd_input_data_out_0 <= ub_memory[rd_input_ptr + 16'd1];
                            rd_input_ptr <= rd_input_ptr + 16'd2;
                        end else begin
                            ub_rd_input_valid_out_0 <= 1'b0;
                            ub_rd_input_data_out_0 <= 16'b0;
                            rd_input_ptr <= rd_input_ptr + 16'd1;
                        end
                    end else begin
                        ub_rd_input_valid_out_1 <= 1'b0;
                        ub_rd_input_data_out_1 <= 16'b0;

                        if(rd_input_time_counter < rd_input_row_size && 16'd0 < rd_input_col_size) begin
                            ub_rd_input_valid_out_0 <= 1'b1;
                            ub_rd_input_data_out_0 <= ub_memory[rd_input_ptr];
                            rd_input_ptr <= rd_input_ptr + 16'd1;
                        end else begin
                            ub_rd_input_valid_out_0 <= 1'b0;
                            ub_rd_input_data_out_0 <= 16'b0;
                        end
                    end
                end
                rd_input_time_counter <= rd_input_time_counter + 16'd1;
            end else begin
                rd_input_ptr <= 16'd0;
                rd_input_row_size <= 16'd0;
                rd_input_col_size <= 16'd0;
                rd_input_time_counter <= 16'b0;
                ub_rd_input_valid_out_0 <= 1'b0;
                ub_rd_input_data_out_0 <= 16'b0;
                ub_rd_input_valid_out_1 <= 1'b0;
                ub_rd_input_data_out_1 <= 16'b0;
            end

            // READING LOGIC (for weights from UB to top of systolic array)
            if (ub_rd_start_in && ub_ptr_select == 9'd1) begin
                ub_rd_weight_valid_out_0 <= 1'b0;
                ub_rd_weight_data_out_0 <= 16'b0;
                ub_rd_weight_valid_out_1 <= 1'b0;
                ub_rd_weight_data_out_1 <= 16'b0;
            end else if (rd_weight_time_counter + 16'd1 < rd_weight_row_size + rd_weight_col_size) begin
                if(rd_weight_transpose) begin
                    // For transposed matrices (for loop should increment)
                    if(rd_weight_time_counter < rd_weight_row_size && 16'd0 < rd_weight_col_size) begin
                        ub_rd_weight_valid_out_0 <= 1'b1;
                        ub_rd_weight_data_out_0 <= ub_memory[rd_weight_ptr];

                        if(rd_weight_time_counter >= 16'd1 && rd_weight_time_counter < rd_weight_row_size + 16'd1 && 16'd1 < rd_weight_col_size) begin
                            ub_rd_weight_valid_out_1 <= 1'b1;
                            ub_rd_weight_data_out_1 <= ub_memory[rd_weight_ptr + rd_weight_skip_size];
                            rd_weight_ptr <= rd_weight_ptr + rd_weight_skip_size - 16'd1;
                        end else begin
                            ub_rd_weight_valid_out_1 <= 1'b0;
                            ub_rd_weight_data_out_1 <= 16'b0;
                            rd_weight_ptr <= rd_weight_ptr - 16'd1;
                        end
                    end else begin
                        ub_rd_weight_valid_out_0 <= 1'b0;
                        ub_rd_weight_data_out_0 <= 16'b0;

                        if(rd_weight_time_counter >= 16'd1 && rd_weight_time_counter < rd_weight_row_size + 16'd1 && 16'd1 < rd_weight_col_size) begin
                            ub_rd_weight_valid_out_1 <= 1'b1;
                            ub_rd_weight_data_out_1 <= ub_memory[rd_weight_ptr];
                            rd_weight_ptr <= rd_weight_ptr - 16'd1;
                        end else begin
                            ub_rd_weight_valid_out_1 <= 1'b0;
                            ub_rd_weight_data_out_1 <= 16'b0;
                        end
                    end
                end else begin
                    // For untransposed matrices (for loop should decrement)
                    if(rd_weight_time_counter >= 16'd1 && rd_weight_time_counter < rd_weight_row_size + 16'd1 && 16'd1 < rd_weight_col_size) begin
                        ub_rd_weight_valid_out_1 <= 1'b1;
                        ub_rd_weight_data_out_1 <= ub_memory[rd_weight_ptr];

                        if(rd_weight_time_counter < rd_weight_row_size && 16'd0 < rd_weight_col_size) begin
                            ub_rd_weight_valid_out_0 <= 1'b1;
                            ub_rd_weight_data_out_0 <= ub_memory[rd_weight_ptr - rd_weight_skip_size];
                            rd_weight_ptr <= rd_weight_ptr - rd_weight_skip_size + 16'd1;
                        end else begin
                            ub_rd_weight_valid_out_0 <= 1'b0;
                            ub_rd_weight_data_out_0 <= 16'b0;
                            rd_weight_ptr <= rd_weight_ptr + 16'd1;
                        end
                    end else begin
                        ub_rd_weight_valid_out_1 <= 1'b0;
                        ub_rd_weight_data_out_1 <= 16'b0;

                        if(rd_weight_time_counter < rd_weight_row_size && 16'd0 < rd_weight_col_size) begin
                            ub_rd_weight_valid_out_0 <= 1'b1;
                            ub_rd_weight_data_out_0 <= ub_memory[rd_weight_ptr];
                            rd_weight_ptr <= rd_weight_ptr + 16'd1;
                        end else begin
                            ub_rd_weight_valid_out_0 <= 1'b0;
                            ub_rd_weight_data_out_0 <= 16'b0;
                        end
                    end
                end
                rd_weight_time_counter <= rd_weight_time_counter + 16'd1;
            end else begin
                rd_weight_ptr <= 16'd0;
                rd_weight_row_size <= 16'd0;
                rd_weight_col_size <= 16'd0;
                rd_weight_time_counter <= 16'b0;
                ub_rd_weight_valid_out_0 <= 1'b0;
                ub_rd_weight_data_out_0 <= 16'b0;
                ub_rd_weight_valid_out_1 <= 1'b0;
                ub_rd_weight_data_out_1 <= 16'b0;
            end

            // READING LOGIC (for bias inputs from UB to bias modules in VPU)
            if (ub_rd_start_in && ub_ptr_select == 9'd2) begin
                ub_rd_bias_data_out_0 <= 16'b0;
                ub_rd_bias_data_out_1 <= 16'b0;
            end else if (rd_bias_time_counter + 16'd1 < rd_bias_row_size + rd_bias_col_size) begin
                if(rd_bias_time_counter < rd_bias_row_size && 16'd0 < rd_bias_col_size) begin
                    ub_rd_bias_data_out_0 <= ub_memory[rd_bias_ptr + 0];
                end else begin
                    ub_rd_bias_data_out_0 <= 16'b0;
                end

                if(rd_bias_time_counter >= 16'd1 && rd_bias_time_counter < rd_bias_row_size + 16'd1 && 16'd1 < rd_bias_col_size) begin
                    ub_rd_bias_data_out_1 <= ub_memory[rd_bias_ptr + 1];
                end else begin
                    ub_rd_bias_data_out_1 <= 16'b0;
                end

                rd_bias_time_counter <= rd_bias_time_counter + 16'd1;
            end else begin
                rd_bias_ptr <= 16'd0;
                rd_bias_row_size <= 16'd0;
                rd_bias_col_size <= 16'd0;
                rd_bias_time_counter <= 16'b0;
                ub_rd_bias_data_out_0 <= 16'b0;
                ub_rd_bias_data_out_1 <= 16'b0;
            end

            // READING LOGIC (for Y inputs from UB to loss modules in VPU)
            if (ub_rd_start_in && ub_ptr_select == 9'd3) begin
                ub_rd_Y_data_out_0 <= 16'b0;
                ub_rd_Y_data_out_1 <= 16'b0;
            end else if (rd_Y_time_counter + 16'd1 < rd_Y_row_size + rd_Y_col_size) begin
                if(rd_Y_time_counter >= 16'd1 && rd_Y_time_counter < rd_Y_row_size + 16'd1 && 16'd1 < rd_Y_col_size) begin
                    ub_rd_Y_data_out_1 <= ub_memory[rd_Y_ptr];

                    if(rd_Y_time_counter < rd_Y_row_size && 16'd0 < rd_Y_col_size) begin
                        ub_rd_Y_data_out_0 <= ub_memory[rd_Y_ptr + 16'd1];
                        rd_Y_ptr <= rd_Y_ptr + 16'd2;
                    end else begin
                        ub_rd_Y_data_out_0 <= 16'b0;
                        rd_Y_ptr <= rd_Y_ptr + 16'd1;
                    end
                end else begin
                    ub_rd_Y_data_out_1 <= 16'b0;

                    if(rd_Y_time_counter < rd_Y_row_size && 16'd0 < rd_Y_col_size) begin
                        ub_rd_Y_data_out_0 <= ub_memory[rd_Y_ptr];
                        rd_Y_ptr <= rd_Y_ptr + 16'd1;
                    end else begin
                        ub_rd_Y_data_out_0 <= 16'b0;
                    end
                end

                rd_Y_time_counter <= rd_Y_time_counter + 16'd1;
            end else begin
                rd_Y_ptr <= 16'd0;
                rd_Y_row_size <= 16'd0;
                rd_Y_col_size <= 16'd0;
                rd_Y_time_counter <= 16'b0;
                ub_rd_Y_data_out_0 <= 16'b0;
                ub_rd_Y_data_out_1 <= 16'b0;
            end

            // READING LOGIC (for H inputs from UB to activation derivative modules in VPU)
            if (ub_rd_start_in && ub_ptr_select == 9'd4) begin
                ub_rd_H_data_out_0 <= 16'b0;
                ub_rd_H_data_out_1 <= 16'b0;
            end else if (rd_H_time_counter + 16'd1 < rd_H_row_size + rd_H_col_size) begin
                if(rd_H_time_counter >= 16'd1 && rd_H_time_counter < rd_H_row_size + 16'd1 && 16'd1 < rd_H_col_size) begin
                    ub_rd_H_data_out_1 <= ub_memory[rd_H_ptr];

                    if(rd_H_time_counter < rd_H_row_size && 16'd0 < rd_H_col_size) begin
                        ub_rd_H_data_out_0 <= ub_memory[rd_H_ptr + 16'd1];
                        rd_H_ptr <= rd_H_ptr + 16'd2;
                    end else begin
                        ub_rd_H_data_out_0 <= 16'b0;
                        rd_H_ptr <= rd_H_ptr + 16'd1;
                    end
                end else begin
                    ub_rd_H_data_out_1 <= 16'b0;

                    if(rd_H_time_counter < rd_H_row_size && 16'd0 < rd_H_col_size) begin
                        ub_rd_H_data_out_0 <= ub_memory[rd_H_ptr];
                        rd_H_ptr <= rd_H_ptr + 16'd1;
                    end else begin
                        ub_rd_H_data_out_0 <= 16'b0;
                    end
                end

                rd_H_time_counter <= rd_H_time_counter + 16'd1;
            end else begin
                rd_H_ptr <= 16'd0;
                rd_H_row_size <= 16'd0;
                rd_H_col_size <= 16'd0;
                rd_H_time_counter <= 16'b0;
                ub_rd_H_data_out_0 <= 16'b0;
                ub_rd_H_data_out_1 <= 16'b0;
            end

            // READING LOGIC (for bias and weight gradient descent inputs from UB to gradient descent modules)
            if (ub_rd_start_in && ub_ptr_select == 9'd5) begin
                value_old_in_0 <= 16'b0;
                value_old_in_1 <= 16'b0;
            end else if (rd_grad_bias_time_counter + 16'd1 < rd_grad_bias_row_size + rd_grad_bias_col_size) begin
                if(rd_grad_bias_time_counter < rd_grad_bias_row_size && 16'd0 < rd_grad_bias_col_size) begin
                    value_old_in_0 <= ub_memory[rd_grad_bias_ptr + 0];
                end else begin
                    value_old_in_0 <= 16'b0;
                end

                if(rd_grad_bias_time_counter >= 16'd1 && rd_grad_bias_time_counter < rd_grad_bias_row_size + 16'd1 && 16'd1 < rd_grad_bias_col_size) begin
                    value_old_in_1 <= ub_memory[rd_grad_bias_ptr + 1];
                end else begin
                    value_old_in_1 <= 16'b0;
                end

                rd_grad_bias_time_counter <= rd_grad_bias_time_counter + 16'd1;
            end else if (ub_rd_start_in && ub_ptr_select == 9'd6) begin
                value_old_in_0 <= 16'b0;
                value_old_in_1 <= 16'b0;
            end else if (rd_grad_weight_time_counter + 16'd1 < rd_grad_weight_row_size + rd_grad_weight_col_size) begin
                if(rd_grad_weight_time_counter >= 16'd1 && rd_grad_weight_time_counter < rd_grad_weight_row_size + 16'd1 && 16'd1 < rd_grad_weight_col_size) begin
                    value_old_in_1 <= ub_memory[rd_grad_weight_ptr];

                    if(rd_grad_weight_time_counter < rd_grad_weight_row_size && 16'd0 < rd_grad_weight_col_size) begin
                        value_old_in_0 <= ub_memory[rd_grad_weight_ptr + 16'd1];
                        rd_grad_weight_ptr <= rd_grad_weight_ptr + 16'd2;
                    end else begin
                        value_old_in_0 <= 16'b0;
                        rd_grad_weight_ptr <= rd_grad_weight_ptr + 16'd1;
                    end
                end else begin
                    value_old_in_1 <= 16'b0;

                    if(rd_grad_weight_time_counter < rd_grad_weight_row_size && 16'd0 < rd_grad_weight_col_size) begin
                        value_old_in_0 <= ub_memory[rd_grad_weight_ptr];
                        rd_grad_weight_ptr <= rd_grad_weight_ptr + 16'd1;
                    end else begin
                        value_old_in_0 <= 16'b0;
                    end
                end

                rd_grad_weight_time_counter <= rd_grad_weight_time_counter + 16'd1;
            end else begin
                rd_grad_bias_ptr <= 16'd0;
                rd_grad_bias_row_size <= 16'd0;
                rd_grad_bias_col_size <= 16'd0;
                rd_grad_bias_time_counter <= 16'b0;
                rd_grad_weight_ptr <= 16'd0;
                rd_grad_weight_row_size <= 16'd0;
                rd_grad_weight_col_size <= 16'd0;
                rd_grad_weight_time_counter <= 16'b0;
            end
        end
    end

endmodule
