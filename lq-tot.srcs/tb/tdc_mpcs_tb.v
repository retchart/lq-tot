/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_mpcs_tb.v: tdc_fine_tb readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.29
	******************************************************************************
*/

`timescale 1ns / 0.1ps
module tdc_mpcs_tb;

// Parameters
// Input Clock Period
parameter	CLK_FRE = 200; // 200Mhz
parameter	CLK_PERIOD_HALF = 2.5; // nS

// Polarity of hit signals.
parameter   POLARITY_POS        = 1'b0;
parameter   POLARITY_NEG        = 1'b1;

// Time stamp's period (nS).
parameter  TIME_STAMP_PERIOD   = 5;
// Time to avoid invalid events caused by jitter(10ns)
parameter  JITTER_TIME   = 200;

//Differential system clocks
reg  sys_clk;
reg rst_n;

// initialise
// Clock Generation
initial begin
	sys_clk = 1'b1;
end

always #CLK_PERIOD_HALF  begin
	sys_clk = ~sys_clk;
end

// tdc initialise.
reg hit = 0;
reg fifo_rd_en = 0;
reg enable = 1'b1;
reg sync = 1'b0;
initial begin
    hit = 0;
	rst_n = 0;
	# 100
	rst_n = 1;
	# 200
	hit = 1'b1;
	# 100
	hit = 1'b0;
	# 25.3125
	hit = 1'b1;
	# 74.6875
	hit = 1'b0;
	# 125.9375
	hit = 1'b1;
	# 74.0625
	hit = 1'b0;
	# 126.5625
	hit = 1'b1;
	# 73.4375
	hit = 1'b0;
	# 127.1875
	hit = 1'b1;
	# 72.8125
	hit = 1'b0;
	# 127.8125
	hit = 1'b1;
	# 72.1875
	hit = 1'b0;
	# 128.4375
	hit = 1'b1;
	# 71.5625
	hit = 1'b0;
	# 129.0625
	hit = 1'b1;
	# 70.9375
	hit = 1'b0;
	# 129.6875
	hit = 1'b1;
	# 70.3125
	hit = 1'b0;
	# 30.3125
	hit = 1'b1;
	# 69.6875
	hit = 1'b0;
	# 30.9375
	hit = 1'b1;
	# 69.0625
	hit = 1'b0;
	# 31.5625
	hit = 1'b1;
	# 68.4375
	hit = 1'b0;
	# 32.1875
	hit = 1'b1;
	# 67.8125
	hit = 1'b0;
	# 32.8125
	hit = 1'b1;
	# 67.1875
	hit = 1'b0;
	# 33.4375
	hit = 1'b1;
	# 66.5625
	hit = 1'b0;
	# 34.0625
	hit = 1'b1;
	# 65.9375
	hit = 1'b0;
	# 34.6875
	hit = 1'b1;
	# 65.3125
	hit = 1'b0;
	# 35.3125
	hit = 1'b1;
	# 64.6875
	hit = 1'b0;
    // read data in fifo
    # 200
    fifo_rd_en = 1'b1;
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
/*
// Phase counter used to synchrotron the phase of 8 clocks.
reg[7:0] phase_count = 8'b0;
always@(posedge sys_clk)
begin
	phase_count <= phase_count + 1'b1;
end

// buffer the state of each clock.
wire[7:0] q;
wire[7:0] q_n;
assign q[7] = phase_count[0];
assign q_n[7] = ~phase_count[0];
tdc_dff dff7_cnt(
    .clk(clk7), 
    .din(phase_count[0]),
    .q(q[0]),
    .q_n(q_n[0])
);
tdc_dff dff6_cnt(
    .clk(clk6), 
    .din(q_n[0]),
    .q(q[1]),
    .q_n(q_n[1])
);
tdc_dff dff5_cnt(
    .clk(clk5), 
    .din(q_n[1]),
    .q(q[2]),
    .q_n(q_n[2])
);
tdc_dff dff4_cnt(
    .clk(clk4), 
    .din(q_n[2]),
    .q(q[3]),
    .q_n(q_n[3])
);
tdc_dff dff3_cnt(
    .clk(clk3), 
    .din(q_n[3]),
    .q(q[4]),
    .q_n(q_n[4])
);
tdc_dff dff2_cnt(
    .clk(clk2), 
    .din(q_n[4]),
    .q(q[5]),
    .q_n(q_n[5])
);
tdc_dff dff1_cnt(
    .clk(clk1), 
    .din(q_n[5]),
    .q(q[6]),
    .q_n(q_n[6])
);
*/
wire[7:0] fifo_dout;
wire[5:0] fifo_data_count;
tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(5nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY_NEG)                 // Polarity of hit.
) tdc_mpcs_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.enable(enable),         // High valid.
    .sync(sync),           // sychronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),

	.hit(hit),            // Input pulse.
    .number(8'd1),

    .fifo_busy(fifo_busy),      // busy indicator.
    .fifo_rd_en(fifo_rd_en),     // fifo read enable.
    .fifo_dout(fifo_dout),      // fifo data output.
    .fifo_data_count(fifo_data_count) // fifo data counts.  
);

endmodule
