// ABOUTME: Verifies the DE1-SoC UART receiver decodes framed bytes at the target baud rate.
// ABOUTME: Drives a serial line with known bytes and checks the recovered byte stream.

`timescale 1ns/1ps
`default_nettype none

module tb_uart_rx;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;

    reg clk;
    reg rst;
    reg serial_in;
    wire [7:0] data_out;
    wire valid_out;
    wire framing_error;

    integer received_count;
    reg [7:0] expected [0:2];

    uart_rx #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD)
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .data_out(data_out),
        .valid_out(valid_out),
        .framing_error(framing_error)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
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

    always @(posedge clk) begin
        if (valid_out) begin
            if (data_out !== expected[received_count]) begin
                $display("FAIL: byte %0d expected %02x got %02x", received_count, expected[received_count], data_out);
                $finish(1);
            end
            received_count = received_count + 1;
        end

        if (framing_error) begin
            $display("FAIL: unexpected framing error");
            $finish(1);
        end
    end

    initial begin
        expected[0] = 8'hA5;
        expected[1] = 8'h5A;
        expected[2] = 8'h3C;
        received_count = 0;
        rst = 1'b1;
        serial_in = 1'b1;

        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        drive_byte(expected[0]);
        drive_byte(expected[1]);
        drive_byte(expected[2]);

        repeat (CLKS_PER_BIT * 2) @(posedge clk);

        if (received_count != 3) begin
            $display("FAIL: expected 3 bytes, got %0d", received_count);
            $finish(1);
        end

        $display("PASS: uart_rx recovered 3 bytes");
        $finish(0);
    end
endmodule
