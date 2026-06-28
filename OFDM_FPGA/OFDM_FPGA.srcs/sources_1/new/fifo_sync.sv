`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2026 11:19:11 AM
// Design Name: 
// Module Name: fifo_sync
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

module fifo_sync #(
    parameter int DEPTH = 2048,
    parameter int WIDTH = 32
) (
    input  logic              clk,
    input  logic              n_rst,
    input  logic [WIDTH-1:0]  in_data,
    input  logic              in_valid,
    output logic              in_ready,
    output logic [WIDTH-1:0]  out_data,
    output logic              out_valid,
    input  logic              out_ready
);

    // Internal wires connecting to the Xilinx IP
    logic        srst;
    logic        full, empty;
    logic        wr_en, rd_en;

    // === YOUR LOGIC HERE ===
    // Use the 6 expressions you derived to drive:
    //   srst, in_ready, out_valid, wr_en, rd_en
    // (din and out_data go directly into the IP instantiation)
    assign srst = !n_rst;
    assign in_ready = !full;
    assign out_valid = !empty;

    assign wr_en = in_valid && in_ready;
    assign rd_en = out_valid && out_ready;

    // === IP INSTANTIATION ===
    fifo_generator_0 u_fifo (
        .clk   (clk),
        .srst  (srst),
        .din   (in_data),
        .wr_en (wr_en),
        .rd_en (rd_en),
        .dout  (out_data),
        .full  (full),
        .empty (empty)
    );

endmodule