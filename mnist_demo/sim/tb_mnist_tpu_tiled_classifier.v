// ABOUTME: Verifies the tiled TPU classifier runs a complete two-layer inference on a small toy network.
// ABOUTME: Uses the real TPU datapath and checks the scheduler's hidden activations and final prediction.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_tpu_tiled_classifier;
    reg clk;
    reg rst;
    reg start;
    wire [2:0] pixel_addr_out;
    reg [15:0] pixel_data_in;
    wire busy;
    wire done;
    wire [3:0] prediction_out;

    reg [3:0] frame_bits;

    integer i;

    mnist_classifier_core #(
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
        .start(start),
        .pixel_data_in(pixel_data_in),
        .pixel_addr_out(pixel_addr_out),
        .busy(busy),
        .done(done),
        .prediction_out(prediction_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(*) begin
        if (pixel_addr_out < 4 && frame_bits[pixel_addr_out]) begin
            pixel_data_in = 16'h0100;
        end else begin
            pixel_data_in = 16'h0000;
        end
    end

    initial begin
        rst = 1'b1;
        start = 1'b0;
        frame_bits = 4'b0011; // pixels 0 and 1 set

        for (i = 0; i < 8; i = i + 1) begin
            dut.model_runtime.w1_mem[i] = 16'h0000;
        end
        for (i = 0; i < 2; i = i + 1) begin
            dut.b1_mem[i] = 16'h0000;
            dut.model_runtime.w2_mem[i] = 16'h0000;
        end
        for (i = 2; i < 4; i = i + 1) begin
            dut.model_runtime.w2_mem[i] = 16'h0000;
        end
        dut.b2_mem[0] = 16'h0000;
        dut.b2_mem[1] = 16'h0000;

        // W1, tile width 2, row-major by input:
        // neuron0 = [1, 4, 0, 0], neuron1 = [2, 8, 0, 0]
        dut.model_runtime.w1_mem[0] = 16'h0100;
        dut.model_runtime.w1_mem[1] = 16'h0200;
        dut.model_runtime.w1_mem[2] = 16'h0400;
        dut.model_runtime.w1_mem[3] = 16'h0800;
        dut.model_runtime.w1_mem[4] = 16'h0000;
        dut.model_runtime.w1_mem[5] = 16'h0000;
        dut.model_runtime.w1_mem[6] = 16'h0000;
        dut.model_runtime.w1_mem[7] = 16'h0000;

        // W2, tile width 2, row-major by hidden input:
        // out0 = [1, 0], out1 = [0, 1]
        dut.model_runtime.w2_mem[0] = 16'h0100;
        dut.model_runtime.w2_mem[1] = 16'h0000;
        dut.model_runtime.w2_mem[2] = 16'h0000;
        dut.model_runtime.w2_mem[3] = 16'h0100;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (done);
        #1;

        if (prediction_out !== 4'd1) begin
            $display("FAIL: expected prediction 1 got %0d", prediction_out);
            $finish(1);
        end
        if (dut.hidden_buffer[0] !== 16'h0500) begin
            $display("FAIL: expected hidden[0] = 0500 got %04x", dut.hidden_buffer[0]);
            $finish(1);
        end
        if (dut.hidden_buffer[1] !== 16'h0A00) begin
            $display("FAIL: expected hidden[1] = 0A00 got %04x", dut.hidden_buffer[1]);
            $finish(1);
        end
        if (dut.logits_buffer[0] !== 16'h0500) begin
            $display("FAIL: expected logits[0] = 0500 got %04x", dut.logits_buffer[0]);
            $finish(1);
        end
        if (dut.logits_buffer[1] !== 16'h0A00) begin
            $display("FAIL: expected logits[1] = 0A00 got %04x", dut.logits_buffer[1]);
            $finish(1);
        end

        $display("PASS: mnist_tpu_tiled_classifier produced the expected toy inference");
        $finish(0);
    end
endmodule
