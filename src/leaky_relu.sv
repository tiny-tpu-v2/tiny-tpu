`timescale 1ns/1ps
`default_nettype none

module leaky_relu (
    input logic clk,
    input logic rst,
    input logic lr_valid_in,
    input logic signed [15:0] lr_data_in,
    input logic signed [15:0] lr_temp_leak_factor,
    output logic signed [15:0] lr_data_out,
    output logic lr_valid_out,
    input logic h_store_valid,
    input logic lr_is_backward // if 1 then relu is in backward mode
);

    logic signed [8:0] h_stack;


    logic signed[15:0] mul_out;

    fxp_mul mul_inst(
        .ina(lr_data_in),
        .inb(lr_temp_leak_factor),
        .out(mul_out)
    );


    always @(posedge clk) begin
        if (rst) begin
            lr_data_out <= 16'b0;
            lr_valid_out <= 0;
            h_stack <= 0;
        end 
        else begin
            if (lr_valid_in) begin
                if (lr_is_backward) begin // backward mode 
                    if (h_stack[0] == 1'b1) begin
                        lr_data_out <= mul_out;
                    end else begin // if the bit is 0
                        lr_data_out <= lr_data_in;
                    end
                    // add the bit shifting dequeue (bit shift right??)
                    h_stack <= (h_stack >> 1);
                end 
                else begin // forward mode
                    if (lr_data_in >= 0) begin // if positive 
                        lr_data_out <= lr_data_in; 
                    end else begin  // if negative AND zero
                        lr_data_out <= mul_out;
                    end

                    if (h_store_valid) begin // store MSB of lr_data_in. stores 1 for positive, 0 for negative
                        h_stack <= (h_stack << 1) | lr_data_in[15];
                    end
                end
            end
            lr_valid_out <= lr_valid_in;
        end 
    end

endmodule