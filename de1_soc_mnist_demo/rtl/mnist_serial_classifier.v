// ABOUTME: Connects the UART image ingress path to the chunked Tiny-TPU classifier core.
// ABOUTME: Provides a single serial-in, start, done, and prediction interface for higher-level wrappers.

`timescale 1ns/1ps
`default_nettype none

module mnist_serial_classifier #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD = 115200,
    parameter integer PIXELS = 784,
    parameter integer PIXEL_ADDR_WIDTH = 10,
    parameter integer HIDDEN_NEURONS = 64,
    parameter integer HIDDEN_ADDR_WIDTH = 6,
    parameter integer OUTPUT_NEURONS = 10,
    parameter integer OUTPUT_ADDR_WIDTH = 4,
    parameter integer TILE_WIDTH = 2,
    parameter integer UNIFIED_BUFFER_WIDTH = 128,
    parameter integer PRELOAD_MODEL = 0,
    parameter W1_INIT_FILE = "model/w1_tiled_q8_8.memh",
    parameter B1_INIT_FILE = "model/b1_q8_8.memh",
    parameter W2_INIT_FILE = "model/w2_tiled_q8_8.memh",
    parameter B2_INIT_FILE = "model/b2_q8_8.memh"
) (
    input wire clk,
    input wire rst,
    input wire serial_in,
    input wire start_inference,
    output wire busy,
    output wire done,
    output wire [3:0] prediction_out,
    output wire frame_loaded_out,
    output wire frame_error_out
);
    wire [PIXEL_ADDR_WIDTH - 1:0] pixel_addr_out;
    wire [15:0] pixel_data_out;

    mnist_uart_ingress #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PIXELS(PIXELS),
        .ADDR_WIDTH(PIXEL_ADDR_WIDTH)
    ) ingress_inst (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .pixel_addr_in(pixel_addr_out),
        .pixel_data_out(pixel_data_out),
        .frame_loaded_out(frame_loaded_out),
        .frame_error_out(frame_error_out)
    );

    mnist_classifier_core #(
        .PIXELS(PIXELS),
        .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
        .HIDDEN_NEURONS(HIDDEN_NEURONS),
        .HIDDEN_ADDR_WIDTH(HIDDEN_ADDR_WIDTH),
        .OUTPUT_NEURONS(OUTPUT_NEURONS),
        .OUTPUT_ADDR_WIDTH(OUTPUT_ADDR_WIDTH),
        .TILE_WIDTH(TILE_WIDTH),
        .UNIFIED_BUFFER_WIDTH(UNIFIED_BUFFER_WIDTH),
        .PRELOAD_MODEL(PRELOAD_MODEL),
        .W1_INIT_FILE(W1_INIT_FILE),
        .B1_INIT_FILE(B1_INIT_FILE),
        .W2_INIT_FILE(W2_INIT_FILE),
        .B2_INIT_FILE(B2_INIT_FILE)
    ) classifier_inst (
        .clk(clk),
        .rst(rst),
        .start(start_inference),
        .pixel_data_in(pixel_data_out),
        .pixel_addr_out(pixel_addr_out),
        .busy(busy),
        .done(done),
        .prediction_out(prediction_out)
    );
endmodule
