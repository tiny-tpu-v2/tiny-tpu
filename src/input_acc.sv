module input_acc #(
    parameter int INPUT_ACC_WIDTH = 4 
)(
    input  logic clk,
    input  logic rst,

    input  logic input_acc_valid_in,      
    input  logic input_acc_valid_data_in,     
    input  logic signed [15:0] input_acc_data_in,

    input  logic input_acc_valid_data_nn_in,  
    input  logic signed [15:0] input_acc_data_nn_in,

    output logic input_acc_valid_out,  
    output logic signed [15:0] input_acc_data_out
);

    localparam int PTR_W = $clog2(INPUT_ACC_WIDTH);

    logic [PTR_W-1:0] wr_ptr, rd_ptr; 
    logic [PTR_W:0] count;                  

    // fifo memory 
    logic signed [15:0] input_acc_mem_reg [INPUT_ACC_WIDTH];

    logic wr_en;
    logic rd_en;
    logic signed [15:0] wr_data;

    always_comb begin
        wr_en   = input_acc_valid_data_nn_in | input_acc_valid_data_in;
        wr_data = input_acc_valid_data_nn_in ? input_acc_data_nn_in : input_acc_data_in;
    end

    always_ff @(posedge clk) begin
        // logging each element of the memory in the waveform
        // for (int i = 0; i < INPUT_ACC_WIDTH; i++) begin
        //     $dumpvars(0, input_acc_mem_reg[i]);
        // end

        if (rst) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            input_acc_data_out <= '0;
            input_acc_valid_out<= 1'b0;
        end
        else begin

            // enqueue 
            if (wr_en && (count < INPUT_ACC_WIDTH)) begin
                input_acc_mem_reg[wr_ptr] <= wr_data;
                wr_ptr  <= (wr_ptr == INPUT_ACC_WIDTH-1) ? 0 : wr_ptr + 1'b1;
            end

            // dequeue
            rd_en = input_acc_valid_in && (count != 0);
            input_acc_valid_out <= rd_en;             

            if (rd_en) begin
                input_acc_data_out <= input_acc_mem_reg[rd_ptr];
                rd_ptr <= (rd_ptr == INPUT_ACC_WIDTH-1) ? 0 : rd_ptr + 1'b1;
            end

            // tracking count based on wr_en and rd_en (enqueue and dequeue)
            case ({wr_en && (count < INPUT_ACC_WIDTH), rd_en})
                2'b10 : count <= count + 1;   // write only
                2'b01 : count <= count - 1;   // read  only
                2'b11 : count <= count;       // both: count unchanged;
            endcase
        end
    end
endmodule
