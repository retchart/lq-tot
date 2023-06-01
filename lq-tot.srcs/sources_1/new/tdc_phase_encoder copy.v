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

    input               enable,
    input[7:0]          phase,
	(*mark_debug = "true"*)output reg[2:0]     phase_time       // The time by multi-phase shift.
);

always@(posedge sys_clk)
begin
	if(enable) begin 
        case(phase)
            8'b01111111, 8'b10000000: begin
                phase_time <= 3'd0;
            end
            8'b00111111, 8'b11000000: begin
                phase_time <= 3'd1;
            end
            8'b00011111, 8'b11100000: begin
                phase_time <= 3'd2;
            end
            8'b00001111, 8'b11110000: begin
                phase_time <= 3'd3;
            end
            8'b00000111, 8'b11111000: begin
                phase_time <= 3'd4;
            end
            8'b00000011, 8'b11111100: begin
                phase_time <= 3'd5;
            end
            8'b00000001, 8'b11111110: begin
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
