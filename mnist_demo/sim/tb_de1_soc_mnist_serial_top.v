// ABOUTME: Verifies the DE1-SoC MNIST top wrapper accepts a UART frame, debounces KEY[0], and latches HEX0.
// ABOUTME: Uses the tracked model and sample frame to check the board-facing display and status outputs.

`timescale 1ns/1ps
`default_nettype none

module tb_de1_soc_mnist_serial_top;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;
    localparam integer PAYLOAD_BYTES = 98;
    localparam [6:0] SEG_7 = 7'b1111000;

    reg CLOCK_50;
    reg [3:0] KEY;
    reg UART_RX_IN;
    wire [6:0] HEX0;
    wire [6:0] HEX1;
    wire [6:0] HEX2;
    wire [6:0] HEX3;
    wire [6:0] HEX4;
    wire [6:0] HEX5;
    wire [9:0] LEDR;

    reg [7:0] sample_bytes [0:PAYLOAD_BYTES - 1];
    reg [7:0] checksum;
    integer i;
    integer wait_cycles;

    de1_soc_mnist_serial_top #(
        .DEBOUNCE_LIMIT(4),
        .W1_INIT_FILE("../../model/w1_tiled_q8_8.memh"),
        .B1_INIT_FILE("../../model/b1_q8_8.memh"),
        .W2_INIT_FILE("../../model/w2_tiled_q8_8.memh"),
        .B2_INIT_FILE("../../model/b2_q8_8.memh")
    ) dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .UART_RX_IN(UART_RX_IN),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR)
    );

    initial begin
        CLOCK_50 = 1'b0;
        forever #5 CLOCK_50 = ~CLOCK_50;
    end

    task drive_byte;
        input [7:0] value;
        integer bit_index;
        begin
            UART_RX_IN = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge CLOCK_50);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                UART_RX_IN = value[bit_index];
                repeat (CLKS_PER_BIT) @(posedge CLOCK_50);
            end
            UART_RX_IN = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge CLOCK_50);
        end
    endtask

    initial begin
        KEY = 4'b1111;
        UART_RX_IN = 1'b1;
        checksum = 8'h00;

        $readmemh("../../model/sample_image_0.memh", sample_bytes);
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            checksum = checksum ^ sample_bytes[i];
        end

        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b0;
        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b1;
        repeat (5) @(posedge CLOCK_50);

        drive_byte(8'hA5);
        drive_byte(8'h5A);
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            drive_byte(sample_bytes[i]);
        end
        drive_byte(checksum);

        wait (LEDR[0]);

        repeat (2) @(posedge CLOCK_50);
        KEY[0] = 1'b0;
        repeat (8) @(posedge CLOCK_50);
        KEY[0] = 1'b1;

        wait_cycles = 0;
        begin : wait_for_display
            while (wait_cycles < 2000000) begin
                @(posedge CLOCK_50);
                #1;
                wait_cycles = wait_cycles + 1;
                if (LEDR[2]) begin
                    disable wait_for_display;
                end
            end
        end

        if (!LEDR[2]) begin
            $display("FAIL: timed out waiting for a latched prediction");
            $finish(1);
        end
        if (LEDR[3]) begin
            $display("FAIL: unexpected frame error");
            $finish(1);
        end
        if (HEX0 !== SEG_7) begin
            $display("FAIL: expected HEX0 to show 7 got %07b", HEX0);
            $finish(1);
        end
        if (HEX1 !== 7'b1111111 || HEX2 !== 7'b1111111 || HEX3 !== 7'b1111111 ||
            HEX4 !== 7'b1111111 || HEX5 !== 7'b1111111) begin
            $display("FAIL: expected HEX1-HEX5 to stay blank");
            $finish(1);
        end

        $display("PASS: de1_soc_mnist_serial_top latched the expected digit on HEX0");
        $finish(0);
    end
endmodule
