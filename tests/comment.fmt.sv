`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/18/2019 04:03:15 PM
// Design Name: 
// Module Name: port
// Project Name: 
// Target Devices: xc7z020clg484-2
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

`include "constants.vh"

module port (
    input gtx_clk, // 125MHz

    // ARP table
    input logic arp_insert_ready,

    // fifo matrix
    // tx
    // sender set valid = 1 for a transfer
    // valid & ready = 1, transfer starts one cycle later
    // last = 1 for last byte in the transfer
    output logic [`PORT_OS_COUNT - 1:0] fifo_matrix_tx_wready,

    // shared=1
    input gtx_clk90, // 125MHz, 90 deg shift
    // shared=0
    output gtx_clk_out, // 125MHz
    output gtx_clk90_out, // 125MHz, 90 deg shift
    input refclk // 200MHz

);

    // stores ethernet frame data
    xpm_fifo_async # (.READ_DATA_WIDTH (`BYTE_WIDTH),
        .WRITE_DATA_WIDTH (`BYTE_WIDTH),
        .FIFO_WRITE_DEPTH (`MAX_FIFO_SIZE),
        .PROG_FULL_THRESH (`MAX_FIFO_SIZE - `MAX_ETHERNET_FRAME_BYTES),
        .READ_MODE ("fwft"), // special
        .FIFO_READ_LATENCY (0) // special
    ) xpm_fifo_zsync_inst_tx_data (.dout (tx_data_out),
        .rd_en (tx_data_ren),
        .rd_clk (tx_mac_aclk),

        .prog_full (tx_data_full),
        .din (tx_data_in),
        .rst (reset),
        .wr_clk (clk),
        .wr_en (tx_data_wen),
        .wr_rst_busy (tx_data_busy));
endmodule