/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * ide1162.v: ide1162 readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/

`timescale 1ns / 100ps
module trigger_tb;

// Parameters
// Input Clock Period
parameter	CLKIN_PERIOD = 5; // nS
parameter	CLK_FRE = 200; // 200Mhz

// Time stamp's period (nS).
localparam  TIME_STAMP_PERIOD   = 5;

//Differential system clocks
reg  sys_clk;
reg rst_n;

// trigger related io
reg enable;
reg gate_buf;
reg[31:0] din_A;
reg[31:0] din_B;
reg[7:0] s_mode;
reg[7:0] s_jitter_time;

reg store_rd_req;
reg store_rd_en;
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
	rst_n = 0;
	enable = 1'b0;
	din_A = 32'h0000;
	din_B = ~32'h000000;
    s_mode = 8'h01;
	s_jitter_time = 8'd9;
    store_rd_req = 1'b0;
    store_rd_en = 1'b0;
	# 200
	rst_n = 1;
	# 100
	enable = 1'b1;
    gate_buf = 1'b1;
	# 100
	din_A = 32'h00000000;
	din_B = ~32'h00000000;
	# 200
	din_A = 32'h0001;
	din_B = ~32'h0002;
	# 100
	din_A = 32'h0000;
	din_B = ~32'h0000;
	# 1000
	din_A = 32'h0003;
	# 10
	din_B = ~32'h0004;
	# 1000
	din_A = 32'h0000;
	din_B = ~32'h0000;
	# 100
	din_A = 32'h0007;
	# 10
	din_B = 32'h070000;
	# 100
	din_A = 32'h0000;
	# 10
	din_B = 32'h000000;
	# 2000
	# 100
	din_A = 32'h0001;
	# 10
	din_B = 32'h010000;
	# 100
	din_A = 32'h0008;
	# 10
	din_B = 32'h080000;
	# 100
	din_A = 32'h0006;
	# 10
	din_B = 32'h060000;
	# 100
	din_A = 32'h0000;
	# 10
	din_B = 32'h000000;
end


// Generate 7 clock for every 45 degree.
wire clk1;
wire clk2;
wire clk3;
wire clk4;
wire clk5;
wire clk6;
wire clk7;
clk_phase_7 clk_mp_inst
(
    // Clock out ports
    .clk_out1(clk1),
    .clk_out2(clk2),
    .clk_out3(clk3),
    .clk_out4(clk4),
    .clk_out5(clk5),
    .clk_out6(clk6),
    .clk_out7(clk7),

    // Status and control signals
    .reset(~rst_n),

    // Clock in ports
    .clk_in1(sys_clk)
);

// The 32 anode channels.
wire[7:0] store_data_A;
trigger
#(
	.CLK_FRE(CLK_FRE),                      //clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(5nS)
) triggerA
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),

	.enable(enable),                    // High valid.
    .sync(sync_buf),               // synchronization.
    .mode(s_mode[3:0]),                 // 0 - position mode; 1 - list mode.

	.din(din_A),                        // trigger wires.
    .number_shift(3'b000),
	.jitter_time(s_jitter_time),        // jitter time along one event.

    .store_wr_req(store_wr_req_A),      // store fifo write enable.
    .store_wr_ack(store_wr_ack_A),        // store fifo write compelete ack.
    .store_data(store_data_A),           // list mode: pulse width
	.store_wr_en(store_wr_en_A)            // fifo write enable.
	);

// The 32 cathode channels.

wire[7:0] store_data_B;
trigger
#(
	.CLK_FRE(CLK_FRE),                      //clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) triggerB
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),

	.enable(enable),         // High valid.
    .sync(sync_buf),               // synchronization.
    .mode(s_mode[3:0]),                 // 0 - position mode; 1 - list mode.
	
    .din(~din_B),                        // trigger wires.
    .number_shift(3'b001),
	.jitter_time(s_jitter_time),        // jitter time along one event.

    .store_wr_req(store_wr_req_B),      // store fifo write enable.
    .store_wr_ack(store_wr_ack_B),        // store fifo write compelete ack.
    .store_data(store_data_B),           // list mode: pulse width
	.store_wr_en(store_wr_en_B)            // fifo write enable.
	);

// Store fifo 
reg store_wr_req_pos = 1'b0;
reg[7:0] store_data_pos = 8'h0;
reg store_wr_en_pos = 1'b0;
wire[10:0] store_data_cnt;
position_store
#(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) position_store_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

    .enable(enable),             // High valid.
    .mode(s_mode[3:0]),                     // 0 - position mode; 1 - list mode.

	.store_wr_req_A(store_wr_req_A),            // position write request.
    .store_wr_ack_A(store_wr_ack_A),            // fifo write complete ack.
    .store_data_A(store_data_A),                // list mode: trigger wire; 
    .store_wr_en_A(store_wr_en_A),              // list mode: pulse width
	.store_wr_req_B(store_wr_req_B),            // position write request.
    .store_wr_ack_B(store_wr_ack_B),            // fifo write complete ack.
    .store_data_B(store_data_B),                // list mode: trigger wire; 
    .store_wr_en_B(store_wr_en_B),              // list mode: pulse width

	.store_wr_req_pos(store_wr_req_pos),        // position write request.
    .store_wr_ack_pos(store_wr_ack_pos),        // fifo write complete ack.
    .store_data_pos(store_data_pos),            // list mode: pulse width
	.store_wr_en_pos(store_wr_en_pos),          // fifo write enable.

	.store_rd_req(store_rd_req),            // fifo read request.
    .store_rd_ack(store_rd_ack),            // fifo read ack.
	.store_rd_en(store_rd_en),              // fifo read enable.
	.store_dout(store_dout),                // fifo dout.
	.store_full(store_full),                // fifo full.
	.store_empty(store_empty),              // fifo empty.
	.store_data_cnt(store_data_cnt)         // fifo counts.
	);

endmodule
