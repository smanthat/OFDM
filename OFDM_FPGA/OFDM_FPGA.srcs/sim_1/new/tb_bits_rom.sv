`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 10:21:17 AM
// Design Name: 
// Module Name: tb_bits_rom
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

module tb_bit_rom;

    logic       clk;
    logic [7:0] addr;
    logic [7:0] data_out;
    logic [7:0] expected [0:255];
    int errors = 0;

    initial begin
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/bits.hex", expected);
    end

    bits_rom DUT (.clk(clk), .addr(addr), .data_out(data_out));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        addr = 0;
        @(posedge clk);   // ROM reads addr=0
        @(posedge clk);   // pipeline settles
        
        for (int i = 0; i < 256; i++) begin
            addr = i;
            @(posedge clk);
            #1;
            if (data_out !== expected[i]) begin
                $display("FAIL addr=%0d: expected %02h, got %02h", i, expected[i], data_out);
                errors++;
            end else begin
                $display("PASS addr=%0d: %02h", i, data_out);
            end
        end

        if (errors == 0)
            $display("\n========== ALL 256 PASSED ==========");
        else
            $display("\n========== %0d FAILURES ==========", errors);

        $finish;
    end

endmodule
