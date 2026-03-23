// ABOUTME: Verifies the JTAG MMIO image/register map and control behavior for the MNIST host interface.
// ABOUTME: Checks write/readback, busy-write protection, start pulse generation, done latching, and clear control.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_jtag_mmio;
    localparam integer PIXELS = 784;
    localparam integer PIXEL_ADDR_WIDTH = 10;
    localparam [31:0] IMAGE_BASE = 32'h00000100;

    reg clk;
    reg rst;
    reg [31:0] avs_address;
    reg avs_read;
    reg avs_write;
    reg [31:0] avs_writedata;
    reg [3:0] avs_byteenable;
    wire [31:0] avs_readdata;
    wire avs_readdatavalid;
    wire avs_waitrequest;
    reg busy_in;
    reg done_in;
    reg [3:0] prediction_in;
    reg [PIXEL_ADDR_WIDTH - 1:0] pixel_addr_in;
    wire [15:0] pixel_data_out;
    wire start_pulse_out;
    wire frame_loaded_out;
    wire done_sticky_out;
    wire write_while_busy_out;
    wire [3:0] prediction_latched_out;

    reg [31:0] read_value;

    mnist_jtag_mmio #(
        .PIXELS(PIXELS),
        .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
        .IMAGE_BASE_ADDR(IMAGE_BASE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .avs_address(avs_address),
        .avs_read(avs_read),
        .avs_write(avs_write),
        .avs_writedata(avs_writedata),
        .avs_byteenable(avs_byteenable),
        .avs_readdata(avs_readdata),
        .avs_readdatavalid(avs_readdatavalid),
        .avs_waitrequest(avs_waitrequest),
        .busy_in(busy_in),
        .done_in(done_in),
        .prediction_in(prediction_in),
        .pixel_addr_in(pixel_addr_in),
        .pixel_data_out(pixel_data_out),
        .start_pulse_out(start_pulse_out),
        .frame_loaded_out(frame_loaded_out),
        .done_sticky_out(done_sticky_out),
        .write_while_busy_out(write_while_busy_out),
        .prediction_latched_out(prediction_latched_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write32;
        input [31:0] addr;
        input [31:0] value;
        begin
            @(posedge clk);
            avs_address <= addr;
            avs_writedata <= value;
            avs_byteenable <= 4'h1;
            avs_write <= 1'b1;
            avs_read <= 1'b0;
            @(posedge clk);
            avs_write <= 1'b0;
            avs_address <= 32'h0;
            avs_writedata <= 32'h0;
        end
    endtask

    task read32;
        input [31:0] addr;
        output [31:0] value;
        begin
            @(posedge clk);
            avs_address <= addr;
            avs_read <= 1'b1;
            avs_write <= 1'b0;
            @(posedge clk);
            avs_read <= 1'b0;
            avs_address <= 32'h0;
            wait (avs_readdatavalid);
            value = avs_readdata;
        end
    endtask

    initial begin
        rst = 1'b1;
        avs_address = 32'h0;
        avs_read = 1'b0;
        avs_write = 1'b0;
        avs_writedata = 32'h0;
        avs_byteenable = 4'h1;
        busy_in = 1'b0;
        done_in = 1'b0;
        prediction_in = 4'd0;
        pixel_addr_in = {PIXEL_ADDR_WIDTH{1'b0}};

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        write32(IMAGE_BASE + (0 * 4), 32'h00000001);
        write32(IMAGE_BASE + (1 * 4), 32'h00000000);
        write32(IMAGE_BASE + (783 * 4), 32'h00000001);
        @(posedge clk);

        if (!frame_loaded_out) begin
            $display("FAIL: frame_loaded_out should assert after image writes");
            $finish(1);
        end

        pixel_addr_in = 10'd0;
        #1;
        if (pixel_data_out !== 16'h0100) begin
            $display("FAIL: pixel 0 expected 16'h0100 got %h", pixel_data_out);
            $finish(1);
        end

        pixel_addr_in = 10'd1;
        #1;
        if (pixel_data_out !== 16'h0000) begin
            $display("FAIL: pixel 1 expected 16'h0000 got %h", pixel_data_out);
            $finish(1);
        end

        read32(IMAGE_BASE + (0 * 4), read_value);
        if ((read_value & 32'h1) !== 32'h1) begin
            $display("FAIL: pixel 0 readback mismatch: %h", read_value);
            $finish(1);
        end

        busy_in = 1'b1;
        write32(IMAGE_BASE + (2 * 4), 32'h00000001);
        busy_in = 1'b0;
        @(posedge clk);
        if (!write_while_busy_out) begin
            $display("FAIL: write_while_busy_out should assert when writing while busy");
            $finish(1);
        end

        write32(32'h00000000, 32'h00000001);
        @(posedge clk);
        if (!start_pulse_out) begin
            $display("FAIL: start pulse did not assert");
            $finish(1);
        end
        @(posedge clk);
        if (start_pulse_out) begin
            $display("FAIL: start pulse should deassert after one cycle");
            $finish(1);
        end

        prediction_in = 4'd5;
        done_in = 1'b1;
        @(posedge clk);
        done_in = 1'b0;
        @(posedge clk);

        if (!done_sticky_out || prediction_latched_out != 4'd5) begin
            $display(
                "FAIL: done/prediction latch mismatch done=%b pred=%d",
                done_sticky_out,
                prediction_latched_out
            );
            $finish(1);
        end

        read32(32'h00000004, read_value);
        if ((read_value & 32'h00000002) == 0) begin
            $display("FAIL: status done bit not set: %h", read_value);
            $finish(1);
        end

        read32(32'h00000008, read_value);
        if ((read_value & 32'hF) != 32'd5) begin
            $display("FAIL: result register mismatch: %h", read_value);
            $finish(1);
        end

        write32(32'h00000000, 32'h00000002);
        @(posedge clk);
        if (frame_loaded_out || done_sticky_out || prediction_latched_out != 4'd0) begin
            $display(
                "FAIL: clear control did not reset state frame=%b done=%b pred=%d",
                frame_loaded_out,
                done_sticky_out,
                prediction_latched_out
            );
            $finish(1);
        end

        read32(IMAGE_BASE + (0 * 4), read_value);
        if ((read_value & 32'h1) != 0) begin
            $display("FAIL: pixel 0 should clear to zero, got %h", read_value);
            $finish(1);
        end

        $display("PASS: mnist_jtag_mmio register and image map behavior is correct");
        $finish(0);
    end
endmodule
