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
module tdc_tb;

// Parameters
// Input Clock Period
parameter	CLK_FRE = 200; // 200Mhz
parameter	CLK_PERIOD_HALF = 2.5; // nS

// Time stamp's period (nS).
localparam  TIME_STAMP_PERIOD   = 5;

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
reg hit;
initial begin
	rst_n = 1;
    hit = 0;
	rst_n = 0;
	# 100
	rst_n = 1;
	# 100
	hit = 1'b1;
	# 100
	hit = 1'b0;
	# 100
	hit = 1'b1;
	# 100
	hit = 1'b0;
	# 25.3125
	hit = 1'b1;
	# 74.6875
	hit = 1'b0;
	# 25.9375
	hit = 1'b1;
	# 74.0625
	hit = 1'b0;
	# 26.5625
	hit = 1'b1;
	# 73.4375
	hit = 1'b0;
	# 27.1875
	hit = 1'b1;
	# 72.8125
	hit = 1'b0;
	# 27.8125
	hit = 1'b1;
	# 72.1875
	hit = 1'b0;
	# 28.4375
	hit = 1'b1;
	# 71.5625
	hit = 1'b0;
	# 29.0625
	hit = 1'b1;
	# 70.9375
	hit = 1'b0;
	# 29.6875
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
end

wire busy_coarse;
wire[11:0] tdc_value_coarse;
tdc_coarse tdc_coarse_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hit),                      // Input pulse.
    .busy(busy_coarse),
	.tdc_value(tdc_value_coarse)    // The converted time.
);

wire busy_fine;
wire[2:0] tdc_value_fine;
tdc_fine tdc_fine_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hit),            // Input pulse.
    .busy(busy_fine),
	.tdc_value(tdc_value_fine)       // The converted time.
);

endmodule
