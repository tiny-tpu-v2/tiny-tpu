module accumulator#(
    parameter int ACC_WIDTH = 1
)(
    input logic clk,
    input logic rst,
    
    input logic acc_valid_in,
    input logic acc_valid_data_in,

    input logic signed [15:0] acc_data_nn_in,
    input logic acc_valid_data_nn_in,

    input logic signed [15:0] acc_data_in,

    output logic acc_valid_out,
    output logic signed [15:0] acc_data_out
);

    // logic [15:0] acc_data_out;
    logic [7:0] counter;
    logic signed [15:0] acc_mem_reg [0:ACC_WIDTH-1];

    always @(posedge clk) begin
        for (int i = 0; i < ACC_WIDTH; i++) begin
            $dumpvars(0, acc_mem_reg[i]);
        end

        if (rst) begin
            for (int i = 0; i < ACC_WIDTH; i++) begin
                acc_mem_reg[i] <= 0;
            end
            acc_data_out <= 0;
            acc_valid_out <= 0;
            counter <= 0;
        end
        else if (acc_valid_data_nn_in) begin
            acc_mem_reg[0] <= acc_data_nn_in;
            counter <= counter+1;
        end
        else if (acc_valid_data_in) begin    // Enqueue 
            acc_mem_reg[counter] <= acc_data_in;
            counter <= counter + 1;
        end
        else if (acc_valid_in) begin        // Dequeue
            acc_valid_out <= 1'b1;
            counter <= counter - 1;
            acc_data_out <= acc_mem_reg[ACC_WIDTH-counter];
        end else if(counter == 0) begin 
            acc_valid_out <= 0;
            acc_data_out <= 0;
            counter <= 0;
        end
    end
endmodule

