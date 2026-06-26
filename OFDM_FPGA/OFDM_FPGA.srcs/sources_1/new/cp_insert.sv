`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/25/2026 03:55:39 PM
// Design Name: 
// Module Name: cp_insert
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
import fixed_pkg::*;

module cp_insert (
    input  logic  clk,
    input  logic  n_rst,
    
    // AXI-Stream slave (from IFFT)
    input  cplx_t in_data,
    input  logic  in_valid,
    output logic  in_ready,
    
    // AXI-Stream master (to downstream)
    output cplx_t out_data,
    output logic  out_valid,
    input  logic  out_ready,
    output logic  out_last
);
    typedef enum logic [1:0] {
        WRITE = 0,
        WARM_READ = 1,
        READ = 2
    } state_t;

    state_t n_state, state;
    logic [$clog2(64)-1:0] wr_idx, wr_idx_next;
    logic[$clog2(80)-1:0] rd_idx,rd_idx_next;
    cplx_t mem [0:63];



    always_ff @(posedge clk or negedge n_rst)begin
        if(!n_rst) begin
            state <= WRITE;
            
        end
        else begin
            state <= n_state;
        
        end
    end

    //next_state logic
    logic input_trans;
    assign input_trans = (state == WRITE) && in_ready && in_valid;
    logic output_trans;
    assign output_trans = (state == READ) && out_ready && out_valid;


    always_comb begin
        n_state = state;
        case(state)
            WRITE : if(input_trans && wr_idx == 63) n_state = WARM_READ;
            WARM_READ : n_state = READ;
            READ :  if(output_trans && rd_idx == 79) n_state = WRITE;
            default : n_state = state;
        endcase
    end

    //next counter logic
    always_comb begin
        if(input_trans) wr_idx_next = wr_idx + 1;
        else wr_idx_next = wr_idx;

        if(output_trans && rd_idx == 79) rd_idx_next = 0;
        else if(output_trans) rd_idx_next = rd_idx + 1;
        else rd_idx_next = rd_idx;

    end

    always_ff @(posedge clk or negedge n_rst)begin
        if(!n_rst)begin
            rd_idx <= 0;
            wr_idx <= 0;
        end
        else begin
            rd_idx <= rd_idx_next;
            wr_idx <= wr_idx_next;
        end
    end

    always_ff @(posedge clk) begin
        if (state == WRITE && in_valid && in_ready) begin
            mem[wr_idx] <= in_data;
        end
    end

    cplx_t mem_out;
    always_ff @(posedge clk) begin
        mem_out <= mem[mem_addr];
    end


    logic [$clog2(64)-1:0] mem_addr;
    assign mem_addr = (rd_idx_next < 16) ? (rd_idx_next + 48) : (rd_idx_next - 16);
    

    //output logic 
    always_comb begin
        in_ready = 0;
        out_valid = 0;  
        out_last  = 0;   
        case(state)
            WRITE : begin 
                in_ready  = 1;
                out_valid = 0;
            end
            WARM_READ : begin
                in_ready = 0;
                out_valid = 0;
            end
            READ : begin
                in_ready = 0;
                out_valid = 1;
                out_data  = mem_out;
                out_last = (rd_idx == 79);
            end
            default : begin 
                in_ready = 0;
                out_valid = 0;
                out_data = 0;

            end
        endcase
    end

endmodule
