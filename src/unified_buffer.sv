// TODO: get rid of the mixing of non blocking and blocking assignments

`timescale 1ns/1ps
`default_nettype none

module unified_buffer #(
    parameter int UNIFIED_BUFFER_WIDTH = 128,
    parameter int SYSTOLIC_ARRAY_WIDTH = 2
)(
    input logic clk,
    input logic rst,

    // Write ports from VPU to UB
    input logic [15:0] ub_wr_data_in [SYSTOLIC_ARRAY_WIDTH],
    input logic ub_wr_valid_in [SYSTOLIC_ARRAY_WIDTH],

    // Write ports from host to UB (for loading in parameters)
    input logic [15:0] ub_wr_host_data_in [SYSTOLIC_ARRAY_WIDTH],
    input logic ub_wr_host_valid_in [SYSTOLIC_ARRAY_WIDTH],

    // Read instruction input from instruction memory
    input logic ub_rd_start_in,
    input logic ub_rd_transpose,
    input logic [8:0] ub_ptr_select,
    input logic [15:0] ub_rd_addr_in,
    input logic [15:0] ub_rd_row_size,
    input logic [15:0] ub_rd_col_size,

    // Learning rate input
    input logic [15:0] learning_rate_in,

    // Read ports from UB to left side of systolic array
    // (I had trouble connecting arrays of ports to other modules in the tpu.sv file for some reason so I had to split them like so)
    output logic [15:0] ub_rd_input_data_out_0,
    output logic [15:0] ub_rd_input_data_out_1,
    output logic ub_rd_input_valid_out_0,
    output logic ub_rd_input_valid_out_1,

    // Read ports from UB to top of systolic array
    output logic [15:0] ub_rd_weight_data_out_0,
    output logic [15:0] ub_rd_weight_data_out_1,
    output logic ub_rd_weight_valid_out_0,
    output logic ub_rd_weight_valid_out_1,

    // Read ports from UB to bias modules in VPU
    output logic [15:0] ub_rd_bias_data_out_0,
    output logic [15:0] ub_rd_bias_data_out_1,

    // Read ports from UB to loss modules (Y matrices) in VPU
    output logic [15:0] ub_rd_Y_data_out_0,
    output logic [15:0] ub_rd_Y_data_out_1,

    // Read ports from UB to activation derivative modules (H matrices) in VPU
    output logic [15:0] ub_rd_H_data_out_0,
    output logic [15:0] ub_rd_H_data_out_1,

    // Outputs to send number of columns to systolic array
    output logic [15:0] ub_rd_col_size_out,
    output logic ub_rd_col_size_valid_out
);

    logic [15:0] ub_memory [0:UNIFIED_BUFFER_WIDTH-1];

    logic [15:0] ub_rd_input_data_out [SYSTOLIC_ARRAY_WIDTH];
    logic ub_rd_input_valid_out [SYSTOLIC_ARRAY_WIDTH];
    logic [15:0] ub_rd_weight_data_out [SYSTOLIC_ARRAY_WIDTH];
    logic ub_rd_weight_valid_out [SYSTOLIC_ARRAY_WIDTH];
    logic [15:0] ub_rd_bias_data_out [SYSTOLIC_ARRAY_WIDTH];
    logic [15:0] ub_rd_Y_data_out [SYSTOLIC_ARRAY_WIDTH];
    logic [15:0] ub_rd_H_data_out [SYSTOLIC_ARRAY_WIDTH];

    logic [15:0] wr_ptr;

    // Internal logic for reading inputs from UB to left side of systolic array
    logic [15:0] rd_input_ptr;
    logic [15:0] rd_input_row_size;
    logic [15:0] rd_input_col_size;
    logic [15:0] rd_input_time_counter;
    logic rd_input_transpose;

    // Internal logic for reading weights from UB to left side of systolic array
    logic signed [15:0] rd_weight_ptr;
    logic [15:0] rd_weight_row_size;
    logic [15:0] rd_weight_col_size;
    logic [15:0] rd_weight_time_counter;
    logic rd_weight_transpose;
    logic [15:0] rd_weight_skip_size;

    // Internal logic for bias inputs from UB to bias modules in VPU
    logic [15:0] rd_bias_ptr;
    logic [15:0] rd_bias_row_size;
    logic [15:0] rd_bias_col_size;
    logic [15:0] rd_bias_time_counter;

    // Internal logic for Y inputs from UB to loss modules in VPU
    logic [15:0] rd_Y_ptr;
    logic [15:0] rd_Y_row_size;
    logic [15:0] rd_Y_col_size;
    logic [15:0] rd_Y_time_counter;

    // Internal logic for bias inputs from UB to activation derivative modules in VPU
    logic [15:0] rd_H_ptr;
    logic [15:0] rd_H_row_size;
    logic [15:0] rd_H_col_size;
    logic [15:0] rd_H_time_counter; 

    // Internal logic for bias gradient descent inputs from UB to gradient descent modules
    logic [15:0] rd_grad_bias_ptr;
    logic [15:0] rd_grad_bias_row_size;
    logic [15:0] rd_grad_bias_col_size;
    logic [15:0] rd_grad_bias_time_counter; 

    // Internal logic for weight gradient descent inputs from UB to gradient descent modules
    logic [15:0] rd_grad_weight_ptr;
    logic [15:0] rd_grad_weight_row_size;
    logic [15:0] rd_grad_weight_col_size;
    logic [15:0] rd_grad_weight_time_counter; 

    // Internal logic for gradient descent inputs from UB to gradient descent modules
    logic [15:0] value_old_in [SYSTOLIC_ARRAY_WIDTH];
    logic grad_descent_valid_in [SYSTOLIC_ARRAY_WIDTH];
    logic [15:0] value_updated_out [SYSTOLIC_ARRAY_WIDTH];
    logic grad_descent_done_out [SYSTOLIC_ARRAY_WIDTH];
    
    // Where to write gradients to UB
    logic [15:0] grad_descent_ptr;

    // Whether the gradients are biases or weights (0 for biases, 1 for weights)
    logic grad_bias_or_weight;

    genvar i;
    generate
        for (i=0; i<SYSTOLIC_ARRAY_WIDTH; i++) begin : gradient_descent_gen
            gradient_descent gradient_descent_inst (
                .clk(clk),
                .rst(rst),
                .lr_in(learning_rate_in),
                .grad_in(ub_wr_data_in[i]),
                .value_old_in(value_old_in[i]),
                .grad_descent_valid_in(grad_descent_valid_in[i]),
                .grad_bias_or_weight(grad_bias_or_weight),
                .value_updated_out(value_updated_out[i]),
                .grad_descent_done_out(grad_descent_done_out[i])
            );
        end
    endgenerate

    // (I had trouble connecting arrays of ports to other modules in the tpu.sv file for some reason, so I had to connect them to split up output ports like so)
    assign ub_rd_input_data_out_0 = ub_rd_input_data_out[0];
    assign ub_rd_input_data_out_1 = ub_rd_input_data_out[1];
    assign ub_rd_input_valid_out_0 = ub_rd_input_valid_out[0];
    assign ub_rd_input_valid_out_1 = ub_rd_input_valid_out[1];

    assign ub_rd_weight_data_out_0 = ub_rd_weight_data_out[0];
    assign ub_rd_weight_data_out_1 = ub_rd_weight_data_out[1];
    assign ub_rd_weight_valid_out_0 = ub_rd_weight_valid_out[0];
    assign ub_rd_weight_valid_out_1 = ub_rd_weight_valid_out[1];

    assign ub_rd_bias_data_out_0 = ub_rd_bias_data_out[0];
    assign ub_rd_bias_data_out_1 = ub_rd_bias_data_out[1];

    assign ub_rd_Y_data_out_0 = ub_rd_Y_data_out[0];
    assign ub_rd_Y_data_out_1 = ub_rd_Y_data_out[1];

    assign ub_rd_H_data_out_0 = ub_rd_H_data_out[0];
    assign ub_rd_H_data_out_1 = ub_rd_H_data_out[1];

    always_comb begin
        //READING LOGIC (UB to left side of systolic array)
        if (ub_rd_start_in) begin
            case (ub_ptr_select)
                0: begin
                    rd_input_transpose = ub_rd_transpose;
                    rd_input_ptr = ub_rd_addr_in;

                    if(ub_rd_transpose) begin   // Switch columns and rows!
                        rd_input_row_size = ub_rd_col_size;
                        rd_input_col_size = ub_rd_row_size;
                    end else begin
                        rd_input_row_size = ub_rd_row_size;
                        rd_input_col_size = ub_rd_col_size;
                    end

                    rd_input_time_counter = '0;
                end
                1: begin
                    rd_weight_transpose = ub_rd_transpose;

                    if(ub_rd_transpose) begin   // Switch columns and rows!
                        rd_weight_row_size = ub_rd_col_size;
                        rd_weight_col_size = ub_rd_row_size;
                        rd_weight_ptr = ub_rd_addr_in + ub_rd_col_size - 1;
                        ub_rd_col_size_out = ub_rd_row_size;
                    end else begin
                        rd_weight_row_size = ub_rd_row_size;
                        rd_weight_col_size = ub_rd_col_size;
                        rd_weight_ptr = ub_rd_addr_in + ub_rd_row_size*ub_rd_col_size - ub_rd_col_size;
                        ub_rd_col_size_out = ub_rd_col_size;
                    end

                    rd_weight_skip_size = ub_rd_col_size + 1;
                    rd_weight_time_counter = '0;
                    ub_rd_col_size_valid_out = 1'b1;
                end
                2: begin
                    rd_bias_ptr = ub_rd_addr_in;
                    rd_bias_row_size = ub_rd_row_size;
                    rd_bias_col_size = ub_rd_col_size;
                    rd_bias_time_counter = '0;
                end
                3: begin
                    rd_Y_ptr = ub_rd_addr_in;
                    rd_Y_row_size = ub_rd_row_size;
                    rd_Y_col_size = ub_rd_col_size;
                    rd_Y_time_counter = '0;
                end
                4: begin
                    rd_H_ptr = ub_rd_addr_in;
                    rd_H_row_size = ub_rd_row_size;
                    rd_H_col_size = ub_rd_col_size;
                    rd_H_time_counter = '0;
                end
                5: begin
                    rd_grad_bias_ptr = ub_rd_addr_in;
                    rd_grad_bias_row_size = ub_rd_row_size;
                    rd_grad_bias_col_size = ub_rd_col_size;
                    rd_grad_bias_time_counter = '0;
                    grad_bias_or_weight = 1'b0;
                    grad_descent_ptr = ub_rd_addr_in;
                end
                6: begin
                    rd_grad_weight_ptr = ub_rd_addr_in;
                    rd_grad_weight_row_size = ub_rd_row_size;
                    rd_grad_weight_col_size = ub_rd_col_size;
                    rd_grad_weight_time_counter = '0;
                    grad_bias_or_weight = 1'b1;
                    grad_descent_ptr = ub_rd_addr_in;
                end
            endcase
        end else begin
            ub_rd_col_size_out = 0;
            ub_rd_col_size_valid_out = 1'b0;
        end
    end

    always_comb begin   // Automatically turn on gradient descent modules when bias or weight gradient descent pointers have been set by a read command
        if (
            rd_grad_bias_time_counter < rd_grad_bias_row_size + rd_grad_bias_col_size ||
            rd_grad_weight_time_counter < rd_grad_weight_row_size + rd_grad_weight_col_size
        ) begin
            for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                grad_descent_valid_in[i] = ub_wr_valid_in[i];
            end
        end else begin
            for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                grad_descent_valid_in[i] = 1'b0;
            end
        end
    end 

    always @(posedge clk or posedge rst) begin
        // Display variables in GTKWave
        for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin
            $dumpvars(0, ub_memory[i]);
        end
        for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
            $dumpvars(0, ub_wr_data_in[i]);
            $dumpvars(0, ub_wr_valid_in[i]);
            $dumpvars(0, ub_rd_input_data_out[i]);
            $dumpvars(0, ub_rd_input_valid_out[i]);
            $dumpvars(0, ub_rd_weight_data_out[i]);
            $dumpvars(0, ub_rd_weight_valid_out[i]);
            $dumpvars(0, ub_rd_bias_data_out[i]);
            $dumpvars(0, ub_rd_Y_data_out[i]);
            $dumpvars(0, ub_rd_H_data_out[i]);
            $dumpvars(0, value_old_in[i]);
            $dumpvars(0, grad_descent_valid_in[i]);
            $dumpvars(0, grad_descent_done_out[i]);
            $dumpvars(0, value_updated_out[i]);
        end


        if (rst) begin
            // reset all memory to 0
            for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin
                ub_memory[i] <= '0;
            end

            // set internal registers to 0
            for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                ub_rd_input_data_out[i] <= '0;
                ub_rd_input_valid_out[i] <= '0;
                ub_rd_weight_data_out[i] <= '0;
                ub_rd_weight_valid_out[i] <= '0;
                ub_rd_bias_data_out[i] <= '0;
                ub_rd_Y_data_out[i] <= '0;
                ub_rd_H_data_out[i] <= '0;
                value_old_in[i] <= '0;
                grad_descent_valid_in[i] <= '0;
            end

            wr_ptr <= '0;

            rd_input_ptr <= '0;
            rd_input_row_size <= '0;
            rd_input_col_size <= '0;
            rd_input_time_counter <= '0;
            rd_input_transpose <= '0;

            rd_weight_ptr <= '0;
            rd_weight_row_size <= '0;
            rd_weight_col_size <= '0;
            rd_weight_time_counter <= '0;
            rd_weight_transpose <= '0;

            rd_bias_ptr <= '0;
            rd_bias_row_size <= '0;
            rd_bias_col_size <= '0;
            rd_bias_time_counter <= '0;

            rd_Y_ptr <= '0;
            rd_Y_row_size <= '0;
            rd_Y_col_size <= '0;
            rd_Y_time_counter <= '0;

            rd_H_ptr <= '0;
            rd_H_row_size <= '0;
            rd_H_col_size <= '0;
            rd_H_time_counter <= '0;

            rd_grad_bias_ptr <= '0;
            rd_grad_bias_row_size <= '0;
            rd_grad_bias_col_size <= '0;
            rd_grad_bias_time_counter <= '0;

            rd_grad_weight_ptr <= '0;
            rd_grad_weight_row_size <= '0;
            rd_grad_weight_col_size <= '0;
            rd_grad_weight_time_counter <= '0;
        end else begin
            // WRITING LOGIC
            // matrices are stored in row major format
            // if there are two columns, the first column will be stored at even indices and the second column will be stored at odd indices
            for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin     // FOR LOOP SHOULD DECREMENT TO STORE IN ROW MAJOR ORDER!!! yooooooooo
                if (ub_wr_valid_in[i]) begin
                    ub_memory[wr_ptr] <= ub_wr_data_in[i];
                    wr_ptr = wr_ptr + 1;                                // I should get rid of this (not good to mix non blocking and blocking assignments) but it works for now
                end else if (ub_wr_host_valid_in[i]) begin
                    ub_memory[wr_ptr] <= ub_wr_host_data_in[i];
                    wr_ptr = wr_ptr + 1;
                end
            end

            //WRITING LOGIC (for gradient descent modules to UB)
            if (grad_bias_or_weight) begin
                for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                    if (grad_descent_done_out[i]) begin
                        ub_memory[grad_descent_ptr] <= value_updated_out[i];
                        grad_descent_ptr = grad_descent_ptr + 1;
                    end
                end
            end else begin
                for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                    if (grad_descent_done_out[i]) begin
                        ub_memory[grad_descent_ptr + i] <= value_updated_out[i];
                    end
                end
            end

            // READING LOGIC (for input from UB to left side of systolic array)
            if (rd_input_time_counter + 1 < rd_input_row_size + rd_input_col_size) begin
                if(rd_input_transpose) begin
                    // For transposed matrices (for loop should increment)
                    for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                        if(rd_input_time_counter >= i && rd_input_time_counter < rd_input_row_size + i && i < rd_input_col_size) begin 
                            ub_rd_input_valid_out[i] <= 1'b1;
                            ub_rd_input_data_out[i] <= ub_memory[rd_input_ptr];
                            rd_input_ptr = rd_input_ptr + 1;            // I should get rid of this (not good to mix non blocking and blocking assignments) but it works for now
                        end else begin 
                            ub_rd_input_valid_out[i] <= 1'b0;
                            ub_rd_input_data_out[i] <= '0;
                        end
                    end
                end else begin
                    // For untransposed matrices (for loop should decrement)
                    for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                        if(rd_input_time_counter >= i && rd_input_time_counter < rd_input_row_size + i && i < rd_input_col_size) begin 
                            ub_rd_input_valid_out[i] <= 1'b1;
                            ub_rd_input_data_out[i] <= ub_memory[rd_input_ptr];
                            rd_input_ptr = rd_input_ptr + 1;            // I should get rid of this (not good to mix non blocking and blocking assignments) but it works for now    
                        end else begin 
                            ub_rd_input_valid_out[i] <= 1'b0;
                            ub_rd_input_data_out[i] <= '0;
                        end
                    end
                end
                rd_input_time_counter <= rd_input_time_counter + 1;
            end else begin 
                rd_input_ptr <= 0;
                rd_input_row_size <= 0;
                rd_input_col_size <= 0;
                rd_input_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    ub_rd_input_valid_out[i] <= 1'b0;
                    ub_rd_input_data_out[i] <= '0;
                end
            end

            // READING LOGIC (for weights from UB to top of systolic array)
            if (rd_weight_time_counter + 1 < rd_weight_row_size + rd_weight_col_size) begin
                if(rd_weight_transpose) begin
                    // For transposed matrices (for loop should increment)
                    for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                        if(rd_weight_time_counter >= i && rd_weight_time_counter < rd_weight_row_size + i && i < rd_weight_col_size) begin
                            ub_rd_weight_valid_out[i] <= 1'b1;
                            ub_rd_weight_data_out[i] <= ub_memory[rd_weight_ptr];
                            rd_weight_ptr = rd_weight_ptr + rd_weight_skip_size;
                        end else begin
                            ub_rd_weight_valid_out[i] <= 0;
                            ub_rd_weight_data_out[i] <= '0;
                        end
                    end
                    rd_weight_ptr = rd_weight_ptr - rd_weight_skip_size - 1;
                end else begin
                    // For untransposed matrices (for loop should decrement)
                    for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                        if(rd_weight_time_counter >= i && rd_weight_time_counter < rd_weight_row_size + i && i < rd_weight_col_size) begin
                            ub_rd_weight_valid_out[i] <= 1'b1;
                            ub_rd_weight_data_out[i] <= ub_memory[rd_weight_ptr];
                            rd_weight_ptr = rd_weight_ptr - rd_weight_skip_size;
                        end else begin
                            ub_rd_weight_valid_out[i] <= 0;
                            ub_rd_weight_data_out[i] <= '0;
                        end
                    end
                    rd_weight_ptr = rd_weight_ptr + rd_weight_skip_size + 1;
                end
                rd_weight_time_counter <= rd_weight_time_counter + 1;
            end else begin
                rd_weight_ptr <= 0;
                rd_weight_row_size <= 0;
                rd_weight_col_size <= 0;
                rd_weight_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    ub_rd_weight_valid_out[i] <= 0;
                    ub_rd_weight_data_out[i] <= '0;
                end
            end

            // READING LOGIC (for bias inputs from UB to bias modules in VPU)
            if (rd_bias_time_counter + 1 < rd_bias_row_size + rd_bias_col_size) begin
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    if(rd_bias_time_counter >= i && rd_bias_time_counter < rd_bias_row_size + i && i < rd_bias_col_size) begin
                        ub_rd_bias_data_out[i] <= ub_memory[rd_bias_ptr + i];
                    end else begin
                        ub_rd_bias_data_out[i] <= '0;
                    end
                end
                rd_bias_time_counter <= rd_bias_time_counter + 1;
            end else begin
                rd_bias_ptr <= 0;
                rd_bias_row_size <= 0;
                rd_bias_col_size <= 0;
                rd_bias_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    ub_rd_bias_data_out[i] <= '0;
                end
            end

            // READING LOGIC (for Y inputs from UB to loss modules in VPU)
            if (rd_Y_time_counter + 1 < rd_Y_row_size + rd_Y_col_size) begin
                for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                    if(rd_Y_time_counter >= i && rd_Y_time_counter < rd_Y_row_size + i && i < rd_Y_col_size) begin
                        ub_rd_Y_data_out[i] <= ub_memory[rd_Y_ptr];
                        rd_Y_ptr = rd_Y_ptr + 1;
                    end else begin
                        ub_rd_Y_data_out[i] <= '0;
                    end
                end
                rd_Y_time_counter <= rd_Y_time_counter + 1;
            end else begin
                rd_Y_ptr <= 0;
                rd_Y_row_size <= 0;
                rd_Y_col_size <= 0;
                rd_Y_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    ub_rd_Y_data_out[i] <= '0;
                end
            end

            // READING LOGIC (for H inputs from UB to activation derivative modules in VPU)
            if (rd_H_time_counter + 1 < rd_H_row_size + rd_H_col_size) begin
                for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                    if(rd_H_time_counter >= i && rd_H_time_counter < rd_H_row_size + i && i < rd_H_col_size) begin
                        ub_rd_H_data_out[i] <= ub_memory[rd_H_ptr];
                        rd_H_ptr = rd_H_ptr + 1;
                    end else begin
                        ub_rd_H_data_out[i] <= '0;
                    end
                end
                rd_H_time_counter <= rd_H_time_counter + 1;
            end else begin
                rd_H_ptr <= 0;
                rd_H_row_size <= 0;
                rd_H_col_size <= 0;
                rd_H_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    ub_rd_H_data_out[i] <= '0;
                end
            end

            // READING LOGIC (for bias and weight gradient descent inputs from UB to gradient descent modules)
            if (rd_grad_bias_time_counter + 1 < rd_grad_bias_row_size + rd_grad_bias_col_size) begin
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    if(rd_grad_bias_time_counter >= i && rd_grad_bias_time_counter < rd_grad_bias_row_size + i && i < rd_grad_bias_col_size) begin
                        value_old_in[i] <= ub_memory[rd_grad_bias_ptr + i];
                    end else begin
                        value_old_in[i] <= '0;
                    end
                end
                rd_grad_bias_time_counter <= rd_grad_bias_time_counter + 1;
            end else if (rd_grad_weight_time_counter + 1 < rd_grad_weight_row_size + rd_grad_weight_col_size) begin
                for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
                    if(rd_grad_weight_time_counter >= i && rd_grad_weight_time_counter < rd_grad_weight_row_size + i && i < rd_grad_weight_col_size) begin 
                        value_old_in[i] <= ub_memory[rd_grad_weight_ptr];
                        rd_grad_weight_ptr = rd_grad_weight_ptr + 1;            // I should get rid of this (not good to mix non blocking and blocking assignments) but it works for now    
                    end else begin 
                        value_old_in[i] <= '0;
                    end
                end
                rd_grad_weight_time_counter <= rd_grad_weight_time_counter + 1;
            end else begin
                rd_grad_bias_ptr <= 0;
                rd_grad_bias_row_size <= 0;
                rd_grad_bias_col_size <= 0;
                rd_grad_bias_time_counter <= '0;
                rd_grad_weight_ptr <= 0;
                rd_grad_weight_row_size <= 0;
                rd_grad_weight_col_size <= 0;
                rd_grad_weight_time_counter <= '0;
                for (int i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin
                    value_old_in[i] <= '0;
                end
            end
        end
    end
endmodule