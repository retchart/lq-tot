/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * position_store.v: position_store readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
 * Data structure:
 *      pixel data: time(16bit) posA(8bit) posB(8bit)
 *      list data:  time(16bit) trigger_width(16bit) channel(8bit) 
 *          time_beat_counts(24bits)
	******************************************************************************
*/

module position_store
#(
	parameter CLK_FRE = 200,        	//clock frequency(Mhz)
	parameter TIME_STAMP_PERIOD = 5  	//clock period(5 nS)
)
(
	input sys_clk,
	input rst_n,
    
    input[3:0]      mode,                   // 0 - position mode; 1 - list mode.

	input			store_wr_req_A,           // position write request.
    output reg      store_wr_ack_A,           // fifo write complete ack.
    input[7:0]      store_data_A,           // list mode: pulse width
	input			store_wr_en_A,            // fifo write enable.
	input			store_wr_req_B,           // position write request.
    output reg      store_wr_ack_B,           // fifo write complete ack.
    input[7:0]      store_data_B,          // list mode: pulse width
	input			store_wr_en_B,            // fifo write enable.

	input			store_wr_req_pos,           // position write request.
    output reg      store_wr_ack_pos,           // fifo write complete ack.
    input[7:0]      store_data_pos,          // list mode: pulse width
	input			store_wr_en_pos,            // fifo write enable.

    input           store_rd_req,        // fifo read request.
    output reg      store_rd_ack,        // fifo read ack.
	input			store_rd_en,         // fifo read enable.
	output[7:0]		store_dout,          // fifo dout.
	output			store_full,          // fifo full.
	output			store_empty,         // fifo empty.
	output[10:0]	store_data_cnt       // fifo counts.
	);

// mode
localparam  MODE_POS            = 4'h0;
localparam  MODE_LIST           = 4'h1;

// State
localparam	IDLE				= 4'b0000;
localparam	STORE_READ	        = 4'b0001;
localparam	STORE_WRITE_A       = 4'b0010;
localparam	STORE_WRITE_B       = 4'b0100;
localparam	STORE_WRITE_POS     = 4'b1000;

// Store position data
(*mark_debug = "true"*)reg[3:0] state = IDLE;
reg[31:0] clk_cnt = 32'd1;      // clock counts at idle state.
reg[7:0] state_clk_cnt = 8'd0; // used for save data.
reg[7:0] store_din = 8'd0;
reg store_wr_en;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		state <= IDLE;
		store_wr_en <= 1'b0;
        store_wr_ack_A <= 1'b0;
        store_wr_ack_B <= 1'b0;
        store_wr_ack_pos <= 1'b0;
        store_rd_ack <= 1'b0;
	end
	else begin
		case(state)
			IDLE: begin
				store_wr_en <= 1'b0;
                store_wr_ack_A <= 1'b0;
                store_wr_ack_B <= 1'b0;
				state_clk_cnt <= 8'd0;
                // If store full, the store fifo can only be read.
                if(store_rd_req) begin
                    store_rd_ack <= 1'b1;
                    state <= STORE_READ;
                end
                // Check wether store full or not.
                // If store full, the store fifo cannot be write.
                else if(store_data_cnt < (11'd2032)) begin
                    // handle the write request of channel A first.
				    if(store_wr_req_A && (store_rd_en == 1'b0)) begin
				    	// Ackknowledge that the store fifo can be write.
                        store_wr_ack_A <= 1'b1;
                        state <= STORE_WRITE_A;
				    end
                    // handle the write request of channel B second.
				    else if(store_wr_req_B && (store_rd_en == 1'b0)) begin
				    	// Ackknowledge that the store fifo can be write.
                        store_wr_ack_B <= 1'b1;
                        state <= STORE_WRITE_B;
				    end
                    // handle the write request of position data.
				    else if(store_wr_req_pos && (store_rd_en == 1'b0)) begin
				    	// Ackknowledge that the store fifo can be write.
                        store_wr_ack_pos <= 1'b1;
                        state <= STORE_WRITE_POS;
				    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
			end
            STORE_READ: begin
                store_rd_ack <= 1'b0;
                // Wait for read complete. One event stores 8 bytes at lest.
                if((state_clk_cnt > 3'd7) && (store_rd_en == 1'b0)) begin
				    state <= IDLE;
                end
                else begin
				    state_clk_cnt <= state_clk_cnt + 1'b1;
                end
            end
			STORE_WRITE_A: begin
                store_wr_ack_A <= 1'b0;
                // Wait for write complete. One event stores 8 bytes at lest.
                if((state_clk_cnt >= 3'd7) && (store_wr_en == 1'b0)) begin
				    state <= IDLE;
                end
                else begin
                    store_wr_en <= store_wr_en_A;
                    store_din <= store_data_A;
				    state_clk_cnt <= state_clk_cnt + 1'b1;
                end
            end
			STORE_WRITE_B: begin
                store_wr_ack_B <= 1'b0;
                // Wait for write complete. One event stores 8 bytes at lest.
                if((state_clk_cnt >= 3'd7) && (store_wr_en == 1'b0)) begin
				    state <= IDLE;
                end
                else begin
                    store_wr_en <= store_wr_en_B;
                    store_din <= store_data_B;
				    state_clk_cnt <= state_clk_cnt + 1'b1;
                end
            end
			STORE_WRITE_POS: begin
                store_wr_ack_pos <= 1'b0;
                // Wait for write complete. One event stores 8 bytes at lest.
                if((state_clk_cnt >= 3'd7) && (store_wr_en == 1'b0)) begin
				    state <= IDLE;
                end
                else begin
                    store_wr_en <= store_wr_en_pos;
                    store_din <= store_data_pos;
				    state_clk_cnt <= state_clk_cnt + 1'b1;
                end
            end
			default: begin
				store_wr_en <= 1'b0;
                store_din <= 8'd0;
				state <= IDLE;
			end
		endcase
	end
end

// System clock divided into shift clock and adc clock.
fifo_list_data fifo_list_data_inst(
  .clk(sys_clk),
  .srst(~rst_n),
  .din(store_din),
  .wr_en(store_wr_en),
  .rd_en(store_rd_en),
  .dout(store_dout),
  .full(store_full),
  .empty(store_empty),
  .data_count(store_data_cnt)
);

endmodule
