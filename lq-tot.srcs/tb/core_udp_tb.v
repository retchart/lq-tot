/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * position_position_tb.v: position_position readout and test.
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

// system
reg sys_clk;
reg rst_n;

reg[3:0] rgmii_rxd;
reg rgmii_rxc;
reg rgmii_rxctrl;

// position_position
reg trigger_wr_req_A;      // position write request.
reg[7:0] trigger_wr_req_ch_A;      // list mode: trigger wire; 
reg[7:0] trigger_width_A;          // list mode: pulse width
reg trigger_wr_req_B;      // position write request.
reg[7:0] trigger_wr_req_ch_B;      // list mode: trigger wire; 
reg[7:0] trigger_width_B;          // list mode: pulse width
reg				position_valid;
reg[31:0]		position_A;
reg[31:0]		position_B;

wire[7:0]		store_dout;
wire			store_full;
wire			store_empty;
wire[10:0]		store_data_cnt;

// uart


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

// ide1162 related initialise
initial begin
	rst_n = 1;
	rst_n = 0;
	position_A = 0;
	position_B = 0;
	position_valid = 0;
	# 200
	rst_n = 1;
    /*
	# 1500
	position_A = 2;
	position_B = 4;
	position_valid = 1;
	# 5
	position_valid = 0;
	# 1500
	position_A = 3;
	position_B = 7;
	position_valid = 1;
	# 5
	position_valid = 0;
	# 1500
	position_A = 31;
	position_B = 63;
	position_valid = 1;
	# 5
	position_valid = 0;
	# 1500
	position_A = 63;
	position_B = 31;
	position_valid = 1;
	# 5
	position_valid = 0;
    */
end

// signal
always #(2000)  begin
	# 1500
	position_A = 2;
	//position_B = 4;
	position_valid = 1;
	# 5
	position_valid = 0;
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
// wire[7:0]			store_dout;
// wire[10:0]   		store_data_cnt;
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



// negedge of coincidence means position valid.
// wire position_valid;
// assign position_valid = ~coin;
// wire[10:0] store_data_cnt;
position_store
#(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) position_store_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

    .enable(enable),                        // High valid.
    .sync(sync),                            // synchronization.
    .sync_out(sync_internal),                    // synchronization.
    .mode(s_mode[3:0]),                     // 0 - position mode; 1 - list mode.

	.store_wr_req_A(store_wr_req_A),            // position write request.
    .store_wr_ack_A(store_wr_ack_A),            // fifo write complete ack.
    .trigger_ch_A(trigger_ch_A),                // list mode: trigger wire; 
    .trigger_data_A(trigger_data_A),          // list mode: pulse width
	.store_wr_req_B(store_wr_req_B),            // position write request.
    .store_wr_ack_B(store_wr_ack_B),            // fifo write complete ack.
    .trigger_ch_B(trigger_ch_B),                // list mode: trigger wire; 
    .trigger_data_B(trigger_data_B),          // list mode: pulse width
	
	.position_valid(position_valid),
	.position_A(position_A),                // position mode: 32bit position of chA.
	.position_B(position_B),                // position mode: 32bit position of chB.

	.store_busy(store_busy),          // fifo write busy flag.
	.store_rd_en(store_rd_en),        // fifo read enable.
	.store_dout(store_dout),          // fifo dout.
	.store_full(store_full),          // fifo full.
	.store_empty(store_empty),        // fifo empty.
	.store_data_cnt(store_data_cnt)   // fifo counts.
	);

endmodule
