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
    input               clk1,
    input               clk2,
    input               clk3,
    input               clk4,
    input               clk5,
    input               clk6,
    input               clk7,
    // input[7:0]          q,

	input   			hit,            // Input pulse.
    output reg          busy,           // time is converting.
	(*mark_debug = "true"*)output reg[2:0]     tdc_value       // The converted time.
);


// Phase counter used to synchrotron the phase of 8 clocks.
reg phase_count = 1'b0;
always@(posedge sys_clk)
begin
	phase_count <= phase_count + 1'b1;
end

// buffer the state of each clock.
wire[7:0] q;
wire[7:0] q_n;
assign q[0] = phase_count;
assign q_n[0] = ~phase_count;
tdc_dff dff_cnt7(
    .clk(clk7), 
    .din(phase_count),
    .q(q[7]),
    .q_n(q_n[7])
);
tdc_dff dff_cnt6(
    .clk(clk6), 
    .din(q_n[7]),
    .q(q[6]),
    .q_n(q_n[6])
);
tdc_dff dff_cnt5(
    .clk(clk5), 
    .din(q_n[6]),
    .q(q[5]),
    .q_n(q_n[5])
);
tdc_dff dff_cnt4(
    .clk(clk4), 
    .din(q_n[5]),
    .q(q[4]),
    .q_n(q_n[4])
);
tdc_dff dff_cnt3(
    .clk(clk3), 
    .din(q_n[4]),
    .q(q[3]),
    .q_n(q_n[3])
);
tdc_dff dff_cnt2(
    .clk(clk2), 
    .din(q_n[3]),
    .q(q[2]),
    .q_n(q_n[2])
);
tdc_dff dff_cnt1(
    .clk(clk1), 
    .din(q_n[2]),
    .q(q[1]),
    .q_n(q_n[1])
);

/*
// Replace the routing line with LUT to minimize the time jitter.
wire hit_level0;
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level0 (
    .O(hit_level0), // LUT general output
    .I0(hit) // LUT input
);
// First level (1->2)
wire hit_level1_0;
wire hit_level1_1;
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level1_0 (
    .O(hit_level1_0), // LUT general output
    .I0(hit_level0) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level1_1 (
    .O(hit_level1_1), // LUT general output
    .I0(hit_level0) // LUT input
);
// Second level (2->4)
wire hit_level2_0;
wire hit_level2_1;
wire hit_level2_2;
wire hit_level2_3;
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level2_0 (
    .O(hit_level2_0), // LUT general output
    .I0(hit_level1_0) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level2_1 (
    .O(hit_level2_1), // LUT general output
    .I0(hit_level1_0) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level2_2 (
    .O(hit_level2_2), // LUT general output
    .I0(hit_level1_1) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level2_3 (
    .O(hit_level2_3), // LUT general output
    .I0(hit_level1_1) // LUT input
);
// Third level (4->8)
wire hit_level3_0;
wire hit_level3_1;
wire hit_level3_2;
wire hit_level3_3;
wire hit_level3_4;
wire hit_level3_5;
wire hit_level3_6;
wire hit_level3_7;
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_0 (
    .O(hit_level3_0), // LUT general output
    .I0(hit_level2_0) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_1 (
    .O(hit_level3_1), // LUT general output
    .I0(hit_level2_0) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_2 (
    .O(hit_level3_2), // LUT general output
    .I0(hit_level2_1) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_3 (
    .O(hit_level3_3), // LUT general output
    .I0(hit_level2_1) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_4 (
    .O(hit_level3_4), // LUT general output
    .I0(hit_level2_2) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_5 (
    .O(hit_level3_5), // LUT general output
    .I0(hit_level2_2) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_6 (
    .O(hit_level3_6), // LUT general output
    .I0(hit_level2_3) // LUT input
);
LUT1 #(
    .INIT(2'b01) // Specify LUT Contents
) LUT1_inst_level3_7 (
    .O(hit_level3_7), // LUT general output
    .I0(hit_level2_3) // LUT input
);
*/

// buffer the state of each clock.
wire[7:0] hit_rising;
wire[7:0] hit_falling;
tdc_hit_detect tdc_hit0(
    .clk(sys_clk),
    .hit(hit), 
    .hit_rising(hit_rising[0]),
    .hit_falling(hit_falling[0])
);
tdc_hit_detect tdc_hit1(
    .clk(clk1),
    .hit(hit), 
    .hit_rising(hit_rising[1]),
    .hit_falling(hit_falling[1])
);
tdc_hit_detect tdc_hit2(
    .clk(clk2),
    .hit(hit), 
    .hit_rising(hit_rising[2]),
    .hit_falling(hit_falling[2])
);
tdc_hit_detect tdc_hit3(
    .clk(clk3),
    .hit(hit), 
    .hit_rising(hit_rising[3]),
    .hit_falling(hit_falling[3])
);
tdc_hit_detect tdc_hit4(
    .clk(clk4),
    .hit(hit), 
    .hit_rising(hit_rising[4]),
    .hit_falling(hit_falling[4])
);
tdc_hit_detect tdc_hit5(
    .clk(clk5),
    .hit(hit), 
    .hit_rising(hit_rising[5]),
    .hit_falling(hit_falling[5])
);
tdc_hit_detect tdc_hit6(
    .clk(clk6),
    .hit(hit), 
    .hit_rising(hit_rising[6]),
    .hit_falling(hit_falling[6])
);
tdc_hit_detect tdc_hit7(
    .clk(clk7),
    .hit(hit), 
    .hit_rising(hit_rising[7]),
    .hit_falling(hit_falling[7])
);

// latch the hit_rising counter at rising edge of hit.
reg[7:0] phase_latch = 8'h00;
always @(*)
begin
    if(hit_rising[0]) begin
        phase_latch[0] = q[0];
    end
    if(hit_rising[1]) begin
        phase_latch[1] = q[1];
    end
    if(hit_rising[2]) begin
        phase_latch[2] = q[2];
    end
    if(hit_rising[3]) begin
        phase_latch[3] = q[3];
    end
    if(hit_rising[4]) begin
        phase_latch[4] = q[4];
    end
    if(hit_rising[5]) begin
        phase_latch[5] = q[5];
    end
    if(hit_rising[6]) begin
        phase_latch[6] = q[6];
    end
    if(hit_rising[7]) begin
        phase_latch[7] = q[7];
    end
end

// latch the phase counter at falling edge of hit.
reg[7:0] phase_n_latch = 8'h00;
always @(*)
begin
    if(hit_falling[0]) begin
        phase_n_latch[0] = q[0];
    end
    if(hit_falling[1]) begin
        phase_n_latch[1] = q[1];
    end
    if(hit_falling[2]) begin
        phase_n_latch[2] = q[2];
    end
    if(hit_falling[3]) begin
        phase_n_latch[3] = q[3];
    end
    if(hit_falling[4]) begin
        phase_n_latch[4] = q[4];
    end
    if(hit_falling[5]) begin
        phase_n_latch[5] = q[5];
    end
    if(hit_falling[6]) begin
        phase_n_latch[6] = q[6];
    end
    if(hit_falling[7]) begin
        phase_n_latch[7] = q[7];
    end
end

// Convert phase level to phase time.
(*mark_debug = "true"*)wire[2:0] phase_time;
(*mark_debug = "true"*)wire[2:0] phase_time_n;
reg encoder_enable = 1'b0;
reg encoder_n_enable = 1'b0;
tdc_phase_encoder phase_encoder
(
	.sys_clk(sys_clk),

    .enable(1'b1),
    .phase(phase_latch),
	.phase_time(phase_time)       // The time by multi-phase shift.
);
tdc_phase_encoder phase_encoder_n
(
	.sys_clk(sys_clk),

    .enable(1'b1),
    .phase(phase_n_latch),
	.phase_time(phase_time_n)       // The time by multi-phase shift.
);

// Get the hit posedge and negedge at sys_clk.
reg hit_buf0 = 1'b0;
reg hit_buf1 = 1'b0;
wire hit_posedge;
wire hit_negedge;
always@(posedge sys_clk)
begin
    hit_buf0 <= hit;
    hit_buf1 <= hit_buf0;
end
assign hit_posedge = (~hit_buf1) & hit_buf0;
assign hit_negedge = (hit_buf1) & (~hit_buf0);

// Get the fine time 2 sys_clk after 
// trigger state
localparam	IDLE		= 2'b00;
localparam	BUSY		= 2'b01;
localparam	WAIT		= 2'b10;
localparam	STOP		= 2'b11;
reg[1:0] state_posedge = IDLE;
reg[1:0] state_cnt_posedge = 2'b00;
(*mark_debug = "true"*)reg[7:0] phase_time_posedge = 8'h00;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        state_posedge <= IDLE;
    end
	else begin
        case(state_posedge)
            IDLE: begin
                encoder_enable <= 1'b0;
                if(hit_posedge) begin
                    state_cnt_posedge <= 1'b0;
                    state_posedge <= WAIT;
                end
            end
            WAIT: begin
                if(state_cnt_posedge < 2'b11) begin
                    // start encoder after 1 system clock.
                    encoder_enable <= 1'b1;
                    state_cnt_posedge <= state_cnt_posedge + 1'b1;
                end
                else begin
                    encoder_enable <= 1'b0;
                    phase_time_posedge <= phase_time;
                    state_cnt_posedge <= 1'b0;
                    state_posedge <= IDLE;
                end
            end
            default: begin
                state_cnt_posedge <= 1'b0;
                state_posedge <= IDLE;
            end
        endcase
    end
end

reg[1:0] state_negedge;
reg[1:0] state_cnt_negedge = 2'b00;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        state_negedge <= IDLE;
    end
	else begin
        case(state_negedge)
            IDLE: begin
                encoder_n_enable <= 1'b0;
                if(hit_negedge) begin
                    state_cnt_negedge <= 1'b0;
                    state_negedge <= WAIT;
                end
            end
            WAIT: begin
                if(state_cnt_negedge < 2'b11) begin
                    // start encoder after 1 system clock.
                    encoder_n_enable <= 1'b1;
                    state_cnt_negedge <= state_cnt_negedge + 1'b1;
                end
                else begin
                    if(phase_time_posedge > phase_time_n) begin
                        tdc_value <= 3'd7 - phase_time_posedge + phase_time_n;
                    end
                    else begin
                        tdc_value <= phase_time_n - phase_time_posedge - 1'b1;
                    end
                    encoder_n_enable <= 1'b0;
                    state_cnt_negedge <= 2'b0;
                    state_negedge <= IDLE;
                end
            end
            default: begin
                state_cnt_negedge <= 2'b0;
                state_negedge <= IDLE;
            end
        endcase
    end
end

// Set the busy flag.
reg[1:0] state_busy = IDLE;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin 
        busy <= 1'b0;
        state_busy <= 2'b00;
    end
    else begin
        case(state_busy)
            IDLE: begin
                if(hit_posedge) begin
                    busy <= 1'b1;
                    state_busy <= WAIT;
                end
                else begin
                    busy <= 1'b0;
                end
            end
            WAIT: begin
                if(state_cnt_negedge >= 2'b11) begin
                    state_busy <= IDLE;
                end
            end
            default: begin
                busy <= 1'b0;
                state_busy <= IDLE;
            end
        endcase
    end
end

endmodule
