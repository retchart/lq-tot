/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * idelay.v: delay some time for the selected io.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/
`timescale 1ns / 1ps

module idelay
#(
	parameter CLK_FRE = 200        	//clock frequency(Mhz)
)
(
    input                   ref_clk,
    input                   rst_n,
    input[4:0]              delay_tap,

    input                   io,
    output                  io_delay
    );

// IDELAYCTRL module
IDELAYCTRL IDELAYCTRL_inst (
  	.RDY(1'b1),       // 1-bit output: Ready output
  	.REFCLK(ref_clk),// 1-bit input: Reference clock input
  	.RST(~rst_n)        // 1-bit input: Active high reset input
);

wire[4:0] tap_value_out;
// delay frame
IDELAYE2 #(
  	.CINVCTRL_SEL("FALSE"),          // Enable dynamic clock inversion (FALSE, TRUE)
  	.DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
  	.HIGH_PERFORMANCE_MODE("FALSE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
  	.IDELAY_TYPE("VAR_LOAD"),        // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  	.IDELAY_VALUE(0),                // Input delay tap setting (0-31)
  	.PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
  	.REFCLK_FREQUENCY(200.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  	.SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
)
IDELAYE2_inst (
  	.CNTVALUEOUT(tap_value_out),// 5-bit output: Counter value output
  	.DATAOUT(io_delay),	  // 1-bit output: Delayed data output
  	.C(ref_clk),	              // 1-bit input: Clock input
  	.CE(1'b0),                 	  // 1-bit input: Active high enable increment/decrement input
  	.CINVCTRL(1'b0),           	  // 1-bit input: Dynamic clock inversion input
  	.CNTVALUEIN(delay_tap),  	  // 5-bit input: Counter value input
  	.DATAIN(1'b0),         	   	  // 1-bit input: Internal delay data input
  	.IDATAIN(io),    	          // 1-bit input: Data input from the I/O
  	.INC(1'b0),                	  // 1-bit input: Increment / Decrement tap delay input
  	.LD(1'b1),                    // 1-bit input: Load IDELAY_VALUE input
  	.LDPIPEEN(1'b0),           	  // 1-bit input: Enable PIPELINE register to load data input
  	.REGRST(1'b0)              	  // 1-bit input: Active-high reset tap-delay input
);

endmodule
