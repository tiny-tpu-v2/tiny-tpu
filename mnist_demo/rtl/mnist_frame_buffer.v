// ABOUTME: Stores the latest packed MNIST frame and exposes individual pixels as Q8.8 values.
// ABOUTME: Bridges the UART packet payload format to the TPU scheduler's per-pixel read interface.

`timescale 1ns/1ps
`default_nettype none

module mnist_frame_buffer #(
    parameter integer PIXELS = 784,
    parameter integer ADDR_WIDTH = 10
) (
    input wire clk,
    input wire rst,
    input wire [(((PIXELS + 7) / 8) * 8) - 1:0] frame_data_in,
    input wire frame_valid_in,
    input wire [ADDR_WIDTH - 1:0] pixel_addr_in,
    output reg [15:0] pixel_data_out,
    output reg frame_loaded_out
);
    integer bit_index;
    reg [PIXELS - 1:0] frame_bits;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            frame_bits <= {PIXELS{1'b0}};
            frame_loaded_out <= 1'b0;
        end else if (frame_valid_in) begin
            for (bit_index = 0; bit_index < PIXELS; bit_index = bit_index + 1) begin
                frame_bits[bit_index] <= frame_data_in[bit_index];
            end
            frame_loaded_out <= 1'b1;
        end
    end

    always @(*) begin
        pixel_data_out = 16'h0000;
        if (pixel_addr_in < PIXELS && frame_bits[pixel_addr_in]) begin
            pixel_data_out = 16'h0100;
        end
    end
endmodule
