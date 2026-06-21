`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2026 11:03:01 AM
// Design Name: 
// Module Name: uart_tx
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
typedef enum logic [3:0] { 
    IDLE = 4'b0000,
    START = 4'b0001,
    DATA0 = 4'b0010,
    DATA1 = 4'b0011,
    DATA2 = 4'b0100,
    DATA3 = 4'b0101,
    DATA4 = 4'b0110,
    DATA5 = 4'b0111,
    DATA6 = 4'b1000,
    DATA7 = 4'b1001,
    STOP = 4'b1010
 } state_t;

module uart_tx#(
    parameter int CLK_HZ   = 100_000_000,
    parameter int BAUD     = 115_200,
    parameter int BAUD_DIV = CLK_HZ / BAUD       // 868
)(
    input logic clk, n_rst,
    input logic [7:0] data_in,
    input logic data_valid,
    output logic tx_out,
    output logic busy
    );

    state_t n_state, state;
 
    always_ff @(posedge clk or negedge n_rst) begin
        if(~n_rst)begin 
            state <= IDLE;
        end
        else begin
            state <= n_state;

        end
    end


    logic [9:0] baud_counter;
    logic       baud_tick;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            baud_counter <= 0;
        else if (baud_counter == BAUD_DIV - 1)
            baud_counter <= 0;
        else
            baud_counter <= baud_counter + 1;
    end

    assign baud_tick = (baud_counter == BAUD_DIV - 1);
    // ... use baud_tick in your next-state logic
    


    always_comb begin
    n_state = state;
    case (state)
        IDLE:  if (data_valid) n_state = START;
        START: if (baud_tick)  n_state = DATA0;
        DATA0: if (baud_tick)  n_state = DATA1;
        DATA1: if (baud_tick)  n_state = DATA2;
        DATA2: if (baud_tick)  n_state = DATA3;
        DATA3: if (baud_tick)  n_state = DATA4;
        DATA4: if (baud_tick)  n_state = DATA5;
        DATA5: if (baud_tick)  n_state = DATA6;
        DATA6: if (baud_tick)  n_state = DATA7;
        DATA7: if (baud_tick)  n_state = STOP;
        STOP:  if (baud_tick)  n_state = IDLE;
        default : n_state = IDLE;
    endcase
    end


    always_comb begin : output_logic
        tx_out = 1;
        busy = 0;
        casez(state)
            IDLE : begin
                tx_out = 1;
                busy = 0;
                end 
            START : begin
                tx_out = 0;
                busy = 1;
            end
            DATA0 : begin
                tx_out = data_in[0];
                busy = 1;
            end
            DATA1 : begin
                tx_out = data_in[1];
                busy = 1;
            end
            DATA2 : begin
                tx_out = data_in[2];
                busy = 1;
            end
            DATA3 : begin
                tx_out = data_in[3];
                busy = 1;
            end
            DATA4 : begin
                tx_out = data_in[4];
                busy = 1;
            end
            DATA5 : begin
                tx_out = data_in[5];
                busy = 1;
            end
            DATA6 : begin
                tx_out = data_in[6];
                busy = 1;
            end
            DATA7 : begin
                tx_out = data_in[7];
                busy = 1;
            end
            STOP : begin
                tx_out = 1;
                busy = 1;
            end
            default : begin 
                tx_out = 1;
            busy = 0;
            end
        endcase



    end

    
    
endmodule
