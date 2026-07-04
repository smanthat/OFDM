`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 02:59:54 PM
// Design Name: 
// Module Name: button_sync
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

module button_sync (
    input  logic clk,
    input  logic n_rst,
    input  logic btn_async,
    output logic pulse       // one-cycle pulse on rising edge
);
    logic s0, s1, s2;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) {s0, s1, s2} <= '0;
        else        {s0, s1, s2} <= {btn_async, s0, s1};
    end
    assign pulse = s1 & ~s2;
endmodule
