/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * position_store_tb.v: position_store readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/
`timescale 1ns / 100ps
module position_store_tb;

localparam               CLK_FRE = 200;
localparam               TIME_STAMP_PERIOD = 5;

// system
reg             sys_clk;
reg             rst_n;
reg             enable;
reg             sync;
reg[3:0]        mode;

reg             store_wr_req_A;
reg[7:0]        trigger_ch_A;
reg[7:0]        trigger_data_A;
reg             store_wr_req_B;
reg[7:0]        trigger_ch_B;
reg[7:0]        trigger_data_B;

reg				position_valid;
reg[31:0]		position_A;
reg[31:0]		position_B;

reg 			store_rd_req;
reg				store_rd_en;
wire[7:0]		store_dout;
wire			store_full;
wire			store_empty;
wire[10:0]		store_data_cnt;

// initialise
// Clock Generation
initial begin
	sys_clk = 1'b0;
end

always #2.5  begin
	sys_clk = ~sys_clk;
end

// ide1162 related initialise
initial begin
	rst_n = 1;

    enable = 1;
    sync = 0;
    mode = 1;

	store_wr_req_A = 0;
	trigger_ch_A = 1;
	trigger_data_A = 64;
	store_wr_req_B = 0;
	trigger_ch_B = 2;
	trigger_data_B = 128;

    position_valid = 0;
    position_A = 1;
    position_B = 2;

    store_rd_req = 0;
    store_rd_en = 0;

	# 100
	rst_n = 0;
	# 100
	rst_n = 1;

	# 1000
	trigger_ch_A = 1;
	trigger_data_A = 64;
	store_wr_req_A = 1;
	# 10
    store_wr_req_A = 0;
	# 1000
	trigger_ch_B = 2;
	trigger_data_B = 128;
	store_wr_req_B = 1;
	# 10
    store_wr_req_B = 0;
	# 1000
	store_rd_req = 1;
	# 10
	store_rd_req = 0;
    store_rd_en = 1;
    # 100
    store_rd_en = 0;
    # 400000
    mode = 0;
end

position_store
#(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(uS)
) position_store_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

    .enable(enable),
    .sync(sync),                            // synchronization
    .sync_out(sync_out),                    // internal synchronization output
    .mode(mode),                            // 0 - position mode; 1 - list mode.

	.store_wr_req_A(store_wr_req_A),           // position write request.
    .store_wr_ack_A(store_wr_ack_A),           // fifo write complete ack.
    .trigger_ch_A(trigger_ch_A),                // list mode: trigger wire; 
    .trigger_data_A(trigger_data_A),           // list mode: pulse width
	.store_wr_req_B(store_wr_req_B),           // position write request.
    .store_wr_ack_B(store_wr_ack_B),           // fifo write complete ack.
    .trigger_ch_B(trigger_ch_B),             // list mode: trigger wire; 
    .trigger_data_B(trigger_data_B),          // list mode: pulse width

	.position_valid(position_valid),
	.position_A(position_A),
	.position_B(position_B),

    .store_rd_req(store_rd_req),        // fifo read request.
    .store_rd_ack(store_rd_ack),        // fifo read ack.
	.store_rd_en(store_rd_en),         // fifo read enable.
	.store_dout(store_dout),          // fifo dout.
	.store_full(store_full),          // fifo full.
	.store_empty(store_empty),         // fifo empty.
	.store_data_cnt(store_data_cnt)       // fifo counts.
	);

endmodule
