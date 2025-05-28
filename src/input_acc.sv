module input_acc#(
    parameter int INPUT_ACC_WIDTH = 4
)(
    input logic clk,
    input logic rst,
    
    input logic input_acc_valid_in,
    input logic input_acc_valid_data_in,

    input logic signed [15:0] input_acc_data_nn_in,
    input logic input_acc_valid_data_nn_in,

    input logic signed [15:0] input_acc_data_in,

    output logic input_acc_valid_out,
    output logic signed [15:0] input_acc_data_out
);
    logic [7:0] counter;
    logic [7:0] counter_reg;
    logic signed [15:0] input_acc_mem_reg [0:INPUT_ACC_WIDTH-1];

    always @(posedge clk) begin
        for (int i = 0; i < INPUT_ACC_WIDTH; i++) begin
            $dumpvars(0, input_acc_mem_reg[i]);
        end

        if (rst) begin
            for (int i = 0; i < INPUT_ACC_WIDTH; i++) begin
                input_acc_mem_reg[i] <= 0;
            end
            input_acc_data_out <= 0;
            input_acc_valid_out <= 0;
            counter <= 0;
            counter_reg <= 0;
        end else begin
            input_acc_valid_out <= input_acc_valid_in;
            if (input_acc_valid_data_nn_in) begin
                input_acc_mem_reg[counter] <= input_acc_data_nn_in;
                counter <= counter+1;
                counter_reg <= counter;
            end 
            if (input_acc_valid_in) begin        // Dequeue
                counter <= counter - 1;
                counter_reg <= counter;
                input_acc_data_out <= input_acc_mem_reg[counter_reg+1-counter];
                // if(counter == 0) begin 
                //     // input_acc_valid_out <= 0;
                //     // input_acc_data_out <= 0;
                //     counter <= 0;
                // end
            end 
            if (input_acc_valid_data_in) begin    // Enqueue 
                input_acc_mem_reg[counter] <= input_acc_data_in;
                counter <= counter + 1;
                counter_reg <= counter;
            end 
            
        end
    end
endmodule

