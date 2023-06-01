/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_fine.v: fine time to digital convertor based on system clock counter.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * The output delays 1 sys_clk.
	******************************************************************************
*/

module tdc_fine
(
	input				sys_clk,
	input				rst_n,

	input   			hit,            // Input pulse.
	output reg[2:0]     tdc_value       // The converted time.
);

// hit delay buffer. 
reg hit_delay[0:4];
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		hit_delay[0] <= 1'b0;
		hit_delay[1] <= 1'b0;
		hit_delay[2] <= 1'b0;
		hit_delay[3] <= 1'b0;
		hit_delay[4] <= 1'b0;
	end
	else begin
		hit_delay[0] <= hit;
		hit_delay[1] <= hit_delay[0];
		hit_delay[2] <= hit_delay[1];
		hit_delay[3] <= hit_delay[2];
		hit_delay[4] <= hit_delay[3];
	end
end

// Check the posedge of hit.
(*mark_debug = "true"*)wire hit_posedge;
(*mark_debug = "true"*)wire hit_negedge;
assign hit_posedge = (~hit_delay[4]) && (hit_delay[3]);
assign hit_negedge = (hit_delay[4]) && (~hit_delay[3]);

// Generate 7 clock for every 45 degree.
wire clk1;
wire clk2;
wire clk3;
wire clk4;
wire clk5;
wire clk6;
wire clk7;
clk_phase_7 clk_mp_inst
(
    // Clock out ports
    .clk_out1(clk1),
    .clk_out2(clk2),
    .clk_out3(clk3),
    .clk_out4(clk4),
    .clk_out5(clk5),
    .clk_out6(clk6),
    .clk_out7(clk7),

    // Status and control signals
    .reset(~rst_n),

    // Clock in ports
    .clk_in1(sys_clk)
);

// buffer the state of each clock.
reg[7:0] buf_lv0 = 8'h00;
reg[7:0] buf_lv1 = 8'h00;
reg[7:0] buf_lv2 = 8'h00;
reg[7:0] buf_lv3 = 8'h00;
// Two stage buffer to avoid jitter.
always@(posedge sys_clk or negedge rst_n)
begin
    buf_lv0[0] <= hit;
    buf_lv1[0] <= buf_lv0[0];
end
always@(posedge clk1 or negedge rst_n)
begin
    buf_lv0[1] <= hit;
    buf_lv1[1] <= buf_lv0[1];
end
always@(posedge clk2 or negedge rst_n)
begin
    buf_lv0[2] <= hit;
    buf_lv1[2] <= buf_lv0[2];
end
always@(posedge clk3 or negedge rst_n)
begin
    buf_lv0[3] <= hit;
    buf_lv1[3] <= buf_lv0[3];
end
always@(posedge clk4 or negedge rst_n)
begin
    buf_lv0[4] <= hit;
    buf_lv1[4] <= buf_lv0[4];
end
always@(posedge clk5 or negedge rst_n)
begin
    buf_lv0[5] <= hit;
    buf_lv1[5] <= buf_lv0[5];
end
always@(posedge clk6 or negedge rst_n)
begin
    buf_lv0[6] <= hit;
    buf_lv1[6] <= buf_lv0[6];
end
always@(posedge clk7 or negedge rst_n)
begin
    buf_lv0[7] <= hit;
    buf_lv1[7] <= buf_lv0[7];
end

// Reduce sys_clk from 8 to 2.
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        buf_lv2[3:0] <= 4'b0;
    end
	else begin
        buf_lv2[3:0] <= buf_lv1[3:0];
    end
end
always@(posedge clk4 or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        buf_lv2[7:4] <= 4'b0;
    end
	else begin
        buf_lv2[7:4] <= buf_lv1[7:4];
    end
end
// Reduce sys_clk from 2 to 1.
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        buf_lv3 <= 8'b0;
    end
	else begin
        buf_lv3 <= buf_lv2;
    end
end

// Get the phase time at the signal edge.
wire[2:0] time_phase;
tdc_mp_pos tdc_mp_pos_inst
(
    .sys_clk(sys_clk),
	.rst_n(rst_n),

    .phase(buf_lv3),
	.time_phase(time_phase)
);

// trigger state
localparam	IDLE		= 2'b00;
localparam	START		= 2'b01;
localparam	WAIT		= 2'b10;
localparam	STOP		= 2'b11;

// 
reg[1:0] state;
reg[2:0] start_time;
reg[2:0] stop_time;
reg[7:0] state_count;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		state <= IDLE;
        state_count <= 8'd0;
        start_time <= 3'b0;
        stop_time <= 3'b0;
        tdc_value <= 3'd0;
	end
	else begin
        case(state)
            IDLE: begin
                // start new tdc convertion.
                if(hit_posedge) begin
                    // Get the phase time at hit start.
                    start_time <= time_phase;
                    stop_time <= 3'b0;
                    tdc_value <= 3'b0;
                    state <= START;
                end
            end
            START: begin
                if(hit_negedge) begin
                    // Get the phase time at hit start.
                    stop_time <= time_phase;
                    state <= STOP;
                end
                else begin
                    state <= WAIT;
                end
            end
            WAIT: begin
                if(hit_negedge) begin
                    // Get the phase time at hit stop.
                    stop_time <= time_phase;
                    state <= STOP;
                end
            end
            STOP: begin
                // Get the fine tdc time.
                if(stop_time >= start_time) begin
                    tdc_value <= stop_time - start_time;
                end 
                else begin
                    tdc_value <= (4'b1000 - start_time + stop_time);
                end
                state <= IDLE;
            end
            default: begin
                state <= IDLE;
            end
        endcase
	end
end

endmodule
