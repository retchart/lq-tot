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

`timescale 1ns / 1ps
module tb_idelay();

	// Test signals
	reg 			ref_clk 		;
	reg 			rst 			;
	wire 			rdy 			;
	reg [11:0]		rx_data_buf		;
	reg 			rx_frame_buf	;

	wire [11:0]		rx_data_delay	;
	wire 			rx_frame_delay	;
	reg [4:0]		delay_value 	;
	reg  [12:0]		delay_load_en	;
	wire [4:0]		mon_delay_frame ;
	wire [4:0]		mon_delay_data	;

	//generate clock 200M 
	initial begin
        ref_clk = 0;
        forever #(2.5) ref_clk = ~ref_clk;
    end
	
	// generate source data and frame
    initial begin 
    	rst = 1;
    	rx_frame_buf = 0;
    	rx_data_buf = 0;
    	repeat(50)@(posedge ref_clk);
    	rst = 0;
    	repeat(100)@(posedge ref_clk);
    	gen_test_data;
    end
	
	// generate delay value and load signal
    initial begin 
    	delay_load_en = 1'b0;
    	delay_value = 5'd0;
    	@(negedge rx_frame_buf);
    	@(negedge ref_clk);
    	delay_value = 5'd16;
    	delay_load_en =  {13{1'b1}};
    	@(negedge ref_clk);
    	delay_load_en = {13{1'b0}};
    	delay_value = 5'd0;

    	@(negedge rx_frame_buf);
    	@(negedge ref_clk);
    	delay_value = 5'd31;
    	delay_load_en =  {13{1'b1}};
    	@(negedge ref_clk);
    	delay_load_en = {13{1'b1}};
    	delay_value = 5'd31;
    end

    task gen_test_data();
    	integer k,j; begin 
    		for (k = 0; k < 3; k = k + 1) begin
    			rx_frame_buf  = 1'b1;
    			for (j = 0; j < 512; j = j + 1) begin
    				rx_data_buf = j[11:0];
    				@(posedge ref_clk);
    			end
    			rx_frame_buf = 1'b0;
    			repeat(50)@(posedge ref_clk); 
    		end
    	end
    endtask 


genvar i;

// IDELAYCTRL module
IDELAYCTRL IDELAYCTRL_inst (
  	.RDY(rdy),       // 1-bit output: Ready output
  	.REFCLK(ref_clk),// 1-bit input: Reference clock input
  	.RST(rst)        // 1-bit input: Active high reset input
);
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
IDELAYE2_inst_frame_delay (
  	.CNTVALUEOUT(mon_delay_frame),// 5-bit output: Counter value output
  	.DATAOUT(rx_frame_delay),	  // 1-bit output: Delayed data output
  	.C(ref_clk),	              // 1-bit input: Clock input
  	.CE(1'b0),                 	  // 1-bit input: Active high enable increment/decrement input
  	.CINVCTRL(1'b0),           	  // 1-bit input: Dynamic clock inversion input
  	.CNTVALUEIN(delay_value),  	  // 5-bit input: Counter value input
  	.DATAIN(1'b0),         	   	  // 1-bit input: Internal delay data input
  	.IDATAIN(rx_frame_buf),    	  // 1-bit input: Data input from the I/O
  	.INC(1'b0),                	  // 1-bit input: Increment / Decrement tap delay input
  	.LD(1'b1),       // 1-bit input: Load IDELAY_VALUE input
  	.LDPIPEEN(1'b0),           	  // 1-bit input: Enable PIPELINE register to load data input
  	.REGRST(1'b0)              	  // 1-bit input: Active-high reset tap-delay input
);

//delay data
generate
	for (i = 0; i < 12; i = i + 1)
	begin:data_delay
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
		IDELAYE2_inst_data_delay (
		  	.CNTVALUEOUT(mon_delay_data),// 5-bit output: Counter value output
		  	.DATAOUT(rx_data_delay[i]),	 // 1-bit output: Delayed data output
		  	.C(ref_clk),	             // 1-bit input: Clock input
		  	.CE(1'b0),               	 // 1-bit input: Active high enable increment/decrement input
		  	.CINVCTRL(1'b0),         	 // 1-bit input: Dynamic clock inversion input
		  	.CNTVALUEIN(delay_value),	 // 5-bit input: Counter value input
		  	.DATAIN(1'b0),         	 	 // 1-bit input: Internal delay data input
		  	.IDATAIN(rx_data_buf[i]),	 // 1-bit input: Data input from the I/O
		  	.INC(1'b0),              	 // 1-bit input: Increment / Decrement tap delay input
		  	.LD(delay_load_en[i]),       // 1-bit input: Load IDELAY_VALUE input
		  	.LDPIPEEN(1'b0),         	 // 1-bit input: Enable PIPELINE register to load data input
		  	.REGRST(1'b0)            	 // 1-bit input: Active-high reset tap-delay input
		);
	end
endgenerate


endmodule
