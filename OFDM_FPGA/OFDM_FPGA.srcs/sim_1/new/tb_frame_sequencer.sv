`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 10:05:50 PM
// Design Name: 
// Module Name: tb_frame_sequencer
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
module tb_frame_sequencer;
    logic clk,n_rst;
    logic start;
    logic done;
    cplx_t out_data;
    logic out_valid, out_ready;

    localparam int TOTAL_SAMPLES = 1152;
    localparam string GOLDEN_FILE = "C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_freq.hex";

    int out_count =0;
    int errors =0;


    logic [31:0] expected_frame [0:TOTAL_SAMPLES-1];  
    initial begin
        $readmemh(GOLDEN_FILE,expected_frame);
    end


    logic [31:0] got_frame [0:TOTAL_SAMPLES-1];
    
    frame_sequencer DUT (.clk(clk),.n_rst(n_rst),.start(start),
                        .done(done),.out_data(out_data),.out_valid(out_valid),
                        .out_ready(out_ready));

                        
    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;

    assign out_ready = 1'b1;
    
    always_ff @(posedge clk) begin
        if (out_valid && out_ready && out_count < TOTAL_SAMPLES) begin
            got_frame[out_count] <= out_data;
            out_count      <= out_count + 1;
        end
    end
    
    initial begin

        n_rst = 0;
        repeat(4) @(negedge clk);
    
        n_rst = 1;

        start = 1;
        @(negedge clk);
        start = 0;
        
        wait (out_count == TOTAL_SAMPLES);
        @(negedge clk);

        for(int i = 0;i<TOTAL_SAMPLES;i++)begin
            logic [31:0] got_p = {got_frame[i].re,got[i].im};
            if(got_p !== expected_frame[i])begin
                $display("TEST CASE FAILED: EXPECTED RE,IM -> %04h, %04h GOT RE/IM -> %04h, %04h", expected_frame[i][31:16], expected_frame[i][15:0],got_p[31:16],got_p[15:0]);
                errors++;
            end
        end

        if (errors == 0)
            $display("\n========== ALL %0d SAMPLES PASSED ==========", TOTAL_SAMPLES);
        else
            $display("\n========== %0d FAILURES out of %0d ==========", errors, TOTAL_SAMPLES);

        

        $finish;
    end

endmodule
