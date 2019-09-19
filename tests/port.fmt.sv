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

module port #(
    parameter shared = 1
) (
    input clk,
    input gtx_clk, // 125MHz
    input reset_n,

    input [`PORT_WIDTH-1:0] port_id,
    input [`PORT_COUNT-1:0][`IPV4_WIDTH-1:0] port_ip,
    input [`MAC_WIDTH-1:0] port_mac,

    // ARP table
    output logic arp_arbiter_req,
    input arp_arbiter_granted,
    output logic [`IPV4_WIDTH-1:0] arp_lookup_ip,
    input [`MAC_WIDTH-1:0] arp_lookup_mac,
    input [`PORT_WIDTH-1:0] arp_lookup_port,
    output logic arp_lookup_ip_valid,
    input arp_lookup_mac_valid,
    input arp_lookup_mac_not_found,
    output logic [`IPV4_WIDTH-1:0] arp_insert_ip,
    output logic [`MAC_WIDTH-1:0] arp_insert_mac,
    output logic [`PORT_WIDTH-1:0] arp_insert_port,
    output logic arp_insert_valid,
    input logic arp_insert_ready,

    // Routing table
    output logic routing_arbiter_req,
    input routing_arbiter_granted,
    output logic [`IPV4_WIDTH-1:0] routing_lookup_dest_ip,
    input [`IPV4_WIDTH-1:0] routing_lookup_via_ip,
    input [`PORT_WIDTH-1:0] routing_lookup_via_port,
    output logic routing_lookup_valid,
    input routing_lookup_ready,
    input routing_lookup_output_valid,
    input routing_lookup_not_found,

    // fifo matrix
    // tx
    // sender set valid = 1 for a transfer
    // valid & ready = 1, transfer starts one cycle later
    // last = 1 for last byte in the transfer
    input [`PORT_OS_COUNT-1:0][`BYTE_WIDTH-1:0] fifo_matrix_tx_wdata,
    input [`PORT_OS_COUNT-1:0]fifo_matrix_tx_wlast ,
    input [`PORT_OS_COUNT-1:0]fifo_matrix_tx_wvalid,
    output logic [`PORT_OS_COUNT-1:0]fifo_matrix_tx_wready,
    // rx
    output logic [`PORT_OS_COUNT-1:0][`BYTE_WIDTH-1:0] fifo_matrix_rx_wdata,
    output logic [`PORT_OS_COUNT-1:0]fifo_matrix_rx_wlast,
    output logic [`PORT_OS_COUNT-1:0]fifo_matrix_rx_wvalid,
    input [`PORT_OS_COUNT-1:0]fifo_matrix_rx_wready,

    // shared=1
    input gtx_clk90, // 125MHz, 90 deg shift
    // shared=0
    output gtx_clk_out, // 125MHz
    output gtx_clk90_out, // 125MHz, 90 deg shift
    input refclk, // 200MHz

    input logic [3:0] rgmii_rd,
    input logic rgmii_rx_ctl,
    input logic rgmii_rxc,
    output logic [3:0] rgmii_td,
    output logic rgmii_tx_ctl,
    output logic rgmii_txc,

    // statistics
    output logic [`STATS_WIDTH-1:0] stats_rx_packets,
    output logic [`STATS_WIDTH-1:0] stats_rx_bytes,
    output logic [`STATS_WIDTH-1:0] stats_tx_packets,
    output logic [`STATS_WIDTH-1:0] stats_tx_bytes
    );

    logic reset;
    assign reset = ~reset_n;

    logic rx_enable;

    logic [27:0] rx_statistics_vector;
    logic rx_statistics_valid;

    logic rx_mac_aclk;
    logic rx_reset;
    logic [7:0] rx_axis_mac_tdata;
    logic rx_axis_mac_tvalid;
    logic rx_axis_mac_tlast;
    logic rx_axis_mac_tuser;

    logic tx_enable;

    logic [31:0] tx_statistics_vector;
    logic tx_statistics_valid;
    logic tx_mac_aclk;
    logic tx_reset;
    logic [7:0] tx_axis_mac_tdata;
    logic tx_axis_mac_tvalid = 0;
    logic tx_axis_mac_tlast = 0;
    logic tx_axis_mac_tuser = 0;
    logic tx_axis_mac_tready;

    logic speedis100;
    logic speedis10100;

    logic link_status;
    logic [1:0] clock_speed;
    logic duplex_status;

    logic [15:0] counter = 0;

    logic [`BYTE_WIDTH-1:0] tx_data_out;
    logic tx_data_ren;

    logic tx_data_full;
    logic [`BYTE_WIDTH-1:0] tx_data_in;
    logic tx_data_busy;
    logic tx_data_wen;
 
    // stores ethernet frame data
    xpm_fifo_async #(
        .READ_DATA_WIDTH(`BYTE_WIDTH),
        .WRITE_DATA_WIDTH(`BYTE_WIDTH),
        .FIFO_WRITE_DEPTH(`MAX_FIFO_SIZE),
        .PROG_FULL_THRESH(`MAX_FIFO_SIZE - `MAX_ETHERNET_FRAME_BYTES),
        .READ_MODE("fwft"), // special
        .FIFO_READ_LATENCY(0) // special
    ) xpm_fifo_zsync_inst_tx_data (
        .dout(tx_data_out),
        .rd_en(tx_data_ren),
        .rd_clk(tx_mac_aclk),

        .prog_full(tx_data_full),
        .din(tx_data_in),
        .rst(reset),
        .wr_clk(clk),
        .wr_en(tx_data_wen),
        .wr_rst_busy(tx_data_busy)
    );

    logic [`LENGTH_WIDTH-1:0] tx_len_out;
    logic tx_len_ren = 0;
    logic tx_len_empty;

    logic tx_len_full;
    logic [`LENGTH_WIDTH-1:0] tx_len_in;
    logic tx_len_busy;
    logic tx_len_wen;

    logic [`LENGTH_WIDTH-1:0] tx_length;

    // stores ethernet frame length
    xpm_fifo_async #(
        .READ_DATA_WIDTH(`LENGTH_WIDTH),
        .WRITE_DATA_WIDTH(`LENGTH_WIDTH),
        .FIFO_WRITE_DEPTH(`MAX_FIFO_SIZE),
        .PROG_FULL_THRESH(`MAX_FIFO_SIZE - 16)
    ) xpm_fifo_zsync_inst_tx_len (
        .dout(tx_len_out),
        .rd_en(tx_len_ren),
        .rd_clk(tx_mac_aclk),
        .empty(tx_len_empty),

        .prog_full(tx_len_full),
        .din(tx_len_in),
        .rst(reset),
        .wr_clk(clk),
        .wr_en(tx_len_wen),
        .wr_rst_busy(tx_len_busy)
    );

    // from fifo matrix to tx fifo
    // Round robin
    logic [`PORT_OS_WIDTH-1:0] fifo_matrix_tx_index;
    logic fifo_matrix_tx_progress;
    logic fifo_matrix_tx_last_wlast;
    logic [`LENGTH_WIDTH-1:0] fifo_matrix_tx_length;

    always_ff @ (posedge clk) begin
        if (reset) begin
            fifo_matrix_tx_index <= 0;
            fifo_matrix_tx_wready <= 0;
            fifo_matrix_tx_progress <= 0;
            fifo_matrix_tx_length <= 0;
            tx_data_in <= 0;
            tx_data_wen <= 0;
            tx_len_in <= 0;
            tx_len_wen <= 0;
        end else begin
            fifo_matrix_tx_last_wlast <= fifo_matrix_tx_wlast[fifo_matrix_tx_index];
            if (!fifo_matrix_tx_progress) begin
                if (fifo_matrix_tx_wvalid[fifo_matrix_tx_index] && !tx_len_busy && !tx_data_busy) begin
                    fifo_matrix_tx_progress <= 1;
                    fifo_matrix_tx_wready[fifo_matrix_tx_index] <= 1;
                    fifo_matrix_tx_length <= 0;
                end else begin
                    fifo_matrix_tx_index <= fifo_matrix_tx_index + 1;
                end
            end else if (!fifo_matrix_tx_wlast[fifo_matrix_tx_index] && !fifo_matrix_tx_last_wlast)  begin
                tx_data_wen <= fifo_matrix_tx_length >= 1;
                fifo_matrix_tx_length <= fifo_matrix_tx_length + 1;
                tx_data_in <= fifo_matrix_tx_wdata[fifo_matrix_tx_index];
            end else if (fifo_matrix_tx_last_wlast && !fifo_matrix_tx_wlast[fifo_matrix_tx_index]) begin
                tx_data_in <= 0;
                tx_data_wen <= 0;
                tx_len_in <= 0;
                tx_len_wen <= 0;
                fifo_matrix_tx_progress <= 0;
                fifo_matrix_tx_wready[fifo_matrix_tx_index] <= 0;
            end else begin
                tx_data_in <= fifo_matrix_tx_wdata[fifo_matrix_tx_index];
                tx_data_wen <= 1;
                tx_len_in <= fifo_matrix_tx_length;
                tx_len_wen <= 1;
            end
        end
    end

    // from tx fifo to MAC
    logic tx_send;
    logic [`LENGTH_WIDTH-1:0] tx_send_counter;
    logic [`LENGTH_WIDTH-1:0] tx_send_length;

    assign tx_axis_mac_tdata = tx_data_out;
    assign tx_data_ren = tx_axis_mac_tready;

    always @ (posedge tx_mac_aclk) begin
        if (reset) begin
            tx_len_ren <= 0;
            tx_send <= 0;
            tx_send_counter <= 0;
            tx_send_length <= 0;

            stats_tx_packets <= 0;
            stats_tx_bytes <= 0;
        end else begin
            if (!tx_send && !tx_len_empty) begin
                tx_send <= 1;
                tx_len_ren <= 1;
                tx_send_counter <= 0;
                tx_send_length <= 0;

                stats_tx_packets <= stats_tx_packets + 1;
            end else if (tx_send) begin
                if (tx_axis_mac_tready) begin
                    tx_send_counter <= tx_send_counter + 1;
                end
                if (tx_send_counter == tx_send_length - 2) begin
                    tx_axis_mac_tlast <= 1;
                    tx_send_counter <= 0;
                    tx_send_length <= 0;
                end else if (!tx_axis_mac_tlast) begin
                    tx_axis_mac_tlast <= 0;
                    tx_axis_mac_tvalid <= 1;
                end else begin
                    tx_send <= 0;
                    tx_axis_mac_tlast <= 0;
                    tx_axis_mac_tvalid <= 0;
                end
                if (!tx_send_length && !tx_len_ren) begin
                    tx_send_length <= tx_len_out;
                end

                if (tx_len_ren) begin
                    stats_tx_bytes <= stats_tx_bytes + tx_len_out;
                end
                tx_len_ren <= 0;
            end
        end
    end

    logic [`BYTE_WIDTH-1:0] rx_data_out;
    logic rx_data_ren = 0;

    logic rx_data_full;
    logic [`BYTE_WIDTH-1:0] rx_data_in;
    logic rx_data_busy;
    logic rx_data_wen;
    logic rx_axis_mac_tvalid_last;

    // stores ethernet frame data
    xpm_fifo_async #(
        .READ_DATA_WIDTH(`BYTE_WIDTH),
        .WRITE_DATA_WIDTH(`BYTE_WIDTH),
        .FIFO_WRITE_DEPTH(`MAX_INPUT_FIFO_SIZE),
        .PROG_FULL_THRESH(`MAX_INPUT_FIFO_SIZE - `MAX_ETHERNET_FRAME_BYTES)
    ) xpm_fifo_async_inst_rx_data (
        .dout(rx_data_out),
        .rd_en(rx_data_ren),
        .rd_clk(clk),

        .prog_full(rx_data_full),
        .din(rx_data_in),
        .rst(reset),
        .wr_clk(rx_mac_aclk),
        .wr_en(rx_data_wen),
        .wr_rst_busy(rx_data_busy)
    );

    logic [`LENGTH_WIDTH-1:0] rx_len_out;
    logic rx_len_ren = 0;
    logic rx_len_empty;

    logic rx_len_full;
    logic [`LENGTH_WIDTH-1:0] rx_len_in;
    logic rx_len_busy;
    logic rx_len_wen;

    logic [`LENGTH_WIDTH-1:0] rx_length;

    // stores ethernet frame length
    xpm_fifo_async #(
        .READ_DATA_WIDTH(`LENGTH_WIDTH),
        .WRITE_DATA_WIDTH(`LENGTH_WIDTH),
        .FIFO_WRITE_DEPTH(`MAX_FIFO_SIZE),
        .PROG_FULL_THRESH(`MAX_FIFO_SIZE - 16)
    ) xpm_fifo_async_inst_rx_len (
        .dout(rx_len_out),
        .rd_en(rx_len_ren),
        .rd_clk(clk),
        .empty(rx_len_empty),

        .prog_full(rx_len_full),
        .din(rx_len_in),
        .rst(reset),
        .wr_clk(rx_mac_aclk),
        .wr_en(rx_len_wen),
        .wr_rst_busy(rx_len_busy)
    );

    // store received ethernet frame into fifo, data first, then len
    always_ff @ (posedge rx_mac_aclk) begin
        if (reset) begin
            rx_data_wen <= 0;
            rx_axis_mac_tvalid_last <= 0;
            rx_length <= 0;
            rx_len_wen <= 0;
            rx_len_in <= 0;

            stats_rx_packets <= 0;
            stats_rx_bytes <= 0;
        end else begin
            rx_axis_mac_tvalid_last <= rx_axis_mac_tvalid;
            if (rx_axis_mac_tvalid && !rx_axis_mac_tvalid_last && !rx_data_busy && !rx_data_full && !rx_len_busy && !rx_len_full) begin
                // begin
                rx_data_wen <= 1;
                rx_length <= 1;
                rx_data_in <= rx_axis_mac_tdata;
                rx_len_wen <= 0;
                rx_len_in <= 0;
            end else if (!rx_axis_mac_tvalid && rx_axis_mac_tvalid_last && rx_data_wen) begin
                // end
                rx_data_wen <= 0;
                rx_data_in <= 0;
                rx_len_wen <= 1;
                rx_len_in <= rx_length;

                stats_rx_packets <= stats_rx_packets + 1;
                stats_rx_bytes <= stats_rx_bytes + rx_length;
            end else begin
                // progress
                if (rx_data_wen) begin
                    rx_length <= rx_length + 1;
                    rx_data_in <= rx_axis_mac_tdata;
                end else begin
                    rx_data_in <= 0;
                    rx_length <= 0;
                end
                rx_len_wen <= 0;
                rx_len_in <= 0;
            end
        end
    end

    logic rx_read;
    logic [`LENGTH_WIDTH-1:0] rx_read_length;
    logic [`BYTE_WIDTH-1:0] rx_read_data;
    logic [`LENGTH_WIDTH-1:0] rx_read_counter;

    // Ethernet
    logic [`MAC_WIDTH-1:0] rx_saved_dst_mac_addr;
    logic [`MAC_WIDTH-1:0] rx_saved_src_mac_addr;
    logic [`ETHERTYPE_WIDTH-1:0] rx_saved_ethertype;
    // ARP
    logic [`IPV4_WIDTH-1:0] rx_saved_arp_src_ipv4_addr;
    logic [`IPV4_WIDTH-1:0] rx_saved_arp_dst_ipv4_addr;
    logic [`ARP_OPCODE_COUNT*`BYTE_WIDTH-1:0] rx_saved_arp_opcode;
    // IPV4
    logic [`BYTE_WIDTH-1:0] rx_saved_ipv4_ttl;
    logic [`IPV4_CHECKSUM_COUNT*`BYTE_WIDTH-1:0] rx_saved_ipv4_checksum;
    logic [`IPV4_WIDTH-1:0] rx_saved_ipv4_src_addr;
    logic [`IPV4_WIDTH-1:0] rx_saved_ipv4_dst_addr;

    logic [`IPV4_WIDTH-1:0] rx_nexthop_ipv4_addr;
    logic [`PORT_WIDTH-1:0] rx_nexthop_port;
    logic [`MAC_WIDTH-1:0] rx_nexthop_mac_addr;
    //logic [`MAX_ETHERNET_FRAME_BYTES*`BYTE_WIDTH-1:0] rx_saved_ipv4_packet;
    logic rx_found_nexthop_ipv4;
    logic rx_lookup_nexthop_mac;

    logic [`BYTE_WIDTH-1:0] rx_saved_ipv4_in;
    logic [`BYTE_WIDTH-1:0] rx_saved_ipv4_out;
    logic [`LENGTH_WIDTH-1:0] rx_saved_ipv4_addr;
    logic rx_saved_ipv4_wen;

    // stores the current ethernet frame temporarily
    xpm_memory_spram #(
        .ADDR_WIDTH_A(`LENGTH_WIDTH),
        .BYTE_WRITE_WIDTH_A(`BYTE_WIDTH),
        .MEMORY_SIZE(`MAX_ETHERNET_FRAME_BYTES * `BYTE_WIDTH),
        .READ_DATA_WIDTH_A(`BYTE_WIDTH),
        .READ_LATENCY_A(1),
        .WRITE_DATA_WIDTH_A(`BYTE_WIDTH)
    ) xpm_memory_spram_inst_rx_len (
        .douta(rx_saved_ipv4_out),
        .addra(rx_saved_ipv4_addr),
        .clka(clk),
        .dina(rx_saved_ipv4_in),
        .ena(1'b1),
        .rsta(reset),
        .wea(rx_saved_ipv4_wen)
    );

    logic [`ARP_RESPONSE_COUNT*`BYTE_WIDTH-1:0] rx_outbound_arp_response;
    logic [`LENGTH_WIDTH-1:0] rx_outbound_length;
    logic [`LENGTH_WIDTH-1:0] rx_outbound_counter;

    // arp insertion is working
    logic arp_write;
    logic arp_written;
    // ip routing is working
    logic ip_routing;
    logic ip_routed;
    logic ip_lookup_routing;
    // data transfer is working
    logic rx_outbound;
    logic [`PORT_OS_COUNT-1:0] rx_outbound_port_id;

    always_ff @ (posedge clk) begin
        if (reset) begin
            rx_len_ren <= 0;
            rx_data_ren <= 0;
            rx_read <= 0;
            rx_read_data <= 0;

            rx_saved_dst_mac_addr <= 0;
            rx_saved_src_mac_addr <= 0;
            rx_saved_ethertype <= 0;

            rx_saved_arp_src_ipv4_addr <= 0;
            rx_saved_arp_dst_ipv4_addr <= 0;
            rx_saved_arp_opcode <= 0;

            rx_saved_ipv4_ttl <= 0;
            rx_saved_ipv4_checksum <= 0;
            rx_saved_ipv4_src_addr <= 0;
            rx_saved_ipv4_dst_addr <= 0;
            rx_nexthop_ipv4_addr <= 0;
            rx_nexthop_port <= 0;
            rx_nexthop_mac_addr <= 0;
            rx_found_nexthop_ipv4 <= 0;
            rx_lookup_nexthop_mac <= 0;

            arp_write <= 0;
            arp_insert_valid <= 0;
            arp_written <= 0;

            ip_routed <= 0;
            ip_routing <= 0;
            ip_lookup_routing <= 0;
            routing_lookup_valid <= 0;
            routing_lookup_dest_ip <= 0;
            routing_arbiter_req <= 0;
            arp_lookup_ip_valid <= 0;
            arp_lookup_ip <= 0;

            rx_saved_ipv4_in <= 0;
            rx_saved_ipv4_addr <= 0;
            rx_saved_ipv4_wen <= 0;

            rx_outbound <= 0;
            rx_outbound_port_id <= 0;
            rx_outbound_arp_response <= 0;
            rx_outbound_length <= 0;
            rx_outbound_counter <= 0;
            fifo_matrix_rx_wdata <= 0;
            fifo_matrix_rx_wlast <= 0;
            fifo_matrix_rx_wvalid <= 0;
        end else begin
            if (!rx_len_empty && !rx_read && !arp_write && !ip_routing && !rx_outbound) begin 
                rx_read <= 1;
                rx_len_ren <= 1;
                rx_data_ren <= 1;
                rx_read_counter <= -2;

                rx_saved_dst_mac_addr <= 0;
                rx_saved_src_mac_addr <= 0;
                rx_saved_ethertype <= 0;

                rx_saved_arp_src_ipv4_addr <= 0;
                rx_saved_arp_dst_ipv4_addr <= 0;
                rx_saved_arp_opcode <= 0;

                rx_saved_ipv4_ttl <= 0;
                rx_saved_ipv4_checksum <= 0;
                rx_saved_ipv4_src_addr <= 0;
                rx_saved_ipv4_dst_addr <= 0;
                rx_nexthop_ipv4_addr <= 0;
                rx_nexthop_port <= 0;
                rx_nexthop_mac_addr <= 0;
                rx_found_nexthop_ipv4 <= 0;
                rx_lookup_nexthop_mac <= 0;

                arp_written <= 0;

                ip_routed <= 0;
                ip_routing <= 0;
                ip_lookup_routing <= 0;
                routing_lookup_valid <= 0;
                routing_lookup_dest_ip <= 0;
                arp_lookup_ip_valid <= 0;
                arp_lookup_ip <= 0;

                rx_saved_ipv4_in <= 0;
                rx_saved_ipv4_addr <= 0;
                rx_saved_ipv4_wen <= 0;

                rx_outbound <= 0;
                rx_outbound_port_id <= 0;
                rx_outbound_arp_response <= 0;
                fifo_matrix_rx_wdata <= 0;
                fifo_matrix_rx_wlast <= 0;
                fifo_matrix_rx_wvalid <= 0;
                rx_outbound_length <= 0;
                rx_outbound_counter <= 0;
            end else begin
                // read len first, then data
                rx_len_ren <= 0;
                if (rx_read) begin
                    if (!rx_len_ren && rx_read) begin
                        rx_read_length <= rx_len_out;
                    end
                    rx_read_counter <= rx_read_counter + 1;
                    rx_read_data <= rx_data_out;

                    if (rx_read_counter == rx_read_length - 3) begin
                        rx_data_ren <= 0;
                    end
                    if (rx_read_counter == rx_read_length - 2) begin
                        rx_read <= 0;
                    end

                    // Ethernet Handling
                    if (rx_read_counter >= `DST_MAC_BEGIN && rx_read_counter < `DST_MAC_END) begin
                        rx_saved_dst_mac_addr <= {rx_saved_dst_mac_addr[`MAC_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `SRC_MAC_BEGIN && rx_read_counter < `SRC_MAC_END) begin
                        rx_saved_src_mac_addr <= {rx_saved_src_mac_addr[`MAC_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `ETHERTYPE_BEGIN && rx_read_counter < `ETHERTYPE_END) begin
                        rx_saved_ethertype <= {rx_saved_ethertype[`ETHERTYPE_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end

                    // ARP Handling
                    if (rx_read_counter >= `ARP_SRC_IPV4_BEGIN && rx_read_counter < `ARP_SRC_IPV4_END) begin
                        rx_saved_arp_src_ipv4_addr <= {rx_saved_arp_src_ipv4_addr[`IPV4_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `ARP_DST_IPV4_BEGIN && rx_read_counter < `ARP_DST_IPV4_END) begin
                        rx_saved_arp_dst_ipv4_addr <= {rx_saved_arp_dst_ipv4_addr[`IPV4_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `ARP_OPCODE_BEGIN && rx_read_counter < `ARP_OPCODE_END) begin
                        rx_saved_arp_opcode <= {rx_saved_arp_opcode[`ARP_OPCODE_COUNT*`BYTE_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end

                    if (rx_saved_ethertype == `ARP_ETHERTYPE && rx_read_counter >= `ARP_DST_IPV4_END && !arp_write && !arp_written) begin
                        arp_written <= 1;
                        arp_write <= 1;
                        arp_arbiter_req <= 1;
                        arp_insert_valid <= 0;
                        arp_insert_ip <= rx_saved_arp_src_ipv4_addr;
                        arp_insert_mac <= rx_saved_src_mac_addr;
                        arp_insert_port <= port_id;
                        `ifdef HARDWARE_CONTROL_PLANE
                            if (rx_saved_arp_opcode == `ARP_OPCODE_REQUEST && rx_saved_arp_dst_ipv4_addr == port_ip[port_id]) begin
                                // send arp reply
                                rx_outbound <= 1;
                                rx_outbound_port_id <= port_id;
                                rx_outbound_arp_response <= {rx_saved_src_mac_addr, port_mac, `ARP_ETHERTYPE, 16'h0001, `IPV4_ETHERTYPE, 8'h06, 8'h04, `ARP_OPCODE_REPLY, port_mac, port_ip[port_id], rx_saved_src_mac_addr, rx_saved_arp_src_ipv4_addr};
                                rx_outbound_length <= `ARP_RESPONSE_COUNT;
                                rx_outbound_counter <= 0;
                                // send to same port
                                fifo_matrix_rx_wvalid[port_id] <= 1;
                            end
                        `else
                            // when HARDWARE_CONTROL_PLANE is not defined, send packets to OS directly when ip matches
                            if (rx_saved_arp_opcode == `ARP_OPCODE_REQUEST && rx_saved_arp_dst_ipv4_addr == port_ip[port_id]) begin
                                // send arp reply
                                rx_outbound <= 1;
                                rx_outbound_port_id <= `OS_PORT_ID;
                                // pass original request to os
                                rx_outbound_arp_response <= {port_mac, rx_saved_src_mac_addr, `ARP_ETHERTYPE, 16'h0001, `IPV4_ETHERTYPE, 8'h06, 8'h04, `ARP_OPCODE_REQUEST, rx_saved_src_mac_addr, rx_saved_arp_src_ipv4_addr, port_mac, port_ip[port_id]};
                                rx_outbound_length <= `ARP_RESPONSE_COUNT;
                                rx_outbound_counter <= 0;
                                // send to os port
                                fifo_matrix_rx_wvalid[`OS_PORT_ID] <= 1;
                            end
                        `endif
                    end

                    // IPV4 Handling
                    if (rx_read_counter >= `IPV4_TTL_BEGIN && rx_read_counter < `IPV4_TTL_END) begin
                        rx_saved_ipv4_ttl <= rx_read_data;
                    end
                    if (rx_read_counter >= `IPV4_CHECKSUM_BEGIN && rx_read_counter < `IPV4_CHECKSUM_END) begin
                        rx_saved_ipv4_checksum <= {rx_saved_ipv4_checksum[`IPV4_CHECKSUM_COUNT*`BYTE_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `IPV4_SRC_IP_BEGIN && rx_read_counter < `IPV4_SRC_IP_END) begin
                        rx_saved_ipv4_src_addr <= {rx_saved_ipv4_src_addr[`IPV4_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `IPV4_DST_IP_BEGIN && rx_read_counter < `IPV4_DST_IP_END) begin
                        rx_saved_ipv4_dst_addr <= {rx_saved_ipv4_dst_addr[`IPV4_WIDTH-`BYTE_WIDTH-1:0], rx_read_data};
                    end
                    if (rx_read_counter >= `IPV4_BEGIN) begin
                        rx_saved_ipv4_addr <= rx_read_counter - `IPV4_BEGIN;
                        rx_saved_ipv4_in <= rx_read_data;
                        if (rx_read_counter == rx_read_length - 2) begin
                            rx_saved_ipv4_wen <= 0;
                        end else begin
                            rx_saved_ipv4_wen <= 1;
                        end
                    end

                    if (rx_saved_ethertype == `IPV4_ETHERTYPE && rx_read_counter == rx_read_length - 2 && !ip_routing && !ip_routed) begin
                        `ifndef HARDWARE_CONTROL_PLANE
                        // multicast should be sent to os
                        if (rx_saved_ipv4_dst_addr != port_ip[port_id] && rx_saved_ipv4_ttl > 1 && rx_saved_ipv4_dst_addr[`IPV4_WIDTH-1:`IPV4_WIDTH-4] != 4'b1110) begin
                        `else
                        if (rx_saved_ipv4_dst_addr != port_ip[port_id] && rx_saved_ipv4_ttl > 1) begin
                        `endif
                            ip_routed <= 1;
                            ip_routing <= 1;
                            ip_lookup_routing <= 0;
                            routing_arbiter_req <= 1;
                            routing_lookup_valid <= 0;
                        end
                        `ifndef HARDWARE_CONTROL_PLANE
                        else begin
                            // should send to os
                            ip_routed <= 1;
                            ip_routing <= 0;
                            ip_lookup_routing <= 0;
                            rx_found_nexthop_ipv4 <= 0;
                            rx_outbound <= 1;
                            rx_outbound_length <= rx_read_length - 4; // skip fcs
                            rx_outbound_counter <= 0;
                            // reversed, see below
                            rx_nexthop_mac_addr <= rx_saved_dst_mac_addr;
                            rx_saved_dst_mac_addr <= rx_saved_src_mac_addr;
                            // will minus 1 later
                            rx_saved_ipv4_ttl <= rx_saved_ipv4_ttl + 1;
                            // send to os port
                            rx_outbound_port_id <= `OS_PORT_ID;
                            fifo_matrix_rx_wvalid[`OS_PORT_ID] <= 1;
                        end
                        `endif
                    end
                end
                if (arp_write) begin
                    if (arp_arbiter_granted && arp_insert_ready) begin
                        arp_insert_valid <= 1;
                        arp_write <= 0;
                        arp_arbiter_req <= 0;
                    end
                end
                // lookup via ip
                if (ip_routing && !ip_lookup_routing) begin
                    if (routing_arbiter_granted && routing_lookup_ready && !routing_lookup_valid) begin
                        routing_lookup_dest_ip <= rx_saved_ipv4_dst_addr;
                        routing_lookup_valid <= 1;
                    end else if (routing_arbiter_granted && routing_lookup_not_found) begin
                        ip_routing <= 0;
                        routing_lookup_valid <= 0;
                        routing_arbiter_req <= 0;
                        ip_lookup_routing <= 1;
                    end else if (routing_arbiter_granted && routing_lookup_output_valid) begin
                        rx_nexthop_ipv4_addr <= routing_lookup_via_ip;
                        rx_nexthop_port <= routing_lookup_via_port;
                        routing_lookup_valid <= 0;
                        routing_arbiter_req <= 0;
                        rx_found_nexthop_ipv4 <= 1;
                        ip_lookup_routing <= 1;
                    end
                end
                if (ip_routing && rx_found_nexthop_ipv4 && ip_lookup_routing) begin
                    // next hop is found, lookup its mac and port now
                    if (!rx_lookup_nexthop_mac) begin
                        rx_lookup_nexthop_mac <= 1;
                        arp_arbiter_req <= 1;
                    end else if (rx_lookup_nexthop_mac && arp_arbiter_granted && !arp_lookup_mac_valid && !arp_lookup_mac_not_found) begin
                        arp_lookup_ip_valid <= 1;
                        arp_lookup_ip <= rx_nexthop_ipv4_addr;
                    end else if (rx_lookup_nexthop_mac && arp_arbiter_granted && arp_lookup_mac_valid) begin
                        arp_lookup_ip_valid <= 0;
                        arp_arbiter_req <= 0;
                        ip_lookup_routing <= 0;
                        rx_outbound <= 1;
                        rx_outbound_length <= rx_read_length - 4; // skip fcs
                        rx_outbound_counter <= 0;
                        rx_outbound_port_id <= arp_lookup_port;
                        fifo_matrix_rx_wvalid[arp_lookup_port] <= 1;
                        ip_routing <= 0;
                        rx_nexthop_mac_addr <= arp_lookup_mac;
                        // Consider overflow
                        // rx_saved_ipv4_checksum <= rx_saved_ipv4_checksum + 16'h0100;
                        if (rx_saved_ipv4_checksum == 16'hffff) begin
                            rx_saved_ipv4_checksum <= 16'h0100;
                        end else if (rx_saved_ipv4_checksum >= 16'hff00) begin
                            rx_saved_ipv4_checksum <= rx_saved_ipv4_checksum[7:0] + 1;
                        end else begin
                            rx_saved_ipv4_checksum <= rx_saved_ipv4_checksum + 16'h0100;
                        end
                    end else if (rx_lookup_nexthop_mac && arp_arbiter_granted && arp_lookup_mac_not_found) begin
                        arp_lookup_ip_valid <= 0;
                        arp_arbiter_req <= 0;
                        ip_lookup_routing <= 0;
                        ip_routing <= 0;
                        // send arp request
                        arp_written <= 1;
                        rx_outbound <= 1;
                        rx_outbound_arp_response <= {`MAC_WIDTH'hffffffffffff, port_mac, `ARP_ETHERTYPE, 16'h0001, `IPV4_ETHERTYPE, 8'h06, 8'h04, `ARP_OPCODE_REQUEST, port_mac, port_ip[rx_nexthop_port], `MAC_WIDTH'h0, rx_nexthop_ipv4_addr};
                        rx_outbound_length <= `ARP_RESPONSE_COUNT;
                        rx_outbound_counter <= 0;
                        rx_outbound_port_id <= rx_nexthop_port;
                        // send to next hop port
                        fifo_matrix_rx_wvalid[rx_nexthop_port] <= 1;
                    end
                end
                if (rx_outbound && fifo_matrix_rx_wready[rx_outbound_port_id]) begin
                    if (rx_outbound_length > 0) begin
                        rx_outbound_length <= rx_outbound_length - 1;
                        rx_outbound_counter <= rx_outbound_counter + 1;
                        if (arp_written) begin
                            // reply or request
                            rx_outbound_arp_response <= rx_outbound_arp_response << `BYTE_WIDTH;
                            fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_outbound_arp_response[`ARP_RESPONSE_COUNT * `BYTE_WIDTH - 1:`ARP_RESPONSE_COUNT * `BYTE_WIDTH - `BYTE_WIDTH];
                        end else if (ip_routed) begin
                            rx_saved_ipv4_addr <= rx_outbound_counter >= `IPV4_BEGIN - 2 ? (rx_outbound_counter - `IPV4_BEGIN + 2) : 0;
                            if (rx_outbound_counter >= `DST_MAC_BEGIN && rx_outbound_counter < `DST_MAC_END) begin
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_nexthop_mac_addr[`MAC_WIDTH-1:`MAC_WIDTH-`BYTE_WIDTH];
                                rx_nexthop_mac_addr <= rx_nexthop_mac_addr << `BYTE_WIDTH;
                            end else if (rx_outbound_counter >= `SRC_MAC_BEGIN && rx_outbound_counter < `SRC_MAC_END) begin
                                // rx_saved_dst_mac_addr should equal to port_mac
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_saved_dst_mac_addr[`MAC_WIDTH-1:`MAC_WIDTH-`BYTE_WIDTH];
                                rx_saved_dst_mac_addr <= rx_saved_dst_mac_addr << `BYTE_WIDTH;
                            end else if (rx_outbound_counter == `ETHERTYPE_BEGIN) begin
                                // IPv4 Ethertype 0x0800
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= 8'h08;
                            end else if (rx_outbound_counter == `ETHERTYPE_BEGIN + 1) begin
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= 8'h00;
                            end else if (rx_outbound_counter >= `IPV4_TTL_BEGIN && rx_outbound_counter < `IPV4_TTL_END) begin
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_saved_ipv4_ttl - 1;
                            end else if (rx_outbound_counter >= `IPV4_CHECKSUM_BEGIN && rx_outbound_counter < `IPV4_CHECKSUM_END) begin
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_saved_ipv4_checksum[`IPV4_CHECKSUM_COUNT*`BYTE_WIDTH-1:`IPV4_CHECKSUM_COUNT*`BYTE_WIDTH-`BYTE_WIDTH];
                                rx_saved_ipv4_checksum <= rx_saved_ipv4_checksum << `BYTE_WIDTH;
                            end else begin
                                fifo_matrix_rx_wdata[rx_outbound_port_id] <= rx_saved_ipv4_out;
                            end
                        end
                        if (rx_outbound_length == 1) begin
                            fifo_matrix_rx_wlast[rx_outbound_port_id] <= 1;
                        end
                    end else if (fifo_matrix_rx_wlast[rx_outbound_port_id]) begin
                        fifo_matrix_rx_wlast[rx_outbound_port_id] <= 0;
                        fifo_matrix_rx_wvalid[rx_outbound_port_id] <= 0;
                        fifo_matrix_rx_wdata[rx_outbound_port_id] <= 0;
                        rx_outbound <= 0;
                    end
                end
            end
        end
    end

    generate
        if (!shared) begin
            tri_mode_ethernet_mac_0 tri_mode_ethernet_mac_0_inst (
                .gtx_clk(gtx_clk),
                .gtx_clk_out(gtx_clk_out),
                .gtx_clk90_out(gtx_clk90_out),
                .refclk(refclk),

                .glbl_rstn(reset_n),
                .rx_axi_rstn(reset_n),
                .tx_axi_rstn(reset_n),

                .rx_enable(rx_enable),

                .rx_statistics_vector(rx_statistics_vector),
                .rx_statistics_valid(rx_statistics_valid),

                .rx_mac_aclk(rx_mac_aclk),
                .rx_reset(rx_reset),
                .rx_axis_mac_tdata(rx_axis_mac_tdata),
                .rx_axis_mac_tvalid(rx_axis_mac_tvalid),
                .rx_axis_mac_tlast(rx_axis_mac_tlast),
                .rx_axis_mac_tuser(rx_axis_mac_tuser),

                .tx_enable(tx_enable),

                .tx_ifg_delay(8'b00000000),
                .tx_statistics_vector(tx_statistics_vector),
                .tx_statistics_valid(tx_statistics_valid),

                .tx_mac_aclk(tx_mac_aclk),
                .tx_reset(tx_reset),
                .tx_axis_mac_tdata(tx_axis_mac_tdata),
                .tx_axis_mac_tvalid(tx_axis_mac_tvalid),
                .tx_axis_mac_tlast(tx_axis_mac_tlast),
                .tx_axis_mac_tuser(tx_axis_mac_tuser),
                .tx_axis_mac_tready(tx_axis_mac_tready),

                .pause_req(1'b0),
                .pause_val(16'b0),

                .speedis100(speedis100),
                .speedis10100(speedis10100),

                .rgmii_txd(rgmii_td),
                .rgmii_tx_ctl(rgmii_tx_ctl),
                .rgmii_txc(rgmii_txc),
                .rgmii_rxd(rgmii_rd),
                .rgmii_rx_ctl(rgmii_rx_ctl),
                .rgmii_rxc(rgmii_rxc),
                .inband_link_status(link_status),
                .inband_clock_speed(clock_speed),
                .inband_duplex_status(duplex_status),

                // receive 1Gb/s | promiscuous | flow control | fcs | enable
                .rx_configuration_vector(80'b10100000101010),
                // transmit 1Gb/s | enable
                .tx_configuration_vector(80'b10000000000010)
            );
        end else begin
            assign gtx_clk_out = 0;
            assign gtx_clk90_out = 0;
            tri_mode_ethernet_mac_0_shared tri_mode_ethernet_mac_0_shared_inst (
                .gtx_clk(gtx_clk),
                .gtx_clk90(gtx_clk90),

                .glbl_rstn(reset_n),
                .rx_axi_rstn(reset_n),
                .tx_axi_rstn(reset_n),

                .rx_enable(rx_enable),

                .rx_statistics_vector(rx_statistics_vector),
                .rx_statistics_valid(rx_statistics_valid),

                .rx_mac_aclk(rx_mac_aclk),
                .rx_reset(rx_reset),
                .rx_axis_mac_tdata(rx_axis_mac_tdata),
                .rx_axis_mac_tvalid(rx_axis_mac_tvalid),
                .rx_axis_mac_tlast(rx_axis_mac_tlast),
                .rx_axis_mac_tuser(rx_axis_mac_tuser),

                .tx_enable(tx_enable),

                .tx_ifg_delay(8'b00000000),
                .tx_statistics_vector(tx_statistics_vector),
                .tx_statistics_valid(tx_statistics_valid),

                .tx_mac_aclk(tx_mac_aclk),
                .tx_reset(tx_reset),
                .tx_axis_mac_tdata(tx_axis_mac_tdata),
                .tx_axis_mac_tvalid(tx_axis_mac_tvalid),
                .tx_axis_mac_tlast(tx_axis_mac_tlast),
                .tx_axis_mac_tuser(tx_axis_mac_tuser),
                .tx_axis_mac_tready(tx_axis_mac_tready),

                .pause_req(1'b0),
                .pause_val(16'b0),

                .speedis100(speedis100),
                .speedis10100(speedis10100),

                .rgmii_txd(rgmii_td),
                .rgmii_tx_ctl(rgmii_tx_ctl),
                .rgmii_txc(rgmii_txc),
                .rgmii_rxd(rgmii_rd),
                .rgmii_rx_ctl(rgmii_rx_ctl),
                .rgmii_rxc(rgmii_rxc),
                .inband_link_status(link_status),
                .inband_clock_speed(clock_speed),
                .inband_duplex_status(duplex_status),

                // receive 1Gb/s | promiscuous | flow control | fcs | enable
                .rx_configuration_vector(80'b10100000101010),
                // transmit 1Gb/s | enable
                .tx_configuration_vector(80'b10000000000010)
            );
        end
    endgenerate
    
endmodule
