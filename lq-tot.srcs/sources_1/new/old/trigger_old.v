/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * ide1162.v: ide1162 readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
 * trigger pulse width's unit is 50ns. The max pulse width is 12.8us.
	******************************************************************************
*/

module trigger
#(
	parameter CLK_FRE = 200,        	//clock frequency(Mhz)
	parameter TIME_STAMP_PERIOD = 10  	//clock period(50 nS)
)
(
	input				sys_clk,
	input				rst_n,

	input				enable,         // High valid.
    input               sync,           // synchronization.
    input[3:0]          mode,           // 0 - position mode; 1 - list mode.
    
	input[31:0]			din,            // trigger wires.
	input[7:0]			jitter_time,    // jitter time along one event.
	output reg		    trigger,        // trigger flag, used for ide1162 and coincidence.
	output reg[31:0]    trigger_pos,    // position mode: 32bit position / 32 bit trigger wire position.
    
    (*mark_debug = "true"*)output reg          store_wr_req,   // store fifo write enable.
    (*mark_debug = "true"*)input               store_wr_ack,   // store fifo write compelete ack.
    (*mark_debug = "true"*)output reg[7:0]     trigger_ch,     // list mode: trigger wire; 
    (*mark_debug = "true"*)output reg[7:0]     trigger_data    // list mode: pulse width
	);

// trigger state
localparam	IDLE		= 2'b00;
localparam	TRIGGER		= 2'b01;
localparam	WAIT		= 2'b10;
localparam	END			= 2'b11;

// trigger jitter period.
localparam	TRIGGER_JITTER_CYCLE	= 8'd100;	// All trigger valid in 1000nS
// jitter time cycle table. unit is 0.1us. The range is 0.1 - 1.6us.
// System clock is 200Mhz!!!
reg[8:0] jitter_time_cycle[15:0];
always@(posedge sys_clk)
begin
	jitter_time_cycle[0]  <= 9'd19;
	jitter_time_cycle[1]  <= 9'd29;
	jitter_time_cycle[2]  <= 9'd59;
	jitter_time_cycle[3]  <= 9'd79;
	jitter_time_cycle[4]  <= 9'd99;
	jitter_time_cycle[5]  <= 9'd119;
	jitter_time_cycle[6]  <= 9'd139;
	jitter_time_cycle[7]  <= 9'd159;
	jitter_time_cycle[8]  <= 9'd179;
	jitter_time_cycle[9]  <= 9'd199;
	jitter_time_cycle[10] <= 9'd219;
	jitter_time_cycle[11] <= 9'd239;
	jitter_time_cycle[12] <= 9'd259;
	jitter_time_cycle[13] <= 9'd279;
	jitter_time_cycle[14] <= 9'd299;
	jitter_time_cycle[15] <= 9'd319;
end

// din buffer. Two stage buffer to avoid jitter.
reg[31:0] din_buf0;
reg[31:0] din_buf1;
reg[31:0] din_buf2;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		din_buf0 <= 32'd0;
		din_buf1 <= 32'd0;
		din_buf2 <= 32'd0;
	end
	else begin
		din_buf0 <= din;
		din_buf1 <= din_buf0;
		din_buf2 <= din_buf1;
	end
end

// posedge of din detect.
(*mark_debug = "true"*)wire[31:0] din_posedge;
assign din_posedge[0] = (~din_buf2[0]) && (din_buf1[0]);
assign din_posedge[1] = (~din_buf2[1]) && (din_buf1[1]);
assign din_posedge[2] = (~din_buf2[2]) && (din_buf1[2]);
assign din_posedge[3] = (~din_buf2[3]) && (din_buf1[3]);
assign din_posedge[4] = (~din_buf2[4]) && (din_buf1[4]);
assign din_posedge[5] = (~din_buf2[5]) && (din_buf1[5]);
assign din_posedge[6] = (~din_buf2[6]) && (din_buf1[6]);
assign din_posedge[7] = (~din_buf2[7]) && (din_buf1[7]);
assign din_posedge[8] = (~din_buf2[8]) && (din_buf1[8]);
assign din_posedge[9] = (~din_buf2[9]) && (din_buf1[9]);
assign din_posedge[10] = (~din_buf2[10]) && (din_buf1[10]);
assign din_posedge[11] = (~din_buf2[11]) && (din_buf1[11]);
assign din_posedge[12] = (~din_buf2[12]) && (din_buf1[12]);
assign din_posedge[13] = (~din_buf2[13]) && (din_buf1[13]);
assign din_posedge[14] = (~din_buf2[14]) && (din_buf1[14]);
assign din_posedge[15] = (~din_buf2[15]) && (din_buf1[15]);
assign din_posedge[16] = (~din_buf2[16]) && (din_buf1[16]);
assign din_posedge[17] = (~din_buf2[17]) && (din_buf1[17]);
assign din_posedge[18] = (~din_buf2[18]) && (din_buf1[18]);
assign din_posedge[19] = (~din_buf2[19]) && (din_buf1[19]);
assign din_posedge[20] = (~din_buf2[20]) && (din_buf1[20]);
assign din_posedge[21] = (~din_buf2[21]) && (din_buf1[21]);
assign din_posedge[22] = (~din_buf2[22]) && (din_buf1[22]);
assign din_posedge[23] = (~din_buf2[23]) && (din_buf1[23]);
assign din_posedge[24] = (~din_buf2[24]) && (din_buf1[24]);
assign din_posedge[25] = (~din_buf2[25]) && (din_buf1[25]);
assign din_posedge[26] = (~din_buf2[26]) && (din_buf1[26]);
assign din_posedge[27] = (~din_buf2[27]) && (din_buf1[27]);
assign din_posedge[28] = (~din_buf2[28]) && (din_buf1[28]);
assign din_posedge[29] = (~din_buf2[29]) && (din_buf1[29]);
assign din_posedge[30] = (~din_buf2[30]) && (din_buf1[30]);
assign din_posedge[31] = (~din_buf2[31]) && (din_buf1[31]);

// negedge of din.
wire[31:0] din_negedge;
assign din_negedge[0] = (din_buf2[0]) && (~din_buf1[0]);
assign din_negedge[1] = (din_buf2[1]) && (~din_buf1[1]);
assign din_negedge[2] = (din_buf2[2]) && (~din_buf1[2]);
assign din_negedge[3] = (din_buf2[3]) && (~din_buf1[3]);
assign din_negedge[4] = (din_buf2[4]) && (~din_buf1[4]);
assign din_negedge[5] = (din_buf2[5]) && (~din_buf1[5]);
assign din_negedge[6] = (din_buf2[6]) && (~din_buf1[6]);
assign din_negedge[7] = (din_buf2[7]) && (~din_buf1[7]);
assign din_negedge[8] = (din_buf2[8]) && (~din_buf1[8]);
assign din_negedge[9] = (din_buf2[9]) && (~din_buf1[9]);
assign din_negedge[10] = (din_buf2[10]) && (~din_buf1[10]);
assign din_negedge[11] = (din_buf2[11]) && (~din_buf1[11]);
assign din_negedge[12] = (din_buf2[12]) && (~din_buf1[12]);
assign din_negedge[13] = (din_buf2[13]) && (~din_buf1[13]);
assign din_negedge[14] = (din_buf2[14]) && (~din_buf1[14]);
assign din_negedge[15] = (din_buf2[15]) && (~din_buf1[15]);
assign din_negedge[16] = (din_buf2[16]) && (~din_buf1[16]);
assign din_negedge[17] = (din_buf2[17]) && (~din_buf1[17]);
assign din_negedge[18] = (din_buf2[18]) && (~din_buf1[18]);
assign din_negedge[19] = (din_buf2[19]) && (~din_buf1[19]);
assign din_negedge[20] = (din_buf2[20]) && (~din_buf1[20]);
assign din_negedge[21] = (din_buf2[21]) && (~din_buf1[21]);
assign din_negedge[22] = (din_buf2[22]) && (~din_buf1[22]);
assign din_negedge[23] = (din_buf2[23]) && (~din_buf1[23]);
assign din_negedge[24] = (din_buf2[24]) && (~din_buf1[24]);
assign din_negedge[25] = (din_buf2[25]) && (~din_buf1[25]);
assign din_negedge[26] = (din_buf2[26]) && (~din_buf1[26]);
assign din_negedge[27] = (din_buf2[27]) && (~din_buf1[27]);
assign din_negedge[28] = (din_buf2[28]) && (~din_buf1[28]);
assign din_negedge[29] = (din_buf2[29]) && (~din_buf1[29]);
assign din_negedge[30] = (din_buf2[30]) && (~din_buf1[30]);
assign din_negedge[31] = (din_buf2[31]) && (~din_buf1[31]);

// trigger pos analysis in position mode.
reg[1:0] state_pos;
reg[15:0] state_pos_clk_cnt;
reg[31:0] trigger_pos_buf;
reg store_wr_req_pos;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		state_pos <= IDLE;
		trigger <= 1'b0;
		state_pos_clk_cnt <= 16'd0;
		trigger_pos_buf <= 32'b0;
        trigger_pos <= 32'b0;
        store_wr_req_pos <= 1'b0;
	end
	else begin
		case(state_pos)
			IDLE: begin
				state_pos_clk_cnt <= 16'd0;
				if(din_posedge > 1'b0 && enable && (mode == 4'd0)) begin
					trigger <= 1'b1;
					trigger_pos_buf <= din_posedge;
					state_pos <= TRIGGER;
				end
				else begin
					trigger <= 1'b0;
				end
			end
			TRIGGER:begin
				// If another wire's signal trigger
				if(din_posedge > 1'b0) begin
					// state_pos_clk_cnt <= 16'd0;
					trigger_pos_buf <= trigger_pos_buf | din_posedge;
				end
				else begin
					// A typical MWPC signal is about 200nS. 
					// So, trigger delay about 50 sys_clk(200MHz, 250nS).
					// if(state_pos_clk_cnt == TRIGGER_JITTER_CYCLE - 1'b1) begin
					//     trigger_pos <= trigger_pos_buf;
					//     trigger <= 1'b0;
					//     state_pos <= END;
					//     state_pos_clk_cnt <= 16'd0;
					// end
					if(state_pos_clk_cnt == jitter_time_cycle[jitter_time]) begin
						trigger <= 1'b0;
                        trigger_pos <= trigger_pos_buf;
						state_pos <= END;
						state_pos_clk_cnt <= 16'd0;
					end
					else begin
						state_pos_clk_cnt <= state_pos_clk_cnt + 1'b1;
					end
				end
			end
			END: begin
				trigger_pos_buf <= 32'b0;
				state_pos_clk_cnt <= 16'd0;
				state_pos <= IDLE;
			end
			default: begin
				trigger_pos_buf <= 32'b0;
				state_pos_clk_cnt <= 16'd0;
				state_pos <= IDLE;	
			end

		endcase
	end
end

// trigger pos analysis in list mode.
localparam LIST_CHECK           = 4'b0000;
localparam LIST_READ_REQ        = 4'b0001;
localparam LIST_READ_WAIT       = 4'b0010;
localparam LIST_CHECK_FIFO      = 4'b0100;
localparam LIST_DATA_WAIT       = 4'b1000;
localparam LIST_READ_DATA       = 4'b1001;

reg[31:0] trigger_width_enable;
wire[31:0] fifo_busy;
reg[31:0] fifo_rd_en;
wire[7:0] fifo_dout[31:0];
wire[5:0] fifo_count[31:0];

reg[3:0] state_list;
reg[15:0] state_list_clk_cnt;
reg[2:0] fifo_rd_cnt;
reg[7:0] state_wait_clk_cnt;

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		state_list <= LIST_CHECK;
        state_list_clk_cnt <= 16'd0;
        state_wait_clk_cnt <= 8'd0;
        fifo_rd_en <= 32'b0;
        fifo_rd_cnt <= 3'b0;
        store_wr_req <= 1'b0;
        trigger_ch <= 8'd0;
        trigger_data <= 8'd0;
        trigger_width_enable = 32'hFFFFFFFF;
	end
    else begin
        if(enable && (mode == 4'b1)) begin
            case(state_list)
                LIST_CHECK: begin
                    case(state_list_clk_cnt)
                        5'd0: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[0] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[0] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[0] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd1: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[1] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[1] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[1] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd2: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[2] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[2] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[2] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd3: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[3] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[3] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[3] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd4: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[4] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[4] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[4] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd5: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[5] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[5] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[5] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd6: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[6] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[6] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[6] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd7: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[7] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[7] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[7] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd8: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[8] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[8] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[8] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd9: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[9] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[9] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[9] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd10: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[10] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[10] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[10] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd11: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[11] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[11] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[11] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd12: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[12] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[12] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[12] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd13: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[13] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[13] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[13] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd14: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[14] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[14] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[14] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd15: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[15] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[15] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[15] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd16: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[16] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[16] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[16] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd17: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[17] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[17] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[17] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd18: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[18] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[18] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[18] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd19: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[19] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[19] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[19] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd20: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[20] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[20] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[20] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd21: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[21] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[21] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[21] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd22: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[22] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[22] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[22] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd23: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[23] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[23] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[23] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd24: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[24] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[24] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[24] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd25: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[25] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[25] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[25] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd26: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[26] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[26] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[26] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd27: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[27] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[27] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[27] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd28: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[28] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[28] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[28] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd29: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[29] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[29] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[29] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd30: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[30] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[30] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[30] <= 1'b1;
                                state_list_clk_cnt <= state_list_clk_cnt + 1'b1;
                            end
                        end
                        5'd31: begin     // channel 0
                            // if fifo has data, save all the data.
                            if(fifo_count[31] > 1'b0) begin
                                // request the total store fifo to save data.
                                trigger_width_enable[31] <= 1'b0;
                                store_wr_req <= 1'b1;
                                state_list <= LIST_READ_WAIT;
                            end
                            else begin
                                trigger_width_enable[31] <= 1'b1;
                                state_list_clk_cnt <= 16'd0;
                            end
                        end
                    endcase
                end
                LIST_READ_WAIT: begin
                    if(store_wr_ack) begin
                        store_wr_req <= 1'b0;
                        state_list <= LIST_CHECK_FIFO;
                    end
                    // if 32 clock timeout, reset the state.
                    else if(state_wait_clk_cnt >= 5'd31) begin
                        state_wait_clk_cnt <= 8'd0;
                        store_wr_req <= 1'b0;
                        state_list <= LIST_CHECK;
                    end
                    else 
                        state_wait_clk_cnt <= state_wait_clk_cnt + 1'b1;
                end
                LIST_CHECK_FIFO: begin
                    case(state_list_clk_cnt)
                        5'd0:  begin
                            if(fifo_busy[0] == 1'b0) begin 
                                fifo_rd_en[0]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd1:  begin
                            if(fifo_busy[1] == 1'b0) begin 
                                fifo_rd_en[1]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd2:  begin
                            if(fifo_busy[2] == 1'b0) begin 
                                fifo_rd_en[2]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd3:  begin
                            if(fifo_busy[3] == 1'b0) begin 
                                fifo_rd_en[3]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd4:  begin
                            if(fifo_busy[4] == 1'b0) begin 
                                fifo_rd_en[4]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd5:  begin
                            if(fifo_busy[5] == 1'b0) begin 
                                fifo_rd_en[5]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd6:  begin
                            if(fifo_busy[6] == 1'b0) begin 
                                fifo_rd_en[6]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd7:  begin
                            if(fifo_busy[7] == 1'b0) begin 
                                fifo_rd_en[7]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd8:  begin
                            if(fifo_busy[8] == 1'b0) begin 
                                fifo_rd_en[8]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd9:  begin
                            if(fifo_busy[9] == 1'b0) begin 
                                fifo_rd_en[9]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd10:  begin
                            if(fifo_busy[10] == 1'b0) begin 
                                fifo_rd_en[10]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd11:  begin
                            if(fifo_busy[11] == 1'b0) begin 
                                fifo_rd_en[11]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd12:  begin
                            if(fifo_busy[12] == 1'b0) begin 
                                fifo_rd_en[12]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd13:  begin
                            if(fifo_busy[13] == 1'b0) begin 
                                fifo_rd_en[13]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd14:  begin
                            if(fifo_busy[14] == 1'b0) begin 
                                fifo_rd_en[14]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd15:  begin
                            if(fifo_busy[15] == 1'b0) begin 
                                fifo_rd_en[15]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd16:  begin
                            if(fifo_busy[16] == 1'b0) begin 
                                fifo_rd_en[16]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd17:  begin
                            if(fifo_busy[17] == 1'b0) begin 
                                fifo_rd_en[17]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd18:  begin
                            if(fifo_busy[18] == 1'b0) begin 
                                fifo_rd_en[18]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd19:  begin
                            if(fifo_busy[19] == 1'b0) begin 
                                fifo_rd_en[19]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd20:  begin
                            if(fifo_busy[20] == 1'b0) begin 
                                fifo_rd_en[20]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd21:  begin
                            if(fifo_busy[21] == 1'b0) begin 
                                fifo_rd_en[21]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd22:  begin
                            if(fifo_busy[22] == 1'b0) begin 
                                fifo_rd_en[22]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd23:  begin
                            if(fifo_busy[23] == 1'b0) begin 
                                fifo_rd_en[23]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd24:  begin
                            if(fifo_busy[24] == 1'b0) begin 
                                fifo_rd_en[24]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd25:  begin
                            if(fifo_busy[25] == 1'b0) begin 
                                fifo_rd_en[25]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd26:  begin
                            if(fifo_busy[26] == 1'b0) begin 
                                fifo_rd_en[26]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd27:  begin
                            if(fifo_busy[27] == 1'b0) begin 
                                fifo_rd_en[27]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd28:  begin
                            if(fifo_busy[28] == 1'b0) begin 
                                fifo_rd_en[28]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd29:  begin
                            if(fifo_busy[29] == 1'b0) begin 
                                fifo_rd_en[29]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd30:  begin
                            if(fifo_busy[30] == 1'b0) begin 
                                fifo_rd_en[30]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                        5'd31:  begin
                            if(fifo_busy[31] == 1'b0) begin 
                                fifo_rd_en[31]  <= 1'b1;
                                state_list <= LIST_DATA_WAIT;
                            end
                        end
                    endcase
                    fifo_rd_cnt <= 1'b1;
                end
                LIST_DATA_WAIT: begin
                    state_list <= LIST_READ_DATA;
                end
                LIST_READ_DATA: begin
                    // trigger channel is the clock counts in check state.
                    trigger_ch <= state_list_clk_cnt;
                    // now the width is valid.
                    case(state_list_clk_cnt)
                        5'd0:  trigger_data <= fifo_dout[0] ;
                        5'd1:  trigger_data <= fifo_dout[1] ;
                        5'd2:  trigger_data <= fifo_dout[2] ;
                        5'd3:  trigger_data <= fifo_dout[3] ;
                        5'd4:  trigger_data <= fifo_dout[4] ;
                        5'd5:  trigger_data <= fifo_dout[5] ;
                        5'd6:  trigger_data <= fifo_dout[6] ;
                        5'd7:  trigger_data <= fifo_dout[7] ;
                        5'd8:  trigger_data <= fifo_dout[8] ;
                        5'd9:  trigger_data <= fifo_dout[9] ;
                        5'd10: trigger_data <= fifo_dout[10];
                        5'd11: trigger_data <= fifo_dout[11];
                        5'd12: trigger_data <= fifo_dout[12];
                        5'd13: trigger_data <= fifo_dout[13];
                        5'd14: trigger_data <= fifo_dout[14];
                        5'd15: trigger_data <= fifo_dout[15];
                        5'd16: trigger_data <= fifo_dout[16];
                        5'd17: trigger_data <= fifo_dout[17];
                        5'd18: trigger_data <= fifo_dout[18];
                        5'd19: trigger_data <= fifo_dout[19];
                        5'd20: trigger_data <= fifo_dout[20];
                        5'd21: trigger_data <= fifo_dout[21];
                        5'd22: trigger_data <= fifo_dout[22];
                        5'd23: trigger_data <= fifo_dout[23];
                        5'd24: trigger_data <= fifo_dout[24];
                        5'd25: trigger_data <= fifo_dout[25];
                        5'd26: trigger_data <= fifo_dout[26];
                        5'd27: trigger_data <= fifo_dout[27];
                        5'd28: trigger_data <= fifo_dout[28];
                        5'd29: trigger_data <= fifo_dout[29];
                        5'd30: trigger_data <= fifo_dout[30];
                        5'd31: trigger_data <= fifo_dout[31];
                    endcase
                    case(fifo_rd_cnt)
                        3'b001,3'b010: begin
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                        3'b011: begin
                            // The fifo data delay 1 clock. So 4byte has been read.
                            case(state_list_clk_cnt)
                                5'd0:  fifo_rd_en[0]  <= 1'b0;
                                5'd1:  fifo_rd_en[1]  <= 1'b0;
                                5'd2:  fifo_rd_en[2]  <= 1'b0;
                                5'd3:  fifo_rd_en[3]  <= 1'b0;
                                5'd4:  fifo_rd_en[4]  <= 1'b0;
                                5'd5:  fifo_rd_en[5]  <= 1'b0;
                                5'd6:  fifo_rd_en[6]  <= 1'b0;
                                5'd7:  fifo_rd_en[7]  <= 1'b0;
                                5'd8:  fifo_rd_en[8]  <= 1'b0;
                                5'd9:  fifo_rd_en[9]  <= 1'b0;
                                5'd10: fifo_rd_en[10] <= 1'b0;
                                5'd11: fifo_rd_en[11] <= 1'b0;
                                5'd12: fifo_rd_en[12] <= 1'b0;
                                5'd13: fifo_rd_en[13] <= 1'b0;
                                5'd14: fifo_rd_en[14] <= 1'b0;
                                5'd15: fifo_rd_en[15] <= 1'b0;
                                5'd16: fifo_rd_en[16] <= 1'b0;
                                5'd17: fifo_rd_en[17] <= 1'b0;
                                5'd18: fifo_rd_en[18] <= 1'b0;
                                5'd19: fifo_rd_en[19] <= 1'b0;
                                5'd20: fifo_rd_en[20] <= 1'b0;
                                5'd21: fifo_rd_en[21] <= 1'b0;
                                5'd22: fifo_rd_en[22] <= 1'b0;
                                5'd23: fifo_rd_en[23] <= 1'b0;
                                5'd24: fifo_rd_en[24] <= 1'b0;
                                5'd25: fifo_rd_en[25] <= 1'b0;
                                5'd26: fifo_rd_en[26] <= 1'b0;
                                5'd27: fifo_rd_en[27] <= 1'b0;
                                5'd28: fifo_rd_en[28] <= 1'b0;
                                5'd29: fifo_rd_en[29] <= 1'b0;
                                5'd30: fifo_rd_en[30] <= 1'b0;
                                5'd31: fifo_rd_en[31] <= 1'b0;
                            endcase
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                        3'b100: begin
                            fifo_rd_cnt <= 2'b0;
                            state_list <= LIST_CHECK;
                        end
                    endcase
                end
            endcase   
        end
        else begin
            trigger_width_enable = 32'h00000000;
        end
    end
end

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width0
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[0]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[0]),    // posedge of trigger signal.
    .din_negedge(din_negedge[0]),    // negedge of trigger signal.


    .fifo_busy(fifo_busy[0]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[0]),     // fifo read enable.
    .fifo_dout(fifo_dout[0]),      // fifo data output.
    .fifo_data_count(fifo_count[0]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width1
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[1]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[1]),    // posedge of trigger signal.
    .din_negedge(din_negedge[1]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[1]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[1]),     // fifo read enable.
    .fifo_dout(fifo_dout[1]),      // fifo data output.
    .fifo_data_count(fifo_count[1]) // fifo data counts. 
	);
    
trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width2
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[2]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[2]),    // posedge of trigger signal.
    .din_negedge(din_negedge[2]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[2]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[2]),     // fifo read enable.
    .fifo_dout(fifo_dout[2]),      // fifo data output.
    .fifo_data_count(fifo_count[2]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width3
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[3]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[3]),    // posedge of trigger signal.
    .din_negedge(din_negedge[3]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[3]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[3]),     // fifo read enable.
    .fifo_dout(fifo_dout[3]),      // fifo data output.
    .fifo_data_count(fifo_count[3]) // fifo data counts. 
	);
    
trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width4
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[4]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[4]),    // posedge of trigger signal.
    .din_negedge(din_negedge[4]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[4]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[4]),     // fifo read enable.
    .fifo_dout(fifo_dout[4]),      // fifo data output.
    .fifo_data_count(fifo_count[4]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width5
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[5]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[5]),    // posedge of trigger signal.
    .din_negedge(din_negedge[5]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[5]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[5]),     // fifo read enable.
    .fifo_dout(fifo_dout[5]),      // fifo data output.
    .fifo_data_count(fifo_count[5]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width6
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[6]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[6]),    // posedge of trigger signal.
    .din_negedge(din_negedge[6]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[6]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[6]),     // fifo read enable.
    .fifo_dout(fifo_dout[6]),      // fifo data output.
    .fifo_data_count(fifo_count[6]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width7
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[7]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[7]),    // posedge of trigger signal.
    .din_negedge(din_negedge[7]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[7]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[7]),     // fifo read enable.
    .fifo_dout(fifo_dout[7]),      // fifo data output.
    .fifo_data_count(fifo_count[7]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width8
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[8]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[8]),    // posedge of trigger signal.
    .din_negedge(din_negedge[8]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[8]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[8]),     // fifo read enable.
    .fifo_dout(fifo_dout[8]),      // fifo data output.
    .fifo_data_count(fifo_count[8]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width9
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[9]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[9]),    // posedge of trigger signal.
    .din_negedge(din_negedge[9]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[9]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[9]),     // fifo read enable.
    .fifo_dout(fifo_dout[9]),      // fifo data output.
    .fifo_data_count(fifo_count[9]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width10
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[10]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[10]),    // posedge of trigger signal.
    .din_negedge(din_negedge[10]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[10]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[10]),     // fifo read enable.
    .fifo_dout(fifo_dout[10]),      // fifo data output.
    .fifo_data_count(fifo_count[10]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width11
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[11]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[11]),    // posedge of trigger signal.
    .din_negedge(din_negedge[11]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[11]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[11]),     // fifo read enable.
    .fifo_dout(fifo_dout[11]),      // fifo data output.
    .fifo_data_count(fifo_count[11]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width12
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[12]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[12]),    // posedge of trigger signal.
    .din_negedge(din_negedge[12]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[12]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[12]),     // fifo read enable.
    .fifo_dout(fifo_dout[12]),      // fifo data output.
    .fifo_data_count(fifo_count[12]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width13
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[13]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[13]),    // posedge of trigger signal.
    .din_negedge(din_negedge[13]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[13]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[13]),     // fifo read enable.
    .fifo_dout(fifo_dout[13]),      // fifo data output.
    .fifo_data_count(fifo_count[13]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width14
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[14]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[14]),    // posedge of trigger signal.
    .din_negedge(din_negedge[14]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[14]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[14]),     // fifo read enable.
    .fifo_dout(fifo_dout[14]),      // fifo data output.
    .fifo_data_count(fifo_count[14]) // fifo data counts. 
	);
    
trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width15
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[15]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[15]),    // posedge of trigger signal.
    .din_negedge(din_negedge[15]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[15]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[15]),     // fifo read enable.
    .fifo_dout(fifo_dout[15]),      // fifo data output.
    .fifo_data_count(fifo_count[15]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width16
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[16]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[16]),    // posedge of trigger signal.
    .din_negedge(din_negedge[16]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[16]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[16]),     // fifo read enable.
    .fifo_dout(fifo_dout[16]),      // fifo data output.
    .fifo_data_count(fifo_count[16]) // fifo data counts. 
	);
    
trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width17
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[17]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[17]),    // posedge of trigger signal.
    .din_negedge(din_negedge[17]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[17]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[17]),     // fifo read enable.
    .fifo_dout(fifo_dout[17]),      // fifo data output.
    .fifo_data_count(fifo_count[17]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width18
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[18]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[18]),    // posedge of trigger signal.
    .din_negedge(din_negedge[18]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[18]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[18]),     // fifo read enable.
    .fifo_dout(fifo_dout[18]),      // fifo data output.
    .fifo_data_count(fifo_count[18]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width19
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[19]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[19]),    // posedge of trigger signal.
    .din_negedge(din_negedge[19]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[19]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[19]),     // fifo read enable.
    .fifo_dout(fifo_dout[19]),      // fifo data output.
    .fifo_data_count(fifo_count[19]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width20
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[20]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[20]),    // posedge of trigger signal.
    .din_negedge(din_negedge[20]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[20]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[20]),     // fifo read enable.
    .fifo_dout(fifo_dout[20]),      // fifo data output.
    .fifo_data_count(fifo_count[20]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width21
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[21]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[21]),    // posedge of trigger signal.
    .din_negedge(din_negedge[21]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[21]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[21]),     // fifo read enable.
    .fifo_dout(fifo_dout[21]),      // fifo data output.
    .fifo_data_count(fifo_count[21]) // fifo data counts. 
	);


trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width22
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[22]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[22]),    // posedge of trigger signal.
    .din_negedge(din_negedge[22]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[22]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[22]),     // fifo read enable.
    .fifo_dout(fifo_dout[22]),      // fifo data output.
    .fifo_data_count(fifo_count[22]) // fifo data counts. 
	);


trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width23
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[23]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[23]),    // posedge of trigger signal.
    .din_negedge(din_negedge[23]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[23]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[23]),     // fifo read enable.
    .fifo_dout(fifo_dout[23]),      // fifo data output.
    .fifo_data_count(fifo_count[23]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width24
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[24]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[24]),    // posedge of trigger signal.
    .din_negedge(din_negedge[24]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[24]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[24]),     // fifo read enable.
    .fifo_dout(fifo_dout[24]),      // fifo data output.
    .fifo_data_count(fifo_count[24]) // fifo data counts. 
	);


trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width25
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[25]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[25]),    // posedge of trigger signal.
    .din_negedge(din_negedge[25]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[25]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[25]),     // fifo read enable.
    .fifo_dout(fifo_dout[25]),      // fifo data output.
    .fifo_data_count(fifo_count[25]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width26
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[26]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[26]),    // posedge of trigger signal.
    .din_negedge(din_negedge[26]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[26]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[26]),     // fifo read enable.
    .fifo_dout(fifo_dout[26]),      // fifo data output.
    .fifo_data_count(fifo_count[26]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width27
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[27]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[27]),    // posedge of trigger signal.
    .din_negedge(din_negedge[27]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[27]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[27]),     // fifo read enable.
    .fifo_dout(fifo_dout[27]),      // fifo data output.
    .fifo_data_count(fifo_count[27]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width28
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[28]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[28]),    // posedge of trigger signal.
    .din_negedge(din_negedge[28]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[28]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[28]),     // fifo read enable.
    .fifo_dout(fifo_dout[28]),      // fifo data output.
    .fifo_data_count(fifo_count[28]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width29
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[29]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[29]),    // posedge of trigger signal.
    .din_negedge(din_negedge[29]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[29]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[29]),     // fifo read enable.
    .fifo_dout(fifo_dout[29]),      // fifo data output.
    .fifo_data_count(fifo_count[29]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width30
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[30]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[30]),    // posedge of trigger signal.
    .din_negedge(din_negedge[30]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[30]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[30]),     // fifo read enable.
    .fifo_dout(fifo_dout[30]),      // fifo data output.
    .fifo_data_count(fifo_count[30]) // fifo data counts. 
	);

trigger_width #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) trigger_width31
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(trigger_width_enable[31]),         // High valid.
    .sync(sync),                            // synchronization.
    .din_posedge(din_posedge[31]),    // posedge of trigger signal.
    .din_negedge(din_negedge[31]),    // negedge of trigger signal.

    .fifo_busy(fifo_busy[31]),      // busy indicator.
    .fifo_rd_en(fifo_rd_en[31]),     // fifo read enable.
    .fifo_dout(fifo_dout[31]),      // fifo data output.
    .fifo_data_count(fifo_count[31]) // fifo data counts. 
	);

// analyze trigger
endmodule
