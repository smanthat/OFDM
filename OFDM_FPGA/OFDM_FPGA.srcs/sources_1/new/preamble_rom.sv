`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/18/2026 06:00:48 PM
// Design Name: 
// Module Name: preamble_rom
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
module preamble_rom#(
    parameter int DEPTH = 64,
    parameter string INIT_FILE = "C:/Sourish/OFDM/OFDM Simulation/Verification_Files/preamble_timing.hex"
    )(
    input logic clk,
    input logic [$clog2(DEPTH)-1:0] addr,
    output cplx_t data_out
    );

    (* rom_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, mem);
        if(^mem[0] == 1'bx) begin
            $error("ROM init failed: %s not found or empty", INIT_FILE);
            $finish;

        end
    end
    

    always_ff @(posedge clk) begin
        data_out <= mem[addr];
    end


endmodule

