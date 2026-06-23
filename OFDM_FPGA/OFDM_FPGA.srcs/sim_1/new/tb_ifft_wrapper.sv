`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/21/2026 07:58:22 PM
// Design Name: 
// Module Name: tb_ifft_wrapper
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
module tb_ifft_wrapper;

    logic clk, n_rst, in_valid, in_ready, out_valid,out_ready,out_last;
    cplx_t in_data, out_data;

    int errors = 0;
    
    logic [31:0] inputs   [0:1151];   // hold full file; we use first 64
    logic [31:0] expected [0:1151];   // same
    cplx_t       got      [0:63];

    initial begin
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_freq.txt", inputs);
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_time.txt", expected);
    end

    int in_count;
    int out_count;


    ifft_wrapper DUT (.clk(clk),.n_rst(n_rst),.in_data(in_data),.in_valid(in_valid),
    .in_ready(in_ready),.out_data(out_data),.out_valid(out_valid),
    .out_ready(out_ready),.out_last(out_last));


    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;
    
    // ----- INPUT DRIVER (master role) -----
    always_comb begin
        in_data.re = inputs[in_count][31:16];
        in_data.im = inputs[in_count][15:0];
    end
    assign in_valid = (in_count < 64);

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            in_count <= 0;
        else if (in_valid && in_ready)
            in_count <= in_count + 1;
    end

    // ----- OUTPUT CAPTURE (slave role) -----
    assign out_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (out_valid && out_ready && out_count < 64) begin
            got[out_count] <= out_data;
            out_count      <= out_count + 1;
        end
    end


    initial begin
        
        n_rst = 0;
        repeat (4) @(posedge clk);
        n_rst = 1;

        wait (out_count == 64);
        @(posedge clk);

        for (int j = 0; j < 64; j++) begin
            logic signed [15:0] got_re, got_im, exp_re, exp_im;
            int re_err, im_err;

            got_re = got[j].re;
            got_im = got[j].im;
            exp_re = expected[j][31:16];
            exp_im = expected[j][15:0];

            re_err = (got_re > exp_re) ? (got_re - exp_re) : (exp_re - got_re);
            im_err = (got_im > exp_im) ? (got_im - exp_im) : (exp_im - got_im);

            if (re_err > 2 || im_err > 2) begin
                $display("FAIL [%0d]: expected re=%0d im=%0d, got re=%0d im=%0d (err %0d/%0d)",
                         j, exp_re, exp_im, got_re, got_im, re_err, im_err);
                errors++;
            end else begin
                $display("PASS [%0d]: re=%0d im=%0d (err %0d/%0d)",
                         j, got_re, got_im, re_err, im_err);
            end
        end

        if (errors == 0)
            $display("\n========== ALL 64 PASSED ==========");
        else
            $display("\n========== %0d FAILURES ==========", errors);
        $finish;
    end

endmodule
