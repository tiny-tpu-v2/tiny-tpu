// ABOUTME: Receives 8N1 UART bytes into the DE1-SoC fabric at a fixed baud rate.
// ABOUTME: Produces a one-cycle valid pulse per byte and flags framing errors on bad stop bits.

`timescale 1ns/1ps
`default_nettype none

module uart_rx #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst,
    input wire serial_in,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg framing_error
);
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;
    localparam integer HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA = 2'd2;
    localparam [1:0] STATE_STOP = 2'd3;

    reg [1:0] state;
    reg [15:0] bit_timer;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            bit_timer <= 16'd0;
            bit_index <= 3'd0;
            shift_reg <= 8'd0;
            data_out <= 8'd0;
            valid_out <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            framing_error <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (!serial_in) begin
                        state <= STATE_START;
                        bit_timer <= HALF_CLKS_PER_BIT;
                    end
                end

                STATE_START: begin
                    if (bit_timer != 16'd0) begin
                        bit_timer <= bit_timer - 16'd1;
                    end else if (!serial_in) begin
                        state <= STATE_DATA;
                        bit_timer <= CLKS_PER_BIT - 1;
                        bit_index <= 3'd0;
                        shift_reg <= 8'd0;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end

                STATE_DATA: begin
                    if (bit_timer != 16'd0) begin
                        bit_timer <= bit_timer - 16'd1;
                    end else begin
                        shift_reg[bit_index] <= serial_in;
                        bit_timer <= CLKS_PER_BIT - 1;

                        if (bit_index == 3'd7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end
                end

                STATE_STOP: begin
                    if (bit_timer != 16'd0) begin
                        bit_timer <= bit_timer - 16'd1;
                    end else begin
                        state <= STATE_IDLE;
                        if (serial_in) begin
                            data_out <= shift_reg;
                            valid_out <= 1'b1;
                        end else begin
                            framing_error <= 1'b1;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
