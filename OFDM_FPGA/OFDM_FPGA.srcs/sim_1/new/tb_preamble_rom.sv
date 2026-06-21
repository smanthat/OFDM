`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/18/2026 06:35:46 PM
// Design Name: 
// Module Name: tb_preamble_rom
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
module tb_preamble_rom;


    localparam int DEPTH = 64;
    logic clk;
    logic [$clog2(DEPTH)-1:0] addr;
    cplx_t data_out;
    int errors = 0;

    logic [31:0] expected [0:63];
    initial begin
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/preamble_timing.hex",expected);
    end


    preamble_rom #(
    .DEPTH(DEPTH),
    .INIT_FILE("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/preamble_timing.hex")
    ) DUT (
    .clk(clk),
    .addr(addr),
    .data_out(data_out)
)   ;

    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;


    task check_output(
        input[5:0] a_val);
        cplx_t got;
        logic [31:0] exp;
        got = data_out;
        exp = expected[a_val];
        
        if({got.re,got.im} !== exp)begin
            $display("FAIL addr=%0d: expected %08h, got re=%04h im=%04h",
                     a_val, exp, got.re, got.im);
            errors++;
        end else begin
            $display("PASS addr=%0d: %08h", a_val, exp);
        end
    
    endtask

    initial begin
         // wait for ROM init to complete
        addr = 0;
        @(negedge clk);
        @(negedge clk);  // first read settles, data_out reflects mem[0]

        // walk through every address
        for (int i = 0; i < 64; i++) begin
            addr = i[5:0];
            @(negedge clk);   // synchronous read: data_out updates next edge
            #1;               // let combinational settle
            check_output(i[5:0]);
        end

        // summary
        if (errors == 0)
            $display("\n========== ALL 64 PASSED ==========");
        else
            $display("\n========== %0d FAILURES ==========", errors);


        $finish;
    end
endmodule
