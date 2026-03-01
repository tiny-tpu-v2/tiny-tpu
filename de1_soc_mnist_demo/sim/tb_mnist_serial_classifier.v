// ABOUTME: Verifies the serial ingress and classifier core work together end-to-end on a toy network.
// ABOUTME: Sends a framed packet, starts inference, and checks the final class prediction.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_serial_classifier;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;

    reg clk;
    reg rst;
    reg serial_in;
    reg start_inference;
    wire busy;
    wire done;
    wire [3:0] prediction_out;
    wire frame_loaded_out;
    wire frame_error_out;

    integer i;

    mnist_serial_classifier #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PIXELS(4),
        .PIXEL_ADDR_WIDTH(3),
        .HIDDEN_NEURONS(2),
        .HIDDEN_ADDR_WIDTH(2),
        .OUTPUT_NEURONS(2),
        .OUTPUT_ADDR_WIDTH(2),
        .TILE_WIDTH(2),
        .UNIFIED_BUFFER_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .start_inference(start_inference),
        .busy(busy),
        .done(done),
        .prediction_out(prediction_out),
        .frame_loaded_out(frame_loaded_out),
        .frame_error_out(frame_error_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
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

    initial begin
        rst = 1'b1;
        serial_in = 1'b1;
        start_inference = 1'b0;

        for (i = 0; i < 8; i = i + 1) begin
            dut.classifier_inst.w1_mem[i] = 16'h0000;
        end
        for (i = 0; i < 4; i = i + 1) begin
            dut.classifier_inst.w2_mem[i] = 16'h0000;
        end
        dut.classifier_inst.b1_mem[0] = 16'h0000;
        dut.classifier_inst.b1_mem[1] = 16'h0000;
        dut.classifier_inst.b2_mem[0] = 16'h0000;
        dut.classifier_inst.b2_mem[1] = 16'h0000;

        dut.classifier_inst.w1_mem[0] = 16'h0100;
        dut.classifier_inst.w1_mem[1] = 16'h0000;
        dut.classifier_inst.w1_mem[2] = 16'h0000;
        dut.classifier_inst.w1_mem[3] = 16'h0100;
        dut.classifier_inst.w1_mem[4] = 16'h0100;
        dut.classifier_inst.w1_mem[5] = 16'h0000;
        dut.classifier_inst.w1_mem[6] = 16'h0000;
        dut.classifier_inst.w1_mem[7] = 16'h0100;

        dut.classifier_inst.w2_mem[0] = 16'h0100;
        dut.classifier_inst.w2_mem[1] = 16'h0000;
        dut.classifier_inst.w2_mem[2] = 16'h0000;
        dut.classifier_inst.w2_mem[3] = 16'h0100;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // Header + payload(0x05) + checksum(0x05)
        drive_byte(8'hA5);
        drive_byte(8'h5A);
        drive_byte(8'h05);
        drive_byte(8'h05);

        wait (frame_loaded_out);
        @(posedge clk);
        start_inference = 1'b1;
        @(posedge clk);
        start_inference = 1'b0;

        wait (done);
        #1;

        if (frame_error_out) begin
            $display("FAIL: unexpected frame error");
            $finish(1);
        end
        if (prediction_out !== 4'd0) begin
            $display("FAIL: expected prediction 0 got %0d", prediction_out);
            $finish(1);
        end

        $display("PASS: mnist_serial_classifier accepted a frame and inferred the expected class");
        $finish(0);
    end
endmodule
