`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2026 12:06:08 AM
// Design Name: 
// Module Name: qpsk_mapper
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
module qpsk_mapper(
    input logic [1:0] bits_in,
    output cplx_t symbol_out
    );
    always_comb begin
        
        case(bits_in)
            2'b00 : begin
                symbol_out.re = 16'sd8192;
                symbol_out.im = 16'sd8192;
            end

            2'b01 : begin
                symbol_out.re = -16'sd8192;
                symbol_out.im = 16'sd8192;
            end

            2'b11 : begin
                symbol_out.re = -16'sd8192;
                symbol_out.im = -16'sd8192;
            end

            2'b10 : begin
                symbol_out.re = 16'sd8192;
                symbol_out.im = -16'sd8192;
            end

            default : begin
                symbol_out.re = 16'sd0;
                symbol_out.im = 16'sd0;
            end

        endcase

    end

endmodule
    