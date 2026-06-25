`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2026 12:14:09 AM
// Design Name: 
// Module Name: tb_qpsk_mapper
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

import  fixed_pkg::*;
module tb_qpsk_mapper(

    );

    logic [1:0] bits_in;
    cplx_t symbol_out;


    qpsk_mapper DUT (
        .bits_in(bits_in),
        .symbol_out(symbol_out)
    );

    task check_output(input logic signed [15:0] expected_i,expected_q);
        if (symbol_out.re !== expected_i || symbol_out.im !== expected_q) begin
            $display("Test failed for bits_in = %b: Expected I = %d, Q = %d but got I = %d, Q = %d", bits_in, expected_i, expected_q,  symbol_out.re,  symbol_out.im);
        end else begin
            $display("Test passed for bits_in = %b: I = %d, Q = %d", bits_in,  symbol_out.re,  symbol_out.im);
        end
    endtask

    initial begin
        bits_in = 2'b00;
        #10;
        check_output(16'sd8192, 16'sd8192);
        bits_in = 2'b01;
        #10;
        check_output(-16'sd8192, 16'sd8192);
        bits_in = 2'b11;
        #10;
        check_output(-16'sd8192, -16'sd8192);
        bits_in = 2'b10;
        #10;
        check_output(16'sd8192, -16'sd8192);
        $finish;
    end
endmodule
