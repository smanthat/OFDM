`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/25/2026 03:57:43 PM
// Design Name: 
// Module Name: tb_cp_insert
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

import fixed_pkg::*;
module tb_cp_insert;

    localparam int N       = 64;
    localparam int CP_LEN  = 16;
    localparam int OUT_LEN = N + CP_LEN;   // 80

    logic   clk, n_rst;
    cplx_t  in_data;
    logic   in_valid, in_ready, in_last;
    cplx_t  out_data;
    logic   out_valid, out_ready, out_last;

    int in_count  = 0;
    int out_count = 0;
    int errors    = 0;

    logic [31:0] input_samples    [0:N-1];
    logic [31:0] expected_samples [0:OUT_LEN-1];
    cplx_t       got              [0:OUT_LEN-1];

    initial begin
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_time.txt", input_samples);
        $readmemh("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_with_cp.txt", expected_samples);
    end
    // ----- DUT -----
    cp_insert DUT (
        .clk(clk), .n_rst(n_rst),
        .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready), .out_last(out_last)
    );

    // ----- clock -----
    initial clk = 0;
    always #5 clk = ~clk;

    // ----- input feeder (parallel process) -----
    always_comb begin
    in_valid = 1'b0;
    in_data  = '0;
    in_last  = 1'b0;
    if (in_count < N) begin
        in_valid = 1'b1;
        in_data  = input_samples[in_count];
        in_last  = (in_count == N-1);
    end
end

    always_ff @(posedge clk) begin
        if (!n_rst) begin
            in_count <= 0;
        end else if (in_count < N) begin
            if (in_valid && in_ready) begin
                in_count <= in_count + 1;
            end
        end
    end

    // ----- output capture (parallel process) -----
    assign out_ready = 1'b1;
    always_ff @(posedge clk) begin
        if (out_valid && out_ready && out_count < OUT_LEN) begin
            got[out_count] <= out_data;
            out_count      <= out_count + 1;
        end
    end

    // ----- main: reset, wait, diff -----
    initial begin
        n_rst = 0;
        repeat (4) @(negedge clk);
        n_rst = 1;

        // wait for all output samples
        wait (out_count == OUT_LEN);

        // diff
        for (int i = 0; i < OUT_LEN; i++) begin
            automatic logic [31:0] got_p;
            got_p = {got[i].re, got[i].im};
            if (got_p !== expected_samples[i]) begin
                $display("FAIL [%0d]: expected %08h, got %08h", i, expected_samples[i], got_p);
                errors++;
            end
        end

        if (errors == 0)
            $display("\n========== ALL %0d SAMPLES PASSED ==========", OUT_LEN);
        else
            $display("\n========== %0d FAILURES out of %0d ==========", errors, OUT_LEN);

        $finish;
    end

endmodule