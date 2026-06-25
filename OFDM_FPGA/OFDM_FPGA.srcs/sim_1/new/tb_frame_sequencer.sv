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
    localparam string GOLDEN_FILE = "C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_freq.txt";

    logic [13:0] out_count;
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
        if(!n_rst)begin
            out_count <= 0;
        end
        else if (out_valid && out_ready && out_count < TOTAL_SAMPLES) begin
            got_frame[out_count] <= {out_data.re,out_data.im};
            out_count      <= out_count + 1;
        end
    end
    
    initial begin
            

        start =0;

        n_rst = 0;
        repeat(4) @(negedge clk);
    
        n_rst = 1;

        repeat(4) @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        
          fork
        begin
            wait(out_count == TOTAL_SAMPLES);
        end

        begin
            repeat(TOTAL_SAMPLES + 100) @(negedge clk);
            $fatal(1,
                "TIMEOUT: only captured %0d/%0d samples. done=%0b out_valid=%0b out_ready=%0b",
                out_count, TOTAL_SAMPLES, done, out_valid, out_ready
            );
        end
    join_any
    disable fork;

        @(negedge clk);

        for(int i = 0;i<TOTAL_SAMPLES;i++)begin
            logic [31:0] got_p = got_frame[i];
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

        initial begin
    #20_000; // 20 us because timescale is 1ns / 1ps
    $fatal(1, "TIMEOUT: out_count=%0d done=%0b out_valid=%0b out_ready=%0b",
           out_count, done, out_valid, out_ready);
    end
    

endmodule
