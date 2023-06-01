/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_coarse.v: Coarse time to digital convertor based on system clock counter.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * The output delays 1 sys_clk.
	******************************************************************************
*/

module tdc_coarse
(
	input				sys_clk,
	input				rst_n,

	input   			hit,            // Input pulse.
    output reg          busy,
	(*mark_debug = "true"*) output reg[12:0]    tdc_value       // The converted time.
);

// hit delay buffer. 
reg[1:0] hit_delay = 2'b0;
always@(posedge sys_clk)
begin
	hit_delay[0] <= hit;
	hit_delay[1] <= hit_delay[0];
end

// Check the posedge of hit.
(*mark_debug = "true"*)wire hit_posedge;
(*mark_debug = "true"*)wire hit_negedge;
assign hit_posedge = (~hit_delay[1]) && (hit_delay[0]);
assign hit_negedge = (hit_delay[1]) && (~hit_delay[0]);

// trigger state
localparam	IDLE		= 2'b00;
localparam	BUSY		= 2'b01;
localparam	WAIT		= 2'b10;
localparam	STOP		= 2'b11;

// 
reg[1:0] state;
reg[12:0] tdc_cnt = 13'd0;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
        tdc_value <= 13'd0;
		state <= IDLE;
	end
	else begin
        case(state)
            IDLE: begin
                if(hit_posedge) begin
                    tdc_cnt <= 13'd1;
                    busy <= 1'b1;
                    state <= BUSY;
                end
                else begin
                    busy <= 1'b0;
                    tdc_cnt <= 13'd0;
                end
            end
            BUSY: begin
                if(hit_negedge) begin
                    state <= STOP;
                end
                else begin
                    if(tdc_cnt < 13'd8191) begin
                        tdc_cnt <= tdc_cnt + 1'b1;
                    end
                    state <= BUSY;
                end
            end
            STOP: begin
                tdc_value <= tdc_cnt;
                busy <= 1'b0;
                state <= IDLE;
            end
            default: begin
                state <= IDLE;
            end
        endcase
	end
end

endmodule
