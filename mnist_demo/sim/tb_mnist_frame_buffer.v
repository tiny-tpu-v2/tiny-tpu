// ABOUTME: Verifies the MNIST frame buffer latches a packed bitmask and expands pixels to Q8.8.
// ABOUTME: Checks the packed-bit ordering used by the Arduino and Python tooling before TPU integration.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_frame_buffer;
    reg clk;
    reg rst;
    reg [15:0] frame_data_in;
    reg frame_valid_in;
    reg [4:0] pixel_addr_in;
    wire [15:0] pixel_data_out;
    wire frame_loaded_out;

    mnist_frame_buffer #(
        .PIXELS(16),
        .ADDR_WIDTH(5)
    ) dut (
        .clk(clk),
        .rst(rst),
        .frame_data_in(frame_data_in),
        .frame_valid_in(frame_valid_in),
        .pixel_addr_in(pixel_addr_in),
        .pixel_data_out(pixel_data_out),
        .frame_loaded_out(frame_loaded_out)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

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
        frame_data_in = 16'h0000;
        frame_valid_in = 1'b0;
        pixel_addr_in = 5'd0;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        if (frame_loaded_out !== 1'b0) begin
            $display("FAIL: frame should not be marked loaded after reset release");
            $finish(1);
        end

        frame_data_in = 16'h8009; // bits 0, 3, and 15 set
        frame_valid_in = 1'b1;
        @(posedge clk);
        frame_valid_in = 1'b0;
        @(posedge clk);

        if (frame_loaded_out !== 1'b1) begin
            $display("FAIL: frame should be marked loaded after frame_valid_in");
            $finish(1);
        end

        expect_pixel(5'd0, 16'h0100);
        expect_pixel(5'd1, 16'h0000);
        expect_pixel(5'd3, 16'h0100);
        expect_pixel(5'd15, 16'h0100);
        expect_pixel(5'd14, 16'h0000);

        $display("PASS: mnist_frame_buffer latched and expanded pixels");
        $finish(0);
    end
endmodule
