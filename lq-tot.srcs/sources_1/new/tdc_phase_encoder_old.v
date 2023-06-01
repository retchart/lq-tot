/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_phase_encoder.v: Time to digital convertor based on multi-phase clock sample.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * Coarse time is based on main clock. Fine time is 1 / 8 of the main clock.
	******************************************************************************
*/

module tdc_phase_encoder
(
	input				sys_clk,
	input				rst_n,

    input[7:0]          phase,
	output reg[2:0]     phase_time       // The time by multi-phase shift.
);

reg[7:0] phase_jump;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        phase_jump <= 8'b0;
    end
	else begin
        phase_jump[7:1] <= phase[7:1] & (~phase[6:0]);
    end
end

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        phase_time <= 3'b0;
    end
	else begin 
        case(phase)
            8'b11111110, 8'b00000001: begin
                phase_time <= 3'd0;
            end
            8'b11111100, 8'b00000011: begin
                phase_time <= 3'd1;
            end
            8'b11111000, 8'b00000111: begin
                phase_time <= 3'd2;
            end
            8'b11110000, 8'b00001111: begin
                phase_time <= 3'd3;
            end
            8'b11100000, 8'b00011111: begin
                phase_time <= 3'd4;
            end
            8'b11000000, 8'b00111111: begin
                phase_time <= 3'd5;
            end
            8'b10000000, 8'b01111111: begin
                phase_time <= 3'd6;
            end
            8'b00000000, 8'b11111111: begin
                phase_time <= 3'd7;
            end
            default: begin
                phase_time <= 3'd0;
            end
        endcase
    end
end

endmodule
