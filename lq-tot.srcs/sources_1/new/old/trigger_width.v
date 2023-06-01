/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * trigger_width.v: trigger_width analysis.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
 * trigger pulse width's unit is clock period (5ns). The max pulse width is 
 *      16384 * 5 = 81920 ns.
 * event list frame is: trigger_time[15:8], trigger_time[7:0], 
 *      width[13:8], width[7:0].
	******************************************************************************
*/

module trigger_width
#(
	parameter CLK_FRE = 200,            //clock frequency(Mhz)
	parameter TIME_STAMP_PERIOD = 5  	//clock period(5 nS)
)
(
	input				sys_clk,
	input				rst_n,

	input				enable,         // High valid.
    input               sync,           // sychronization.
    input               din_posedge,    // posedge of trigger signal.
    input               din_negedge,    // negedge of trigger signal.

    output reg          fifo_busy,      // busy indicator.
    input               fifo_rd_en,     // fifo read enable.
    output[7:0]         fifo_dout,      // fifo data output.
    output[5:0]         fifo_data_count // fifo data counts.       
	);

// pulse width's unit cycle.
localparam	CYCLE_TIME_STAMP 	    = CLK_FRE * TIME_STAMP_PERIOD / 1000;

// Total pulse height spectrum channels.
localparam	WIDTH_CHANNELS		    = 14'd16383;

// synchronization buffer. 3 clock to avoid jitter.
reg[2:0] sync_buf;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		sync_buf <= 3'd0;
	end
    else begin
        sync_buf[0] <= sync;
        sync_buf[1] <= sync_buf[0];
        sync_buf[2] <= sync_buf[1];
    end
end

wire sync_posedge;
assign sync_posedge = (~sync_buf[2]) & sync_buf[1];

// Time stamp.
reg[15:0] time_sys_clk_cnt;
reg[15:0] time_stamp;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
        time_sys_clk_cnt <= 16'd0;
		time_stamp <= 16'b0;
	end
	else begin
		if(time_sys_clk_cnt >= CYCLE_TIME_STAMP - 1'b1) begin
            time_sys_clk_cnt <= 16'd0;
            time_stamp <= time_stamp + 1'b1;
		end
        else if(sync_posedge) begin
            time_sys_clk_cnt <= 16'd0;
		    time_stamp <= 16'b0;
        end
		else if(enable) begin
			time_sys_clk_cnt <= time_sys_clk_cnt + 1'b1;
		end
	end
end

// trigger state
localparam	IDLE		= 2'b00;
localparam	TRIGGER		= 2'b01;
localparam	WAIT		= 2'b10;
localparam	END			= 2'b11;

// trigger pos analysis in list mode.
reg[1:0] state;
reg[15:0] trigger_time;
reg[13:0] trigger_width;
reg[16:0] state_clk_cnt;
reg[1:0] wait_cnt;
reg[7:0] fifo_din;
reg fifo_wr_en;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
        state <= IDLE;
        trigger_time <= 16'd0;
        state_clk_cnt <= 16'd0;
        trigger_width <= 14'd0;
        fifo_busy <= 1'b0;
        fifo_din <= 8'd0;
        fifo_wr_en <= 1'b0;
        wait_cnt <= 2'b0;
    end
    else begin
        case(state)
            IDLE: begin
				state_clk_cnt <= 16'd0;
				if(din_posedge && enable) begin
                    // record the trigger time.
                    trigger_time <= time_stamp;
                    trigger_width <= 14'd0;
                    state_clk_cnt <= 16'd0;
					state <= TRIGGER;
				end
            end
            TRIGGER: begin
                if(din_negedge) begin
                    state_clk_cnt <= 16'd0;
                    // set busy flag ahead of write.
                    fifo_busy <= 1'b1;
                    state <= WAIT;
                end
                else begin
                    if(state_clk_cnt == CYCLE_TIME_STAMP - 1'b1) begin
                        state_clk_cnt <= 16'd0;
                        // trigger width add.
                        if(trigger_width < WIDTH_CHANNELS) begin
                            trigger_width <= trigger_width + 1'b1;
                        end
                    end
                    else
                        state_clk_cnt <= state_clk_cnt + 1'b1;
                end
            end
            WAIT: begin
                // Check fifo can store one event.
                // fifo_data_count < 32 - 2 - 4 = 26
                if(~fifo_rd_en && fifo_data_count < 5'd26) begin
                    case(wait_cnt)
                        2'b00: begin
                            fifo_din <= trigger_time[15:8];
                            fifo_wr_en <= 1'b1;
                            wait_cnt <= wait_cnt + 1'b1;
                        end
                        2'b01:begin
                            fifo_din <= trigger_time[7:0];
                            fifo_wr_en <= 1'b1;
                            wait_cnt <= wait_cnt + 1'b1;
                        end
                        2'b10:begin
                            fifo_din <= {2'b00,trigger_width[13:8]};
                            fifo_wr_en <= 1'b1;
                            wait_cnt <= wait_cnt + 1'b1;
                        end
                        2'b11:begin
                            fifo_din <= trigger_width[7:0];
                            fifo_wr_en <= 1'b1;
                            wait_cnt <= 2'b00;
                            state <= END;
                        end
                    endcase
                end
                else begin
                    fifo_wr_en <= 1'b0;
                    state <= END;
                end
            end
            END: begin
                trigger_width <= 14'b0;
                fifo_wr_en <= 1'b0;
                fifo_busy <= 1'b0;
                state <= IDLE;
            end
        endcase
    end
end

trigger_width_fifo trigger_width_fifo_inst (
  .clk(sys_clk),                    // input wire clk
  .srst(~rst_n),                     // input wire srst
  .din(fifo_din),                   // input wire [7 : 0] din
  .wr_en(fifo_wr_en),               // input wire wr_en
  .rd_en(fifo_rd_en),               // input wire rd_en
  .dout(fifo_dout),                 // output wire [7 : 0] dout
  .full(),                          // output wire full
  .almost_full(fifo_full),          // output wire full
  .empty(fifo_empty),               // output wire empty
  .data_count(fifo_data_count)      // output wire [5 : 0] data_count
);

// analyze trigger
endmodule
