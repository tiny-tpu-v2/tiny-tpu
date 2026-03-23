// ABOUTME: Verifies the framed UART packet receiver accepts valid packets and rejects bad checksums.
// ABOUTME: Exercises the header search, payload capture, and XOR checksum logic over the serial input.

`timescale 1ns/1ps
`default_nettype none

module tb_uart_frame_receiver;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;
    localparam integer PAYLOAD_BYTES = 4;

    reg clk;
    reg rst;
    reg serial_in;
    wire [(PAYLOAD_BYTES * 8) - 1:0] payload_out;
    wire frame_valid_out;
    wire frame_error_out;
    reg saw_frame_valid;
    reg saw_frame_error;

    uart_frame_receiver #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PAYLOAD_BYTES(PAYLOAD_BYTES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .payload_out(payload_out),
        .frame_valid_out(frame_valid_out),
        .frame_error_out(frame_error_out)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    always @(posedge clk) begin
        if (frame_valid_out) begin
            saw_frame_valid <= 1'b1;
        end
        if (frame_error_out) begin
            saw_frame_error <= 1'b1;
        end
    end

    task drive_byte;
        input [7:0] value;
        integer bit_index;
        begin
            serial_in = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                serial_in = value[bit_index];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            serial_in = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    task drive_good_frame;
        begin
            drive_byte(8'hA5);
            drive_byte(8'h5A);
            drive_byte(8'h11);
            drive_byte(8'h22);
            drive_byte(8'h33);
            drive_byte(8'h44);
            drive_byte(8'h44);
        end
    endtask

    task drive_bad_frame;
        begin
            drive_byte(8'hA5);
            drive_byte(8'h5A);
            drive_byte(8'hAA);
            drive_byte(8'h55);
            drive_byte(8'hF0);
            drive_byte(8'h0F);
            drive_byte(8'h01);
        end
    endtask

    initial begin
        rst = 1'b1;
        serial_in = 1'b1;
        saw_frame_valid = 1'b0;
        saw_frame_error = 1'b0;

        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        drive_good_frame();
        repeat (CLKS_PER_BIT * 2) @(posedge clk);

        if (!saw_frame_valid) begin
            $display("FAIL: expected frame_valid_out after good frame");
            $finish(1);
        end
        if (payload_out[7:0] !== 8'h11 || payload_out[15:8] !== 8'h22 ||
            payload_out[23:16] !== 8'h33 || payload_out[31:24] !== 8'h44) begin
            $display("FAIL: payload mismatch after good frame");
            $finish(1);
        end

        repeat (10) @(posedge clk);
        saw_frame_error = 1'b0;
        drive_bad_frame();
        repeat (CLKS_PER_BIT * 2) @(posedge clk);

        if (!saw_frame_error) begin
            $display("FAIL: expected frame_error_out after bad frame");
            $finish(1);
        end

        $display("PASS: uart_frame_receiver accepted good frame and rejected bad frame");
        $finish(0);
    end
endmodule
