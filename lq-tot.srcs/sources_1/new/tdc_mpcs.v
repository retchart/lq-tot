/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_mpcs.v: Time to digital convertor based on multi-phase clock sample.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * Coarse time is based on main clock. Fine time is 1 / 8 of the main clock.
 * The max tdc_value is 4096 * 5 = 20480 ns.
 * event list frame is: time_stamp[47:40], time_stamp[39:32], time_stamp[31:24]
 *      time_stamp[23:16], time_stamp[15:8], time_stamp[7:0],
 *      tdc_value[15:8], tdc_value[7:0].
	******************************************************************************
*/

module tdc_mpcs
#(
	parameter CLK_FRE = 200,            //clock frequency(Mhz)
	parameter TIME_STAMP_PERIOD = 5,  	//clock period(5 nS)
    parameter JITTER_TIME = 10,        // Time to avoid invalid events caused by jitter.
    parameter POLARITY = 1'b0           // Polarity of hit.
)
(
	input				sys_clk,
	input				rst_n,

	input				enable,         // High valid.
    (*mark_debug = "true"*)input               sync,           // sychronization.
    input               clk1,
    input               clk2,
    input               clk3,
    input               clk4,
    input               clk5,
    input               clk6,
    input               clk7,
    //input[7:0]          q,

	(*mark_debug = "true"*)input   			hit,            // Input pulse.
    input[7:0]          number,         // Channel number.

    output reg          fifo_busy,      // busy indicator.
    output              fifo_full,
    input               fifo_rd_en,     // fifo read enable.
    output[7:0]         fifo_dout,      // fifo data output.
    (*mark_debug = "true"*)output[6:0]         fifo_data_count // fifo data counts.  
);

// pulse width's unit cycle.
localparam	CYCLE_TIME_STAMP 	    = CLK_FRE * TIME_STAMP_PERIOD / 1000;

// Replace the routing line with LUT to minimize the time jitter.
wire hit_level0;
LUT1 #(
    .INIT({~POLARITY,POLARITY}) // Specify LUT Contents
) LUT1_inst_level0 (
    .O(hit_level0), // LUT general output
    .I0(hit) // LUT input
);
wire hit_coarse;
LUT1 #(
    .INIT({~POLARITY,POLARITY}) // Specify LUT Contents
) LUT1_inst_coarse (
    .O(hit_coarse), // LUT general output
    .I0(hit) // LUT input
);

// Coarse TDC.
wire busy_coarse;
wire[12:0] tdc_value_coarse;
tdc_coarse tdc_coarse_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.hit(hit_coarse),                          // Input pulse.
    .busy(busy_coarse),
	.tdc_value(tdc_value_coarse)        // The converted time.
);

// Fine TDC
wire busy_fine;
wire[2:0] tdc_value_fine;
tdc_fine tdc_fine_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),

	.hit(hit_level0),                      // Input pulse.
    .busy(busy_fine),
	.tdc_value(tdc_value_fine)      // The converted time.
);

// Detect the posedge of synchronization.
reg sync_buf0 = 1'b0;
reg sync_buf1 = 1'b0;
wire sync_posedge;
always@(posedge sys_clk)
begin
    sync_buf0 <= sync;
    sync_buf1 <= sync_buf0;
end
assign sync_posedge = (~sync_buf1) & sync_buf0;

// Time stamp.
reg[15:0] sys_time_clk_cnt = 16'd0;
reg[47:0] sys_time = 48'd0;
always@(posedge sys_clk)
begin
    if(sync_posedge) begin
        sys_time_clk_cnt <= 16'd0;
	    sys_time <= 48'b0;
    end
	else if(sys_time_clk_cnt >= CYCLE_TIME_STAMP - 1'b1) begin
        sys_time_clk_cnt <= 16'd0;
        sys_time <= sys_time + 1'b1;
	end
	else if(enable) begin
		sys_time_clk_cnt <= sys_time_clk_cnt + 1'b1;
	end
end

// busy flag. 
reg busy_coarse_buf = 1'b0;
reg busy_fine_buf = 1'b0;
always@(posedge sys_clk)
begin
	busy_coarse_buf <= busy_coarse;
	busy_fine_buf <= busy_fine;
end

// Check the posedge of of busy_coarse(start flag) and negedge of busy_fine
// (stop flag).
(*mark_debug = "true"*)wire busy0;
(*mark_debug = "true"*)wire busy1;
(*mark_debug = "true"*)wire busy2;
assign busy0 = (~busy_coarse_buf) && (busy_coarse);
assign busy1 = (busy_coarse_buf) && (~busy_coarse);
assign busy2 = (busy_fine_buf) && (~busy_fine);

// TDC state
localparam	IDLE		= 3'b000;
localparam	BUSY		= 3'b001;
localparam	STOP1		= 3'b010;
localparam	STOP2		= 3'b100;
localparam  WRITE       = 3'b101;
localparam  WAIT        = 3'b110;
// parameters.
(*mark_debug = "true"*)reg[2:0] state;
(*mark_debug = "true"*)reg[9:0] state_clk_cnt = 10'h00;
reg[47:0] time_stamp = 48'd0;
reg[15:0] tdc_value = 16'h00;
reg[7:0] fifo_din = 8'h00;
reg fifo_wr_en = 1'b0;
// wire fifo_full;
// TDC pos analysis in list mode.
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
        state <= IDLE;
        state_clk_cnt = 10'h00;
    end
    else begin
        case(state)
            IDLE: begin
				state_clk_cnt <= 10'h00;
                fifo_wr_en <= 1'b0;
                fifo_busy <= 1'b0;
				if(busy0 && enable && ({fifo_full,fifo_data_count} <= 7'd112)) begin
                    time_stamp <= sys_time[47:1];
					state <= BUSY;
				end
            end
            BUSY: begin
                if(busy1) begin
                    state <= STOP1;
                end
            end
            STOP1: begin
                // set busy flag ahead of write.
                fifo_busy <= 1'b1;
                if(busy2) begin
                    tdc_value[15:3] <= tdc_value_coarse;
                    tdc_value[2:0] <= tdc_value_fine;
                    state_clk_cnt <= 10'h00;
                    state <= STOP2;
                end
            end
            STOP2: begin
                // Check fifo can store one event.
                if(~fifo_rd_en) begin
                    state <= WRITE;
                end
            end
            WRITE: begin
                case(state_clk_cnt)
                    8'h00: begin
                        fifo_din <= time_stamp[39:32];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h01:begin
                        fifo_din <= time_stamp[31:24];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h02:begin
                        fifo_din <= time_stamp[23:16];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h03:begin
                        fifo_din <= time_stamp[15:8];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h04:begin
                        fifo_din <= time_stamp[7:0];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h05:begin
                        fifo_din <= number;
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h06:begin
                        fifo_din <= tdc_value[15:8];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                    8'h07:begin
                        fifo_din <= tdc_value[7:0];
                        fifo_wr_en <= 1'b1;
                        state_clk_cnt <= 10'h00;
                        state <= WAIT;
                    end
                    default: begin
                        fifo_wr_en <= 1'b0;
                        fifo_busy <= 1'b0;
                        state_clk_cnt <= 10'h00;
                        state <= WAIT;
                    end
                endcase
            end
            WAIT: begin
                fifo_wr_en <= 1'b0;
                fifo_busy <= 1'b0;
                // System clock is in 5ns. The jitter time is in 10ns.
                if(state_clk_cnt[8:1] < JITTER_TIME) begin
                    if(busy0) begin
                        state_clk_cnt <= 10'd0;
                    end
                    else begin
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                    end
                end
                else begin
                    state_clk_cnt <= 10'h00;
                    state <= IDLE;
                end
            end
            default: begin
                fifo_wr_en <= 1'b0;
                fifo_busy <= 1'b0;
                state_clk_cnt <= 10'h00;
                state <= IDLE;
            end
        endcase
    end
end

// tdc fifo.
trigger_width_fifo trigger_width_fifo_inst (
  .clk(sys_clk),                    // input wire clk
  .srst(~rst_n),                     // input wire srst
  .din(fifo_din),                   // input wire [7 : 0] din
  .wr_en(fifo_wr_en),               // input wire wr_en
  .rd_en(fifo_rd_en),               // input wire rd_en
  .dout(fifo_dout),                 // output wire [7 : 0] dout
  .full(fifo_full),                          // output wire full
  .empty(fifo_empty),               // output wire empty
  .data_count(fifo_data_count)      // output wire [5 : 0] data_count
);



endmodule
