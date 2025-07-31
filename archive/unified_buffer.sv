`timescale 1ns/1ps
`default_nettype none

module unified_buffer # (
    parameter int UNIFIED_BUFFER_WIDTH = 50
)(
    input logic clk,
    input logic rst,

    input logic [15:0] ub_write_data_1_in,
    input logic [15:0] ub_write_data_2_in,
    input logic ub_write_valid_1_in,
    input logic ub_write_valid_2_in,

    // ISA ***
    input logic ub_write_start_in, // DETERMINES IF WE ARE WRITING
    input logic ub_read_start_in, // supplied from assembly code (THIS DETERMINES IF WE START READING)
    input logic ub_row_or_col_in, // read row or column
    input logic [5:0] ub_read_addr_in, // this supplies the address which we decode from our ISA
    input logic [5:0] ub_num_mem_locations_in, // NOT AN ADDRESS (THE NUMBER OF MEM LOCATIONS/CELLS TO INCREMENT BY)
    // ISA ***
    
    output logic [15:0] ub_data_1_out,
    output logic [15:0] ub_data_2_out,
    
    output logic ub_valid_1_out,
    output logic ub_valid_2_out
);

    logic [15:0] ub_memory [UNIFIED_BUFFER_WIDTH];
    logic [5:0] wr_ptr; // where to write
    logic [5:0] rd_ptr; // where to read (we need to assign this variable to this ub_read_addr_in)
    logic [5:0] rd_num_locations_left; // how many memory locations to read (counter)
    assign rd_ptr = ub_read_addr_in; 


    always @(posedge clk or posedge rst) begin

        // view simulation only
        for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin
            $dumpvars(0, ub_memory[i]);
        end

        // reset all memory to 0
        if (rst) begin
            wr_ptr <= 0;
            // set every memory register to 0
            for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin  
                ub_memory[i] <= 0;
            end
        end else begin // reset is false, try reading
            // we keep ub_read_start and ub_write_start as seperate if blocks because they can run at the same time!
            // reading (Leaky ReLU to UB)
            // we will only use the device for non-staggered reading
            if (ub_read_start_in) begin // for reading
                // THIS CASE IS DURING THE FIRST CYCLE OF READING
                ub_data_1_out <= ub_memory[ub_read_addr_in]; 
                ub_data_2_out <= ub_memory[ub_read_addr_in + 1]; 
                rd_num_locations_left <= ub_num_mem_locations_in - 2; // save to internal register
                rd_ptr <= ub_read_addr_in + 2; // save to internal register

            end else begin // ON THE NEXT CLOCK CYCLE AFTER ub_read_start_in IS LOW. 
                if (rd_num_locations_left > 0) begin // we still have data to read
                    ub_data_1_out <= ub_memory[rd_ptr]; 
                    ub_data_2_out <= ub_memory[rd_ptr + 1]; 
                    rd_num_locations_left <= rd_num_locations_left - 2
                    rd_ptr <= rd_ptr + 2;
                end 
            end


            // writing (UB to input or weight accumulators)
            if (ub_write_start) begin
                // both valid, write two values
                if (ub_write_valid_1_in && ub_write_valid_2_in) begin
                    ub_memory[wr_ptr] <= ub_write_data_1_in;
                    ub_memory[wr_ptr + 1] <= ub_write_data_2_in;
                    wr_ptr <= wr_ptr + 2;

                end

                // write if the write valid signal is on
                else if (ub_write_valid_1_in) begin 
                    ub_memory[wr_ptr] <= ub_write_data_1_in;
                    wr_ptr <= wr_ptr + 1;
                end

                // write if the write valid signal is on
                else if (ub_write_valid_2_in) begin 
                    ub_memory[wr_ptr] <= ub_write_data_2_in;
                    wr_ptr <= wr_ptr + 1;
                end
            end
        end
    end
endmodule

