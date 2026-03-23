// ABOUTME: Connects the UART packet receiver to the MNIST frame buffer for serial image capture.
// ABOUTME: Provides a simple per-pixel Q8.8 read interface for the TPU scheduler.

`timescale 1ns/1ps
`default_nettype none

module mnist_uart_ingress #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD = 115200,
    parameter integer PIXELS = 784,
    parameter integer ADDR_WIDTH = 10
) (
    input wire clk,
    input wire rst,
    input wire serial_in,
    input wire [ADDR_WIDTH - 1:0] pixel_addr_in,
    output wire [15:0] pixel_data_out,
    output wire frame_loaded_out,
    output wire frame_error_out
);
    localparam integer PAYLOAD_BYTES = (PIXELS + 7) / 8;

    wire [(PAYLOAD_BYTES * 8) - 1:0] payload_out;
    wire frame_valid_out;

    uart_frame_receiver #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PAYLOAD_BYTES(PAYLOAD_BYTES)
    ) frame_receiver_inst (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .payload_out(payload_out),
        .frame_valid_out(frame_valid_out),
        .frame_error_out(frame_error_out)
    );

    mnist_frame_buffer #(
        .PIXELS(PIXELS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) frame_buffer_inst (
        .clk(clk),
        .rst(rst),
        .frame_data_in(payload_out),
        .frame_valid_in(frame_valid_out),
        .pixel_addr_in(pixel_addr_in),
        .pixel_data_out(pixel_data_out),
        .frame_loaded_out(frame_loaded_out)
    );
endmodule
