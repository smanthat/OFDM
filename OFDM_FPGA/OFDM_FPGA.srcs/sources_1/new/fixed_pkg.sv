`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/18/2026 02:03:19 PM
// Design Name: 
// Module Name: fixed_pkg
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


package fixed_pkg;
    typedef logic signed [15:0] fixed_t;        // Q2.13 plus sign
  typedef struct packed {
    fixed_t re;
    fixed_t im;
  } cplx_t;                                   
endpackage 
