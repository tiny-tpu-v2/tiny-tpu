// ABOUTME: DE1-SoC top-level wrapper for the serial-fed Tiny-TPU MNIST demo.
// ABOUTME: Receives a UART frame on GPIO_0[0], debounces KEY[0] as the start button, and latches HEX0.
`timescale 1ns/1ps
`default_nettype none

module de1_soc_mnist_serial_top #(
    parameter integer DEBOUNCE_LIMIT = 50000,
    parameter W1_INIT_FILE = "../../data/model/reference/w1_tiled_q8_8.memh",
    parameter B1_INIT_FILE = "../../data/model/reference/b1_q8_8.memh",
    parameter W2_INIT_FILE = "../../data/model/reference/w2_tiled_q8_8.memh",
    parameter B2_INIT_FILE = "../../data/model/reference/b2_q8_8.memh"
) (
    input wire CLOCK_50,
    input wire [3:0] KEY,
    input wire UART_RX_IN,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [9:0] LEDR
);
    localparam [6:0] SEG_0 = 7'b1000000;
    localparam [6:0] SEG_1 = 7'b1111001;
    localparam [6:0] SEG_2 = 7'b0100100;
    localparam [6:0] SEG_3 = 7'b0110000;
    localparam [6:0] SEG_4 = 7'b0011001;
    localparam [6:0] SEG_5 = 7'b0010010;
    localparam [6:0] SEG_6 = 7'b0000010;
    localparam [6:0] SEG_7 = 7'b1111000;
    localparam [6:0] SEG_8 = 7'b0000000;
    localparam [6:0] SEG_9 = 7'b0010000;
    localparam [6:0] SEG_BLANK = 7'b1111111;

    reg key_sync_0;
    reg key_sync_1;
    reg key_stable;
    reg key_prev;
    reg [19:0] debounce_counter;
    reg [3:0] latched_digit;
    reg digit_valid;

    wire busy;
    wire done;
    wire [3:0] prediction_out;
    wire frame_loaded_out;
    wire frame_error_out;
    wire start_pulse;
    wire start_request;
    reg [6:0] hex0_reg;

    assign start_pulse = key_prev & ~key_stable;
    assign start_request = start_pulse & frame_loaded_out & ~busy;

    mnist_serial_classifier #(
        .PIXELS(784),
        .PIXEL_ADDR_WIDTH(10),
        .HIDDEN_NEURONS(64),
        .HIDDEN_ADDR_WIDTH(6),
        .OUTPUT_NEURONS(10),
        .OUTPUT_ADDR_WIDTH(4),
        .TILE_WIDTH(2),
        .UNIFIED_BUFFER_WIDTH(128),
        .PRELOAD_MODEL(1),
        .W1_INIT_FILE(W1_INIT_FILE),
        .B1_INIT_FILE(B1_INIT_FILE),
        .W2_INIT_FILE(W2_INIT_FILE),
        .B2_INIT_FILE(B2_INIT_FILE)
    ) classifier_inst (
        .clk(CLOCK_50),
        .rst(~KEY[3]),
        .serial_in(UART_RX_IN),
        .start_inference(start_request),
        .busy(busy),
        .done(done),
        .prediction_out(prediction_out),
        .frame_loaded_out(frame_loaded_out),
        .frame_error_out(frame_error_out)
    );

    always @(posedge CLOCK_50) begin
        if (!KEY[3]) begin
            key_sync_0 <= 1'b1;
            key_sync_1 <= 1'b1;
            key_stable <= 1'b1;
            key_prev <= 1'b1;
            debounce_counter <= 20'd0;
            latched_digit <= 4'd0;
            digit_valid <= 1'b0;
        end else begin
            key_sync_0 <= KEY[0];
            key_sync_1 <= key_sync_0;
            key_prev <= key_stable;

            if (key_sync_1 != key_stable) begin
                if (debounce_counter >= DEBOUNCE_LIMIT - 1) begin
                    key_stable <= key_sync_1;
                    debounce_counter <= 20'd0;
                end else begin
                    debounce_counter <= debounce_counter + 20'd1;
                end
            end else begin
                debounce_counter <= 20'd0;
            end

            if (done) begin
                latched_digit <= prediction_out;
                digit_valid <= 1'b1;
            end
        end
    end

    always @(*) begin
        hex0_reg = SEG_BLANK;
        if (digit_valid) begin
            case (latched_digit)
                4'd0: hex0_reg = SEG_0;
                4'd1: hex0_reg = SEG_1;
                4'd2: hex0_reg = SEG_2;
                4'd3: hex0_reg = SEG_3;
                4'd4: hex0_reg = SEG_4;
                4'd5: hex0_reg = SEG_5;
                4'd6: hex0_reg = SEG_6;
                4'd7: hex0_reg = SEG_7;
                4'd8: hex0_reg = SEG_8;
                4'd9: hex0_reg = SEG_9;
                default: hex0_reg = SEG_BLANK;
            endcase
        end
    end

    assign HEX0 = hex0_reg;
    assign HEX1 = SEG_BLANK;
    assign HEX2 = SEG_BLANK;
    assign HEX3 = SEG_BLANK;
    assign HEX4 = SEG_BLANK;
    assign HEX5 = SEG_BLANK;

    assign LEDR[0] = frame_loaded_out;
    assign LEDR[1] = busy;
    assign LEDR[2] = digit_valid;
    assign LEDR[3] = frame_error_out;
    assign LEDR[7:4] = latched_digit;
    assign LEDR[9:8] = 2'b00;
endmodule
