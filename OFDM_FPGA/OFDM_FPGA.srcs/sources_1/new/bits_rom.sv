`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 10:20:54 AM
// Design Name: 
// Module Name: bits_rom
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


module bits_rom #(
    parameter int    DEPTH     = 256,
    parameter string INIT_FILE = "C:/Sourish/OFDM/OFDM Simulation/Verification_Files/bits.hex"
    )(
    input  logic                       clk,
    input  logic [$clog2(DEPTH)-1:0]   addr,
    output logic [7:0]                 data_out
    );
        (* rom_style = "block" *) logic [7:0] mem [0:DEPTH-1];

   initial begin
        $readmemh(INIT_FILE, mem);
        if (^mem[0] === 1'bx) begin
            $error("bit_rom init failed: %s not found or empty", INIT_FILE);
            $finish;
        end
    end

    always_ff @(posedge clk) begin
        data_out <= mem[addr];
    end
    
endmodule
