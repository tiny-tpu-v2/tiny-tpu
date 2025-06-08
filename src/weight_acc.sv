module weight_acc#(
    parameter int WEIGHT_ACC_WIDTH = 4
)(
    input logic clk,
    input logic rst,
    
    input logic weight_acc_valid_in,
    input logic weight_acc_valid_data_in,

    input logic signed [15:0] weight_acc_data_in,

    output logic weight_acc_valid_out,
    output logic signed [15:0] weight_acc_data_out
);
    logic [7:0] counter;
    logic [7:0] counter_reg;
    logic signed [15:0] weight_acc_mem_reg [0:WEIGHT_ACC_WIDTH-1];

    always @(posedge clk) begin
        for (int i = 0; i < WEIGHT_ACC_WIDTH; i++) begin
            //$dumpvars(0, weight_acc_mem_reg[i]);
        end

        if (rst) begin
            for (int i = 0; i < WEIGHT_ACC_WIDTH; i++) begin
                weight_acc_mem_reg[i] <= 0;
            end
            weight_acc_data_out <= 0;
            weight_acc_valid_out <= 0;
            counter <= 0;
            counter_reg <= 0;

            // maybe we should remove the else if's and just make separate if statements if we want to enqueue and dequeue at the same time
        end else begin
            weight_acc_valid_out <= weight_acc_valid_in;
            if (weight_acc_valid_data_in) begin    // Enqueue 
                weight_acc_mem_reg[counter] <= weight_acc_data_in;
                counter <= counter + 1;
                counter_reg <= counter;
            end else if (weight_acc_valid_in) begin        // Dequeue
                weight_acc_valid_out <= 1'b1;
                counter <= counter - 1;
                weight_acc_data_out <= weight_acc_mem_reg[counter_reg+1-counter];
            end else if(counter == 0) begin 
                weight_acc_valid_out <= 0;
                weight_acc_data_out <= 0;
                counter <= 0;
            end
        end
    end
endmodule

