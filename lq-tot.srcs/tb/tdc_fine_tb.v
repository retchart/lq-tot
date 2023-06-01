/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_fine_tb.v: tdc_fine_tb readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.29
	******************************************************************************
*/

`timescale 1ns / 100ps
module trigger_tb;

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
	sys_clk = 1'b0;
end

always #CLK_PERIOD_HALF  begin
	sys_clk = ~sys_clk;
end

// tdc initialise.
initial begin
	rst_n = 1;
	# 200
	rst_n = 0;
	# 200
	rst_n = 1;
	# 50
	enable = 1'b1;
    gate_buf = 1'b1;
	# 100
	din_A = 32'h00000000;
	din_B = ~32'h00000000;
end

tdc_fine tdc_fine_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hist),            // Input pulse.
	.tdc_value(tdc_value)       // The converted time.
);