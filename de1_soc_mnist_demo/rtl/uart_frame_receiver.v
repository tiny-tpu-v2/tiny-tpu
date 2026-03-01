// ABOUTME: Reassembles fixed-header UART packets into a payload buffer for the MNIST demo.
// ABOUTME: Waits for A5 5A, captures a fixed byte count, and validates an XOR checksum byte.

`timescale 1ns/1ps
`default_nettype none

module uart_frame_receiver #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD = 115200,
    parameter integer PAYLOAD_BYTES = 98,
    parameter [7:0] HEADER0 = 8'hA5,
    parameter [7:0] HEADER1 = 8'h5A
) (
    input wire clk,
    input wire rst,
    input wire serial_in,
    output reg [(PAYLOAD_BYTES * 8) - 1:0] payload_out,
    output reg frame_valid_out,
    output reg frame_error_out
);
    localparam [1:0] STATE_WAIT_HEADER0 = 2'd0;
    localparam [1:0] STATE_WAIT_HEADER1 = 2'd1;
    localparam [1:0] STATE_PAYLOAD = 2'd2;
    localparam [1:0] STATE_CHECKSUM = 2'd3;

    wire [7:0] rx_data_out;
    wire rx_valid_out;
    wire rx_framing_error;

    reg [1:0] state;
    reg [7:0] checksum;
    reg [7:0] payload_index;

    uart_rx #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .data_out(rx_data_out),
        .valid_out(rx_valid_out),
        .framing_error(rx_framing_error)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            payload_out <= {PAYLOAD_BYTES * 8{1'b0}};
            frame_valid_out <= 1'b0;
            frame_error_out <= 1'b0;
            state <= STATE_WAIT_HEADER0;
            checksum <= 8'd0;
            payload_index <= 8'd0;
        end else begin
            frame_valid_out <= 1'b0;
            frame_error_out <= 1'b0;

            if (rx_framing_error) begin
                state <= STATE_WAIT_HEADER0;
                checksum <= 8'd0;
                payload_index <= 8'd0;
                frame_error_out <= 1'b1;
            end else if (rx_valid_out) begin
                case (state)
                    STATE_WAIT_HEADER0: begin
                        if (rx_data_out == HEADER0) begin
                            state <= STATE_WAIT_HEADER1;
                        end
                    end

                    STATE_WAIT_HEADER1: begin
                        if (rx_data_out == HEADER1) begin
                            state <= STATE_PAYLOAD;
                            checksum <= 8'd0;
                            payload_index <= 8'd0;
                        end else if (rx_data_out == HEADER0) begin
                            state <= STATE_WAIT_HEADER1;
                        end else begin
                            state <= STATE_WAIT_HEADER0;
                        end
                    end

                    STATE_PAYLOAD: begin
                        payload_out[(payload_index * 8) +: 8] <= rx_data_out;
                        checksum <= checksum ^ rx_data_out;

                        if (payload_index == (PAYLOAD_BYTES - 1)) begin
                            state <= STATE_CHECKSUM;
                        end else begin
                            payload_index <= payload_index + 8'd1;
                        end
                    end

                    STATE_CHECKSUM: begin
                        state <= STATE_WAIT_HEADER0;
                        payload_index <= 8'd0;

                        if (checksum == rx_data_out) begin
                            frame_valid_out <= 1'b1;
                        end else begin
                            frame_error_out <= 1'b1;
                        end
                    end

                    default: begin
                        state <= STATE_WAIT_HEADER0;
                    end
                endcase
            end
        end
    end
endmodule
