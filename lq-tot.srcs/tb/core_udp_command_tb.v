/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * core_udp_command_tb.v: Testbench to receive command from ethernet.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/
`timescale 1ns / 100ps
module core_udp_tb;

//***************************************************************************
parameter RST_ACT_LOW           = 1;
                                  // =1 for active low reset,
                                  // =0 for active high.
//***************************************************************************
parameter CLKIN_PERIOD          = 5;
                                  // Input Clock Period
parameter ETH_CLKIN_PERIOD      = 8;
                                  // Input Clock Period

localparam               CLK_FRE = 200;
localparam               TIME_STAMP_PERIOD = 10;

// Ethernet related parameters.
localparam LOCAL_IP_ADDR    = 32'hc0a80002     ;
localparam LOCAL_MAC_ADDR   = 48'h000a3501fec0 ;
localparam DST_MAC_ADDR     = 48'hffffffffffff ;
localparam DST_IP_ADDR      = 32'hc0a80003     ;
localparam UDP_LOCAL_PORT   = 16'h1f90         ;
localparam UDP_DST_PORT     = 16'h1f90         ;
localparam TTL              = 8'h80            ;

localparam TYPE_IP          = 16'h0800;
localparam VERSION_HEADER_LENGTH    = 8'h45;
localparam TYPE_OF_SERVICE  = 8'h00;
localparam FLAG_OFFSET      = 16'h4000;
localparam PROTOCAL_ICMP    = 8'h1;
localparam PROTOCAL_UDP     = 8'h11;

// system
reg sys_clk;
reg rst_n;

reg[3:0] rgmii_rxd;
reg rgmii_rxc;
reg rgmii_rxctrl;

// ethernet
reg[7:0]        eth_header[49:0];
reg[7:0]        eth_checksum[31:0];
reg[15:0]       ip_length;
reg[15:0]       header_checksum;
reg[15:0]       udp_length;
reg[15:0]       udp_checksum;
reg[31:0]       checksum;

// settings.
reg[15:0]       rx_s_name;
reg[31:0]       rx_s_ip;
reg[7:0]        rx_s_mode;
reg[7:0]        rx_s_channel;
reg[15:0]       rx_s_hv;
reg[15:0]       rx_s_althd;
reg[15:0]       rx_s_clthd;
reg[7:0]        rx_s_jitter_time;
reg[7:0]        rx_s_coin_time;
reg[7:0] 		rx_cmd_start[7:0];
reg[7:0] 		rx_cmd_stop[7:0];
reg[7:0] 		rx_cmd_settings[23:0];

// uart
reg[15:0]       rx_command_lenth;
reg[15:0]       rx_command_data_length;
reg[15:0]       identify_code;

// initialise
// Clock Generation
initial begin
	sys_clk = 1'b0;
end

always #(CLKIN_PERIOD/2.0)  begin
	sys_clk = ~sys_clk;
end

// ethernet clock.
initial begin
  rgmii_rxc = 1'b0;
end

always #(ETH_CLKIN_PERIOD/2.0) begin
  rgmii_rxc = ~rgmii_rxc;
end

// Initialise
// All the checksum are from one capture.
initial begin
	rst_n = 1;
    rx_s_name = {8'h30, 8'h30};
    rx_s_ip = 32'hC0A80002;
    rx_s_mode = 8'h10;
    rx_s_channel = 8'h00;        
	rx_s_hv = 16'h044C;
    rx_s_althd = 16'h01A1;
    rx_s_clthd = 16'h01B9;
    rx_s_jitter_time = 8'h09;
	rx_s_coin_time = 8'h09;
    rx_command_data_length = 16'd16;
    rx_command_lenth = rx_command_data_length + 16'd8;
    udp_length = rx_command_lenth + 8'd8;  // udp header has 8 bytes.
    ip_length = udp_length + 8'd20; // ip header has 8 bytes.
    identify_code = 16'h581d; // from one capture.
    header_checksum = 16'd6146; // from one capture.
    udp_checksum = 16'hfb90;
    checksum = 32'h9634977e;
    eth_header[0] = 8'h55;
    eth_header[1] = 8'h55;
    eth_header[2] = 8'h55;
    eth_header[3] = 8'h55;
    eth_header[4] = 8'h55;
    eth_header[5] = 8'h55;
    eth_header[6] = 8'h55;
    eth_header[7] = 8'hd5;
    eth_header[8]  = LOCAL_MAC_ADDR[47:40];
    eth_header[9]  = LOCAL_MAC_ADDR[39:32];
    eth_header[10] = LOCAL_MAC_ADDR[31:24];
    eth_header[11] = LOCAL_MAC_ADDR[23:16];
    eth_header[12] = LOCAL_MAC_ADDR[15:8];
    eth_header[13] = LOCAL_MAC_ADDR[7:0];
    eth_header[14] = DST_MAC_ADDR[47:40];
    eth_header[15] = DST_MAC_ADDR[39:32];
    eth_header[16] = DST_MAC_ADDR[31:24];
    eth_header[17] = DST_MAC_ADDR[23:16];
    eth_header[18] = DST_MAC_ADDR[15:8];
    eth_header[19] = DST_MAC_ADDR[7:0];
    eth_header[20] = TYPE_IP[15:8];
    eth_header[21] = TYPE_IP[7:0];
    eth_header[22] = VERSION_HEADER_LENGTH;
    eth_header[23] = TYPE_OF_SERVICE;
    eth_header[24] = ip_length[15:8];
    eth_header[25] = ip_length[7:0];
    eth_header[26] = identify_code[15:8];
    eth_header[27] = identify_code[7:0];
    eth_header[28] = FLAG_OFFSET[15:8];
    eth_header[29] = FLAG_OFFSET[7:0];
    eth_header[30] = TTL;
    eth_header[31] = PROTOCAL_UDP;
    eth_header[32] = header_checksum[15:8];
    eth_header[33] = header_checksum[7:0];
    eth_header[34] = DST_IP_ADDR[31:24];
    eth_header[35] = DST_IP_ADDR[23:16];
    eth_header[36] = DST_IP_ADDR[15:8];
    eth_header[37] = DST_IP_ADDR[7:0];
    eth_header[38] = LOCAL_IP_ADDR[31:24];
    eth_header[39] = LOCAL_IP_ADDR[23:16];
    eth_header[40] = LOCAL_IP_ADDR[15:8];
    eth_header[41] = LOCAL_IP_ADDR[7:0];
    eth_header[42] = UDP_DST_PORT[15:8];
    eth_header[43] = UDP_DST_PORT[7:0];
    eth_header[44] = UDP_LOCAL_PORT[15:8];
    eth_header[45] = UDP_LOCAL_PORT[7:0];
    eth_header[46] = udp_length[15:8];
    eth_header[47] = udp_length[7:0];
    eth_header[48] = udp_checksum[15:8];
    eth_header[49] = udp_checksum[7:0];
    eth_checksum[0] = checksum[31:24];
    eth_checksum[1] = checksum[23:16];
    eth_checksum[2] = checksum[15:8];
    eth_checksum[3] = checksum[7:0];
	rx_cmd_settings[0] = 8'h24;
	rx_cmd_settings[1] = 8'h00;
	rx_cmd_settings[2] = 8'h01;
	rx_cmd_settings[3] = 8'h03;
	rx_cmd_settings[4] = rx_command_data_length[15:8];
	rx_cmd_settings[5] = rx_command_data_length[7:0];
	rx_cmd_settings[6] = rx_s_name[15:8];
	rx_cmd_settings[7] = rx_s_name[7:0];
	rx_cmd_settings[8] = rx_s_ip[31:24];
	rx_cmd_settings[9] = rx_s_ip[23:16];
	rx_cmd_settings[10] = rx_s_ip[15:8];
	rx_cmd_settings[11] = rx_s_ip[7:0];
	rx_cmd_settings[12] = rx_s_mode;
	rx_cmd_settings[13] = rx_s_channel;
	rx_cmd_settings[14] = rx_s_hv[15:8];
	rx_cmd_settings[15] = rx_s_hv[7:0];
	rx_cmd_settings[16] = rx_s_althd[15:8];
	rx_cmd_settings[17] = rx_s_althd[7:0];
	rx_cmd_settings[18] = rx_s_clthd[15:8];
	rx_cmd_settings[19] = rx_s_clthd[7:0];
	rx_cmd_settings[20] = rx_s_jitter_time;
	rx_cmd_settings[21] = rx_s_coin_time;
	rx_cmd_settings[22] = 8'h0d;
	rx_cmd_settings[23] = 8'h0a;
	# 200
	rst_n = 0;
	# 200
	rst_n = 1;
    
end

// GMII to RGMII.
wire gmii_rx_clk;
wire[7:0] gmii_txd;
wire gmii_tx_en;
wire gmii_tx_clk;
wire gmii_crs;
wire gmii_col;
wire[7:0] gmii_rxd;
wire gmii_rxc;
wire gmii_rx_dv;
wire gmii_rx_er;
wire[1:0] speed_selection;
wire duplex_mode;
util_gmii_to_rgmii util_gmii_to_rgmii_m0(
    .reset(1'b0),
    
    .rgmii_td(rgmii_txd),
    .rgmii_tx_ctl(rgmii_txctrl),
    .rgmii_txc(rgmii_txc),
    .rgmii_rd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rxctrl),

    .gmii_rx_clk(gmii_rx_clk),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(1'b0),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_crs(gmii_crs),
    .gmii_col(gmii_col),
    .gmii_rxd(gmii_rxd),
    .rgmii_rxc(rgmii_rxc),//add
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .speed_selection(speed_selection),
    .duplex_mode(duplex_mode)
);

//MDIO config
assign speed_selection = 2'b10;
assign duplex_mode = 1'b1;
miim_top miim_top_m0(
    .reset_i            (1'b0),
    .miim_clock_i       (gmii_tx_clk),
    .mdc_o              (e_mdc),
    .mdio_io            (e_mdio),
    .link_up_o          (),                  //link status
    .speed_o            (),                  //link speed
    .speed_override_i   (2'b11)              //11: autonegoation
); 

// modbus_udp
wire[7:0] rx_fifo_dout;
wire[10:0] rx_fifo_cnt;
wire[7:0] tx_fifo_din;

modbus_udp#
(
	.CLK_FRE(CLK_FRE)
) modbus_udp_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.gmii_rx_clk(gmii_rx_clk),
    .gmii_tx_clk(gmii_tx_clk),

    .gmii_tx_en(gmii_tx_en),
    .gmii_txd(gmii_txd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rxd(gmii_rxd),

    .rx_frame_valid(rx_frame_valid),
    .rx_fifo_dout(rx_fifo_dout),
    .rx_fifo_rd_en(rx_fifo_rd_en),
    .rx_fifo_cnt(rx_fifo_cnt),

    .tx_frame_valid(tx_frame_valid),
    .tx_fifo_din(tx_fifo_din),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_full(tx_fifo_full)
);

// Core.
localparam			PHS_CHANNELS = 1024;
wire[7:0]			rx_dout;
wire[10:0]			rx_data_cnt;
wire[15:0]			s_name;
wire[31:0]			s_ip;
wire[7:0]			s_mode;
wire[7:0]			s_channel;
wire[15:0]			s_hv;
wire[15:0]			s_althd;
wire[15:0]			s_clthd;
wire[7:0]			s_jitter_time;
wire[7:0]			s_coin_time;
wire[7:0]			store_dout;
wire[10:0]   		store_data_cnt;
wire[9:0]			phs_rd_addr;
wire[31:0]			phs_out;

core_udp #
(
	.CLK_FRE(CLK_FRE),        //clock frequency(Mhz)
	.PHS_CHANNELS(PHS_CHANNELS)
) core_udp_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.rx_frame_valid(rx_frame_valid),
	.rx_fifo_dout(rx_fifo_dout),
    .rx_fifo_rd_en(rx_fifo_rd_en),
    .rx_fifo_cnt(rx_fifo_cnt),

	.tx_frame_valid(tx_frame_valid),
    .tx_fifo_din(tx_fifo_din),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_full(tx_fifo_full),

	.s_name(s_name),
	.s_ip(s_ip),
	.s_mode(s_mode),
	.s_channel(s_channel),
	.s_hv(s_hv),
	.s_althd(s_althd),
	.s_clthd(s_clthd),
	.s_jitter_time(s_jitter_time),
	.s_coin_time(s_coin_time),

	.enable(enable),

	.store_busy(store_busy),
	.store_rd_en(store_rd_en),
	.store_dout(store_dout),
	.store_full(store_full),
	.store_empty(store_empty),
	.store_data_cnt(store_data_cnt),

	.phs_rd_req(phs_rd_req),
	.phs_rd_addr(phs_rd_addr),
	.phs_rd_busy(phs_rd_busy),
	.phs_out(phs_out)
	);

position_store
#(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(uS)
) position_store_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.position_valid(position_valid),
	.position_A(position_A),
	.position_B(position_B),

	.store_busy(store_busy),
	.store_rd_en(store_rd_en),
	.store_dout(store_dout),
	.store_full(store_full),
	.store_empty(store_empty),
	.store_data_cnt(store_data_cnt)
	);


endmodule
