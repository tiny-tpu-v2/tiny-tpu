// ABOUTME: Verifies the combined UART ingress path loads a packed frame into the MNIST frame buffer.
// ABOUTME: Sends a valid serial packet and checks that pixel reads match the transmitted bitmask.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_uart_ingress;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;

    reg clk;
    reg rst;
    reg serial_in;
    reg [4:0] pixel_addr_in;
    wire [15:0] pixel_data_out;
    wire frame_loaded_out;
    wire frame_error_out;

    mnist_uart_ingress #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PIXELS(16),
        .ADDR_WIDTH(5)
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .pixel_addr_in(pixel_addr_in),
        .pixel_data_out(pixel_data_out),
        .frame_loaded_out(frame_loaded_out),
        .frame_error_out(frame_error_out)
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

    task expect_pixel;
        input [4:0] addr;
        input [15:0] expected;
        begin
            pixel_addr_in = addr;
            #1;
            if (pixel_data_out !== expected) begin
                $display("FAIL: pixel %0d expected %04x got %04x", addr, expected, pixel_data_out);
                $finish(1);
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        serial_in = 1'b1;
        pixel_addr_in = 5'd0;

        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        // Header + payload(0x09, 0x80) + checksum(0x89)
        drive_byte(8'hA5);
        drive_byte(8'h5A);
        drive_byte(8'h09);
        drive_byte(8'h80);
        drive_byte(8'h89);

        repeat (CLKS_PER_BIT * 2) @(posedge clk);

        if (!frame_loaded_out) begin
            $display("FAIL: frame should be marked loaded after valid packet");
            $finish(1);
        end
        if (frame_error_out) begin
            $display("FAIL: unexpected frame error after valid packet");
            $finish(1);
        end

        expect_pixel(5'd0, 16'h0100);
        expect_pixel(5'd1, 16'h0000);
        expect_pixel(5'd3, 16'h0100);
        expect_pixel(5'd15, 16'h0100);
        expect_pixel(5'd14, 16'h0000);

        $display("PASS: mnist_uart_ingress loaded a valid serial frame");
        $finish(0);
    end
endmodule
