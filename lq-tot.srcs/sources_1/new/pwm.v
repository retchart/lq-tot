/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * pwm.v: .
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/

module pwm
#(
	parameter CLK_FRE         = 200,        		//clock frequency(Mhz)
	parameter PWM_PERIOD      = 16'd1024	// pwm period.
)
(
	input				sys_clk,
	input				rst_n,

	input[15:0]			width,
	output reg			pwm
	);

// Set up the PWM
reg[15:0] pwm_cnt =16'd0;
always@(posedge sys_clk)
begin
	begin
		if(pwm_cnt < PWM_PERIOD) begin
			pwm_cnt <= pwm_cnt + 1'b1;
		end
		else begin
			pwm_cnt <= 16'd0;
		end
	end
end

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		pwm <= 1'b0;
	end
	else begin
		if(pwm_cnt < width) begin
			pwm <= 1'b1;
		end
		else begin
			pwm <= 1'b0;
		end
	end
end

// analyze trigger
endmodule
