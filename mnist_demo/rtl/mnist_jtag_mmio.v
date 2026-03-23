// ABOUTME: Exposes a JTAG-accessible Avalon-MM register map and image buffer for MNIST inference control.
// ABOUTME: Presents one-bit image pixels to the classifier core as Q8.8 values and latches inference results.

`timescale 1ns/1ps
`default_nettype none

module mnist_jtag_mmio #(
    parameter integer PIXELS = 784,
    parameter integer PIXEL_ADDR_WIDTH = 10,
    parameter [31:0] IMAGE_BASE_ADDR = 32'h00000100
) (
    input wire clk,
    input wire rst,
    input wire [31:0] avs_address,
    input wire avs_read,
    input wire avs_write,
    input wire [31:0] avs_writedata,
    input wire [3:0] avs_byteenable,
    output reg [31:0] avs_readdata,
    output reg avs_readdatavalid,
    output wire avs_waitrequest,
    input wire busy_in,
    input wire done_in,
    input wire [3:0] prediction_in,
    input wire [PIXEL_ADDR_WIDTH - 1:0] pixel_addr_in,
    output reg [15:0] pixel_data_out,
    output reg start_pulse_out,
    output reg frame_loaded_out,
    output reg done_sticky_out,
    output reg write_while_busy_out,
    output reg [3:0] prediction_latched_out
);
    localparam [31:0] CTRL_WORD_ADDR = 32'h00000000;
    localparam [31:0] STATUS_WORD_ADDR = 32'h00000001;
    localparam [31:0] RESULT_WORD_ADDR = 32'h00000002;
    localparam [31:0] VERSION_WORD_ADDR = 32'h00000003;
    localparam [31:0] IMAGE_BASE_WORD_ADDR = IMAGE_BASE_ADDR[31:2];
    localparam [31:0] IMAGE_LAST_WORD_ADDR = IMAGE_BASE_WORD_ADDR + PIXELS - 1;
    localparam [31:0] VERSION_VALUE = 32'h4D4E4953;  // "MNIS"

    reg [PIXELS - 1:0] frame_bits;
    reg [31:0] read_data_next;
    wire [31:0] word_addr;
    integer clear_index;
    integer pixel_index;

    function pixel_bit_from_write;
        input [31:0] data;
        input [3:0] byteenable;
        begin
            pixel_bit_from_write = 1'b0;
            if (byteenable[0]) begin
                pixel_bit_from_write = data[0];
            end else if (byteenable[1]) begin
                pixel_bit_from_write = data[8];
            end else if (byteenable[2]) begin
                pixel_bit_from_write = data[16];
            end else if (byteenable[3]) begin
                pixel_bit_from_write = data[24];
            end
        end
    endfunction

    assign word_addr = avs_address[31:2];
    assign avs_waitrequest = 1'b0;

    always @(*) begin
        read_data_next = 32'h00000000;

        if (word_addr == CTRL_WORD_ADDR) begin
            read_data_next[0] = 1'b0;
            read_data_next[1] = 1'b0;
            read_data_next[2] = 1'b0;
            read_data_next[3] = 1'b0;
        end else if (word_addr == STATUS_WORD_ADDR) begin
            read_data_next[0] = busy_in;
            read_data_next[1] = done_sticky_out;
            read_data_next[2] = frame_loaded_out;
            read_data_next[3] = write_while_busy_out;
        end else if (word_addr == RESULT_WORD_ADDR) begin
            read_data_next[3:0] = prediction_latched_out;
        end else if (word_addr == VERSION_WORD_ADDR) begin
            read_data_next = VERSION_VALUE;
        end else if (word_addr >= IMAGE_BASE_WORD_ADDR && word_addr <= IMAGE_LAST_WORD_ADDR) begin
            read_data_next[0] = frame_bits[word_addr - IMAGE_BASE_WORD_ADDR];
        end
    end

    always @(*) begin
        pixel_data_out = 16'h0000;
        if (pixel_addr_in < PIXELS && frame_bits[pixel_addr_in]) begin
            pixel_data_out = 16'h0100;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            frame_bits <= {PIXELS{1'b0}};
            start_pulse_out <= 1'b0;
            frame_loaded_out <= 1'b0;
            done_sticky_out <= 1'b0;
            write_while_busy_out <= 1'b0;
            prediction_latched_out <= 4'd0;
            avs_readdata <= 32'h00000000;
            avs_readdatavalid <= 1'b0;
        end else begin
            start_pulse_out <= 1'b0;
            avs_readdatavalid <= avs_read;
            if (avs_read) begin
                avs_readdata <= read_data_next;
            end

            if (done_in) begin
                done_sticky_out <= 1'b1;
                prediction_latched_out <= prediction_in;
            end

            if (avs_write) begin
                if (word_addr == CTRL_WORD_ADDR) begin
                    if (avs_byteenable[0] && avs_writedata[0] && frame_loaded_out && !busy_in) begin
                        start_pulse_out <= 1'b1;
                        done_sticky_out <= 1'b0;
                    end
                    if (avs_byteenable[0] && avs_writedata[1]) begin
                        for (clear_index = 0; clear_index < PIXELS; clear_index = clear_index + 1) begin
                            frame_bits[clear_index] <= 1'b0;
                        end
                        frame_loaded_out <= 1'b0;
                        done_sticky_out <= 1'b0;
                        prediction_latched_out <= 4'd0;
                        write_while_busy_out <= 1'b0;
                    end
                    if (avs_byteenable[0] && avs_writedata[2]) begin
                        done_sticky_out <= 1'b0;
                    end
                    if (avs_byteenable[0] && avs_writedata[3]) begin
                        write_while_busy_out <= 1'b0;
                    end
                end else if (word_addr >= IMAGE_BASE_WORD_ADDR && word_addr <= IMAGE_LAST_WORD_ADDR) begin
                    pixel_index = word_addr - IMAGE_BASE_WORD_ADDR;
                    if (busy_in) begin
                        write_while_busy_out <= 1'b1;
                    end else begin
                        frame_bits[pixel_index] <= pixel_bit_from_write(avs_writedata, avs_byteenable);
                        frame_loaded_out <= 1'b1;
                        done_sticky_out <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
