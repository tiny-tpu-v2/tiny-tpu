// ABOUTME: DE1-SoC top-level for JTAG-driven MNIST inference with host-written image memory.
// ABOUTME: Connects the JTAG Avalon master bridge to a local MMIO image buffer and the Tiny-TPU classifier core.
`timescale 1ns/1ps
`default_nettype none

module de1_soc_mnist_jtag_top #(
    parameter W1_INIT_FILE = "model/w1_tiled_q8_8.memh",
    parameter B1_INIT_FILE = "model/b1_q8_8.memh",
    parameter W2_INIT_FILE = "model/w2_tiled_q8_8.memh",
    parameter B2_INIT_FILE = "model/b2_q8_8.memh"
) (
    input wire CLOCK_50,
    input wire [3:0] KEY,
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

    wire [31:0] jtag_master_address;
    wire [31:0] jtag_master_readdata;
    wire jtag_master_read;
    wire jtag_master_write;
    wire [31:0] jtag_master_writedata;
    wire jtag_master_waitrequest;
    wire jtag_master_readdatavalid;
    wire [3:0] jtag_master_byteenable;

    wire [15:0] pixel_data;
    wire [9:0] pixel_addr;
    wire classifier_busy;
    wire classifier_done;
    wire [3:0] classifier_prediction;
    wire start_pulse;
    wire frame_loaded;
    wire done_sticky;
    wire write_while_busy;
    wire [3:0] latched_prediction;
    reg [6:0] hex0_reg;

    mnist_jtag_bridge bridge_inst (
        .clk_clk(CLOCK_50),
        .jtag_master_address(jtag_master_address),
        .jtag_master_readdata(jtag_master_readdata),
        .jtag_master_read(jtag_master_read),
        .jtag_master_write(jtag_master_write),
        .jtag_master_writedata(jtag_master_writedata),
        .jtag_master_waitrequest(jtag_master_waitrequest),
        .jtag_master_readdatavalid(jtag_master_readdatavalid),
        .jtag_master_byteenable(jtag_master_byteenable),
        .reset_reset_n(KEY[3])
    );

    mnist_jtag_mmio #(
        .PIXELS(784),
        .PIXEL_ADDR_WIDTH(10),
        .IMAGE_BASE_ADDR(32'h00000100)
    ) mmio_inst (
        .clk(CLOCK_50),
        .rst(~KEY[3]),
        .avs_address(jtag_master_address),
        .avs_read(jtag_master_read),
        .avs_write(jtag_master_write),
        .avs_writedata(jtag_master_writedata),
        .avs_byteenable(jtag_master_byteenable),
        .avs_readdata(jtag_master_readdata),
        .avs_readdatavalid(jtag_master_readdatavalid),
        .avs_waitrequest(jtag_master_waitrequest),
        .busy_in(classifier_busy),
        .done_in(classifier_done),
        .prediction_in(classifier_prediction),
        .pixel_addr_in(pixel_addr),
        .pixel_data_out(pixel_data),
        .start_pulse_out(start_pulse),
        .frame_loaded_out(frame_loaded),
        .done_sticky_out(done_sticky),
        .write_while_busy_out(write_while_busy),
        .prediction_latched_out(latched_prediction)
    );

    mnist_classifier_core #(
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
        .start(start_pulse),
        .pixel_data_in(pixel_data),
        .pixel_addr_out(pixel_addr),
        .busy(classifier_busy),
        .done(classifier_done),
        .prediction_out(classifier_prediction)
    );

    always @(*) begin
        hex0_reg = SEG_BLANK;
        if (done_sticky) begin
            case (latched_prediction)
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

    assign LEDR[0] = frame_loaded;
    assign LEDR[1] = classifier_busy;
    assign LEDR[2] = done_sticky;
    assign LEDR[3] = write_while_busy;
    assign LEDR[7:4] = latched_prediction;
    assign LEDR[9:8] = 2'b00;
endmodule
