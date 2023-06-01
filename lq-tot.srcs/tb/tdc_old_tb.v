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

`timescale 1ns / 1ps
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
	hit = 1'b0;
	# 100
	hit = 1'b1;
	# 100
	hit = 1'b0;
	# 100
	hit = 1'b1;
	# 3.125
	hit = 1'b0;
	# 100
	hit = 1'b1;
	# 24.365
	hit = 1'b0;
	# 100
	hit = 1'b1;
	# 24.365
	hit = 1'b0;
end

wire[11:0] tdc_value_coarse;
tdc_coarse tdc_coarse_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hit),                      // Input pulse.
	.tdc_value(tdc_value_coarse)    // The converted time.
);

wire[2:0] tdc_value_fine;
tdc_fine tdc_fine_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hit),                     // Input pulse.
	.tdc_value(tdc_value_fine)      // The converted time.
);

endmodule
