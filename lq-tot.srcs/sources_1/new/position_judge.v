/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * position_judge.v: position_judge readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/

module position_judge
#(
	parameter CLK_FRE = 200         //clock frequency(Mhz)
)
(
	input sys_clk,
	input rst_n,

	input				trigger_A,
	input[31:0]			trigger_pos_A,
	input				trigger_B,
	input[31:0]			trigger_pos_B,
	input[7:0]			coin_time,

	output reg			coin,
	output reg[31:0]	position_A,
	output reg[31:0]	position_B
	);

// Coincidence judge period.
localparam	COIN_CYCLE		= CLK_FRE * 1'b1;	// coincidence time is 1uS.
// Coincidence time cycle table. unit is 0.1us. The range is 0.1 - 3.2us.
// System clock is 200Mhz!!!
reg[9:0] coin_time_cycle[31:0];
always@(posedge sys_clk)
begin
	coin_time_cycle[0]  <= 10'd19;
	coin_time_cycle[1]  <= 10'd29;
	coin_time_cycle[2]  <= 10'd59;
	coin_time_cycle[3]  <= 10'd79;
	coin_time_cycle[4]  <= 10'd99;
	coin_time_cycle[5]  <= 10'd119;
	coin_time_cycle[6]  <= 10'd139;
	coin_time_cycle[7]  <= 10'd159;
	coin_time_cycle[8]  <= 10'd179;
	coin_time_cycle[9]  <= 10'd199;
	coin_time_cycle[10] <= 10'd219;
	coin_time_cycle[11] <= 10'd239;
	coin_time_cycle[12] <= 10'd259;
	coin_time_cycle[13] <= 10'd279;
	coin_time_cycle[14] <= 10'd299;
	coin_time_cycle[15] <= 10'd319;
	coin_time_cycle[16] <= 10'd339;
	coin_time_cycle[17] <= 10'd359;
	coin_time_cycle[18] <= 10'd379;
	coin_time_cycle[19] <= 10'd399;
	coin_time_cycle[20] <= 10'd419;
	coin_time_cycle[21] <= 10'd439;
	coin_time_cycle[22] <= 10'd459;
	coin_time_cycle[23] <= 10'd479;
	coin_time_cycle[24] <= 10'd499;
	coin_time_cycle[25] <= 10'd519;
	coin_time_cycle[26] <= 10'd539;
	coin_time_cycle[27] <= 10'd559;
	coin_time_cycle[28] <= 10'd579;
	coin_time_cycle[29] <= 10'd599;
	coin_time_cycle[30] <= 10'd619;
	coin_time_cycle[31] <= 10'd639;
end

// state
localparam	IDLE			= 3'b000;
localparam	TRIGGER_A		= 3'b001;
localparam	TRIGGER_B		= 3'b010;
localparam	COIN			= 3'b011;
localparam 	END				= 3'b100;

// trigger buffer
reg[1:0] trigger_buffer_A;
reg[1:0] trigger_buffer_B;
 wire trigger_A_posedge;
 wire trigger_A_negedge;
 wire trigger_B_posedge;
 wire trigger_B_negedge;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		trigger_buffer_A <= 2'd0;
		trigger_buffer_B <= 2'd0;
	end
	else begin
		trigger_buffer_A[0] <= trigger_A;
		trigger_buffer_A[1] <= trigger_buffer_A[0];
		trigger_buffer_B[0] <= trigger_B;
		trigger_buffer_B[1] <= trigger_buffer_B[0];
	end
end

assign trigger_A_posedge = (~trigger_buffer_A[1] && trigger_buffer_A[0]);
assign trigger_A_negedge = (trigger_buffer_A[1] && ~trigger_buffer_A[0]);
assign trigger_B_posedge = (~trigger_buffer_B[1] && trigger_buffer_B[0]);
assign trigger_B_negedge = (trigger_buffer_B[1] && ~trigger_buffer_B[0]);

// state evolution
reg[2:0] state;
reg[15:0] state_clk_cnt;
reg get_position_A;
reg get_position_B;

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		state <= IDLE;
		state_clk_cnt <= 16'd0;
		coin <= 1'b0;
		position_A <= 32'd0;
		position_B <= 32'b0;
	end
	else begin
		case(state)
			IDLE: begin
				// here use posedge to judge coincidence.
				if(trigger_A_posedge) begin
					if(trigger_B_posedge) begin
						state_clk_cnt <= 16'd0;
						state <= COIN;
					end
					else begin
						state <= TRIGGER_A;
					end
				end
				else if(trigger_B_posedge) begin
					if(trigger_A_posedge) begin
						state_clk_cnt <= 16'd0;
						state <= COIN;
					end
					else begin
						state <= TRIGGER_B;
					end
				end
			end
			TRIGGER_A: begin
				if(trigger_B_posedge) begin
					state_clk_cnt <= 16'd0;
					state <= COIN;
				end
				// else if(state_clk_cnt == COIN_CYCLE - 1'b1) begin
				// 	state_clk_cnt <= 16'd0;
				// 	state <= END;
				// end
				else if(state_clk_cnt == coin_time_cycle[coin_time]) begin
					state_clk_cnt <= 16'd0;
					state <= END;
				end
				else begin
					state_clk_cnt <= state_clk_cnt + 1'b1;
				end
			end
			TRIGGER_B: begin
				if(trigger_A_posedge) begin
					state_clk_cnt <= 16'd0;
					state <= COIN;
				end
				// else if(state_clk_cnt == COIN_CYCLE - 1'b1) begin
				// 	state_clk_cnt <= 16'd0;
				// 	state <= END;
				// end
				else if(state_clk_cnt == coin_time_cycle[coin_time]) begin
					state_clk_cnt <= 16'd0;
					state <= END;
				end
				else begin
					state_clk_cnt <= state_clk_cnt + 1'b1;
				end
			end
			COIN: begin
				// set the coincidence flag.
				coin <= 1'b1;
				state_clk_cnt <= 16'd0;
				if(trigger_A == 1'b0) begin
					position_A <= trigger_pos_A;
					get_position_A <= 1'b1;
				end
				if(trigger_B == 1'b0) begin
					position_B <= trigger_pos_B;
					get_position_B <= 1'b1;
				end
				if(get_position_A && get_position_B) begin
					state <= END;
				end
			end
			END: begin
				coin <= 1'b0;
				get_position_A <= 1'b0;
				get_position_B <= 1'b0;
				state <= IDLE;
			end
			default:begin
				state <= IDLE;
			end
		endcase
	end
end

endmodule
