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


module tb_qpsk_mapper(

    );

    logic [1:0] bits_in;
    logic signed [15:0] i_out;
    logic signed [15:0] q_out;


    qpsk_mapper DUT (
        .bits_in(bits_in),
        .i_out(i_out),
        .q_out(q_out)
    );

    task check_output(input logic signed [15:0] expected_i, input logic signed [15:0] expected_q);
        if (i_out !== expected_i || q_out !== expected_q) begin
            $display("Test failed for bits_in = %b: Expected I = %d, Q = %d but got I = %d, Q = %d", bits_in, expected_i, expected_q, i_out, q_out);
        end else begin
            $display("Test passed for bits_in = %b: I = %d, Q = %d", bits_in, i_out, q_out);
        end
    endtask

    initial begin
        bits_in = 2'b00;
        #10;
        check_output(16'sd1024, 16'sd1024);
        bits_in = 2'b01;
        #10;
        check_output(-16'sd1024, 16'sd1024);
        bits_in = 2'b11;
        #10;
        check_output(-16'sd1024, -16'sd1024);
        bits_in = 2'b10;
        #10;
        check_output(16'sd1024, -16'sd1024);
        $finish;
    end
endmodule
