/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * core_udp.v: core readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
	******************************************************************************
*/
/* Command List
        The BHCND command Packets format is "$ Address CMD_MSB CMD_LSB LEN_MSB
    LEN_LSB (*Data*) CHKSUM \n"
        The parameter is:
            ** 0x00 - 0x10
            2 bytes -- name
            4 bytes -- ip
            1 bytes -- mode(4 MSB: 0 - gate off; 1 - gate on;
                4 LSB: 0-pixel data; 1-list data)
            1 bytes -- channel
            2 bytes -- anode high voltage
            2 bytes -- lthd of anode
            2 bytes -- lthd of cathode
            1 byte  -- coin_time of anode (unit is 0.1us. The range is 0.1 - 1.6us.)
            1 byte  -- coin_time of cathode (unit is 0.1us. The range is 0.1 - 3.2us.)
            ** 0x10 -- 0x20
            2 bytes -- corse gain (not used)
            2 bytes -- fine gain (not used)
            2 bytes -- shapping time
            2 bytes -- unused
            2 bytes -- unused
            2 bytes -- unused
            2 bytes -- unused
            2 bytes -- unused

    Discover    		2400 0101 0000 24 0A
                            2400 0100 0010 (Settings) ** 0A
    Start       		2400 0103 0000 26 0A
                            ACK
    Stop        		2400 0102 0000 27 0A
                            ACK
    Set settings        2400 0105 0010 (settings) ** 0A
                            ACK
    Get data            2400 0301 0000 22 0A
                            pos data

    ACK List
        The BHCND acknowledge packets format is "$ Address CMD_MSB CMD_LSB
    LEN_MSB LEN_LSB (*Data*) CHKBIT 0A"
    Ok                  2400 FF00 0000 DB 0A
    Command Error       2400 FF01 0000 DA 0A
    Length Error        2400 FF02 0000 D9 0A
    Checksum Error      2400 FF03 0000 D8 0A

    Data List
        The MWPC data packets format is "$ Address TYPE_MSB TYPE_LSB
    LEN_MSB LEN_LSB (*data*) CHKBIT 0A"
    pixel data  		2400 0200 **** (data) ** 0A	(pixel)
    list data           2400 0201 **** (data) ** 0A	(list)

    Data structure:
    pixel data: time(32bit) posA(32bit) posB(32bit)
    list data:  time(16bit) phs(8bit) channel(8bit)
*/

module core_udp
#(
	parameter CLK_FRE               = 200,   //clock frequency(Mhz)
    parameter PHS_CHANNELS          = 1024   // phs channels.
)
(
	input sys_clk,
	input rst_n,
    input                   modbus_ready,

    input                   rx_frame_valid,
    input [7:0]             rx_fifo_dout,
    output reg              rx_fifo_rd_en,
    input [10:0]            rx_fifo_cnt,

    output reg              tx_frame_valid,
    output reg[7:0]         tx_fifo_din,
    output reg              tx_fifo_wr_en,
    input                   tx_fifo_busy,
    input                   tx_fifo_full,
 
	input			        gate,
    // input                   sync,
    (*mark_debug = "true"*)output reg              enable,

    output reg[15:0]        s_name,
    output reg[31:0]        s_ip,
    (*mark_debug = "true"*)output reg[7:0]         s_mode,
    output reg[7:0]         s_channel,
    output reg[15:0]        s_hv,
    output reg[15:0]        s_lthd_a,
    output reg[15:0]        s_lthd_b,
    output reg[7:0]         s_coin_time_a,
    output reg[7:0]         s_coin_time_b,

    output reg              store_rd_req,
    input                   store_rd_ack,
	output reg   			store_rd_en,
	input[7:0]		        store_dout,
	input			        store_full,
	input			        store_empty,
	(*mark_debug = "true"*)input[10:0]	            store_data_cnt,

	output reg		        phs_rd_req,
	output reg[9:0]		    phs_rd_addr,
	input			        phs_rd_busy,
	input[31:0]	            phs_out
);

// Calculates the clock cycle for baud rate 
// Delay 500mS clcok cycles.
localparam	DELAY_CYCLE   = CLK_FRE * 3000000; 
// Send data to host every 50mS.
// localparam	SEND_PERIOD_CYCLE   = CLK_FRE * 100;   // 100 us used for simulation.
localparam	SEND_PERIOD_CYCLE   = CLK_FRE * 50000; 
// The default local address is 0x00.
localparam  LOCAL_ADDRESS       = 8'h00;

// Command define
localparam  CMD_DISCOVER            = 16'h0101;
localparam  CMD_RESPONSE            = 16'h0100;
localparam  CMD_START               = 16'h0103;
localparam  CMD_STOP                = 16'h0102;
localparam  CMD_SET_SETTINGS        = 16'h0105;
localparam  CMD_GET_DATA            = 16'h0301;
localparam  CMD_POS_DATA            = 16'h0200;
localparam  CMD_LIST_DATA           = 16'h0201;
localparam  CMD_ACK_OK              = 16'hFF00;
localparam  CMD_ACK_ERROR           = 16'hFF01;

// 4 MSB: gate on or gate off;
// 4 LSB: 0-pixel data; 1-phs data; 2-list data)
localparam  MODE_GATE_MASK           = 8'hF0;
localparam  MODE_DATA_MASK           = 8'h0F;
localparam  MODE_GATE_OFF            = 4'h0;
localparam  MODE_GATE_ON             = 4'h1;
localparam  MODE_POS                 = 4'h0;
localparam  MODE_LIST                = 4'h1;

// delay a while when power on to wait for pheriphertial.
(*mark_debug = "true"*)reg s_enable = 1'b1;
reg[31:0] delay_cnt = 32'd0;
initial enable = 1'b1;      // Initial is 1 for simulation and 0 for other.
always@(posedge sys_clk) begin
    if(delay_cnt < DELAY_CYCLE - 1'b1) begin
        delay_cnt <= delay_cnt + 1'b1;
	end
	else begin
        enable <= (!(!gate && s_mode[7:4])) && modbus_ready && s_enable;
    end
end


// Receive state
localparam	RX_IDLE				= 4'b0000;
localparam  READ_DELAY          = 4'b0001;
localparam  READ_HEADER         = 4'b0010;
localparam  READ_COMMAND        = 4'b0011;
localparam  READ_LENGTH         = 4'b0100;
localparam  READ_DATA           = 4'b0101;
localparam  READ_END            = 4'b0110;
localparam  RX_END              = 4'b0111;

// system state
(*mark_debug = "true"*)reg[3:0] rx_state;
(*mark_debug = "true"*)reg[7:0] rx_sys_clk_cnt = 8'd0;
wire rx_frame_valid_posedge;
reg[15:0] rx_cnt = 16'd0;
reg[7:0] rx_header = 8'h0;
reg[7:0] rx_address = 8'h0;
reg[15:0] rx_command = 16'h00;
reg[15:0] rx_data_length = 16'd0;
reg[7:0] rx_checksum = 8'h0;
reg[7:0] rx_frame_end = 8'h0;
reg return = 1'b0;
initial begin
    s_enable <= 1'b1;
    s_name <= {"A", "A"};
    s_ip <= 32'hC0A80002;
    s_mode <= {MODE_GATE_OFF, MODE_LIST};
    s_channel <= 8'd0;        
    s_hv <= 16'd1100;
    s_lthd_a <= 16'd320;    // The unit is 0.625ns. So lthd = 200ns.
    s_lthd_b <= 16'd320;    // The unit is 0.625ns. So lthd = 200ns.
    s_coin_time_a <= 8'd100;    // The unit is 5 ns. So coin time = 500ns.
    s_coin_time_b <= 8'd100;    // The unit is 5 ns. So coin time = 500ns.
end

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		rx_state <= RX_IDLE;
        rx_fifo_rd_en <= 1'b0;
        return <= 1'b0;
	end
	else begin
        case(rx_state)
            RX_IDLE: begin
                if(rx_frame_valid_posedge) begin
                    rx_fifo_rd_en <= 1'b1;
                    rx_sys_clk_cnt <= 8'b0;
                    rx_cnt <= rx_fifo_cnt;
                    // fifo out is 1 clock delay compare to rd_en, and 2 clocks
                    // delay compare to rx_frame_come.
                    rx_state <= READ_DELAY; 
                end
            end
            READ_DELAY: begin
                rx_state <= READ_HEADER;
            end
            READ_HEADER: begin
                case(rx_sys_clk_cnt)
                    8'd0: begin
                        rx_header = rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                    end
                    8'd1: begin
                        rx_address <= rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_COMMAND;
                    end
                endcase
            end
            READ_COMMAND: begin
                case(rx_sys_clk_cnt)
                    8'd0: begin
                        rx_command[15:8] = rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                    end
                    8'd1: begin
                        rx_command[7:0] <= rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_LENGTH;
                    end
                    default: begin
                        rx_sys_clk_cnt <= 8'd0;
                    end
                endcase
            end
            READ_LENGTH: begin
                case(rx_sys_clk_cnt)
                    8'd0: begin
                        rx_data_length[15:8] = rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                    end
                    8'd1: begin
                        rx_data_length[7:0] <= rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_DATA;
                    end
                endcase
            end
            READ_DATA:begin
                case(rx_command)
                    CMD_DISCOVER: begin
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_END;
                    end
                    CMD_START: begin     // Start
                        s_enable <= 1'b1;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_END;
                    end
                    CMD_STOP: begin     // Stop
                        s_enable <= 1'b0;
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_END;
                    end
                    CMD_SET_SETTINGS: begin
                        case(rx_sys_clk_cnt)
                            8'd0: begin
                                s_name[15:8] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd1: begin
                                s_name[7:0] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd2: begin
                                s_ip[31:24] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd3: begin
                                s_ip[23:16] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd4: begin
                                s_ip[15:8] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd5: begin
                                s_ip[7:0] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd6: begin
                                s_mode = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd7: begin
                                s_channel = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd8: begin
                                s_hv[15:8] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd9: begin
                                s_hv[7:0] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd10: begin
                                s_lthd_a[15:8] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd11: begin
                                s_lthd_a[7:0] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd12: begin
                                s_lthd_b[15:8] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd13: begin
                                s_lthd_b[7:0] = rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd14: begin
                                s_coin_time_a <= rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                            end
                            8'd15: begin
                                s_coin_time_b <= rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                                rx_sys_clk_cnt <= 1'b0;
                                rx_state <= READ_END;
                            end
                        endcase
                    end
                    CMD_GET_DATA: begin     // get position data.
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_END;
                    end
                    default: begin
                        rx_fifo_rd_en <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= READ_END;
                        
                    end
                endcase
            end
            READ_END: begin
                case(rx_sys_clk_cnt)
                    8'd0: begin
                        rx_checksum = rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b0;
                        rx_sys_clk_cnt <= rx_sys_clk_cnt + 1'b1;
                    end
                    8'd1: begin
                        rx_frame_end <= rx_fifo_dout;
                        rx_fifo_rd_en <= 1'b0;
                        // set the return back signal.
                        return <= 1'b1;
                        rx_sys_clk_cnt <= 1'b0;
                        rx_state <= RX_END;
                    end
                endcase
            end
            RX_END: begin
                // reset the return flag.
                return <= 1'b0;
                // Clear fifo buffer.
                if(rx_fifo_cnt > 1'b0) begin
                    rx_fifo_rd_en <= 1'b1;
                end
                else begin
                    rx_fifo_rd_en <= 1'b0;
                    rx_state <= RX_IDLE;
                end
            end
        endcase
    end
end

// rx frame data valid needs two clock buffer to avoid error between two clocks.
reg[1:0] rx_frame_valid_buf = 2'b0;
always @(posedge sys_clk or negedge rst_n)
begin
    if(~rst_n) begin
        rx_frame_valid_buf[0] <= 1'b0;
        rx_frame_valid_buf[1] <= 1'b0;
    end
    else begin
        rx_frame_valid_buf[0] <= rx_frame_valid;
        rx_frame_valid_buf[1] <= rx_frame_valid_buf[0];
    end
end

assign rx_frame_valid_posedge = ~rx_frame_valid_buf[1] & rx_frame_valid_buf[0];

// get the positive edge of return signal.
reg return_buf;
wire posedge_return;
always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		return_buf <= 1'b0;
	end
	else begin
		return_buf <= return;
	end
end
assign posedge_return = ~return_buf & return;

// Transmit state
localparam	TX_IDLE				= 4'b0000;
localparam  SEND_DELAY          = 4'b0001;
localparam  SEND_HEADER         = 4'b0010;
localparam  SEND_COMMAND        = 4'b0100;
localparam  SEND_LENGTH         = 4'b1000;
localparam  SEND_DATA_WAIT      = 4'b1001;
localparam  SEND_DATA_DELAY     = 4'b1010;
localparam  SEND_DATA           = 4'b1100;
localparam  SEND_END            = 4'b1101;
localparam  TX_END              = 4'b1110;

// system state
(*mark_debug = "true"*)reg[3:0] tx_state;
(*mark_debug = "true"*)reg[31:0] tx_sys_clk_cnt = 32'd0;
reg[15:0] tx_cnt = 16'd0;
reg[7:0] tx_header = 8'h0;
reg[7:0] tx_address = 8'h0;
reg[15:0] tx_command = 8'h0;
reg[15:0] tx_data_length = 16'd0;
reg[7:0] tx_data[0:15];
reg[7:0] tx_checksum = 8'h00;
reg[7:0] tx_frame_end = 8'h00;
// reg tx_frame_valid;

always@(posedge sys_clk or negedge rst_n)
begin
	if(rst_n == 1'b0) begin
		tx_state <= TX_IDLE;
        store_rd_req <= 1'b0;
        store_rd_en <= 1'b0;
        tx_frame_valid <= 1'b0;
        tx_fifo_din <= 8'd0;
        tx_fifo_wr_en <= 1'b0;
	end
	else begin
        case(tx_state)
            TX_IDLE: begin
                tx_frame_valid <= 1'b0;
                // Response to received command.
                if(posedge_return == 1'b1) begin
                    tx_header <= 8'h24;
                    tx_address <= 8'h00;
                    case(rx_command)
                        CMD_DISCOVER: begin
                            tx_command[15:8] <= 8'h01;
                            tx_command[7:0] <= 8'h00;
                            tx_data_length[15:8] <= 8'h00;
                            tx_data_length[7:0] <= 8'h10;
                            tx_data[0] <= s_name[15:8];
                            tx_data[1] <= s_name[7:0];
                            tx_data[2] <= s_ip[31:24];
                            tx_data[3] <= s_ip[23:16];
                            tx_data[4] <= s_ip[15:8];
                            tx_data[5] <= s_ip[7:0];
                            tx_data[6] <= s_mode;
                            tx_data[7] <= s_channel;
                            tx_data[8] <= s_hv[15:8];
                            tx_data[9] <= s_hv[7:0];
                            tx_data[10] <= s_lthd_a[15:8];
                            tx_data[11] <= s_lthd_a[7:0];
                            tx_data[12] <= s_lthd_b[15:8];
                            tx_data[13] <= s_lthd_b[7:0];
                            tx_data[14] <= s_coin_time_a;
                            tx_data[15] <= s_coin_time_b;
                            tx_checksum <= 8'h0A; // dummy value
                        end
                        // Start. Return ACK.
                        CMD_START: begin
                            tx_command[15:8] <= 8'hFF;
                            tx_command[7:0] <= 8'h00;
                            tx_data_length[15:8] <= 8'h00;
                            tx_data_length[7:0] <= 8'h00;
                            tx_checksum <= 8'hDB;
                        end
                        // Stop. Return ACK.
                        CMD_STOP: begin
                            tx_command[15:8] <= 8'hFF;
                            tx_command[7:0] <= 8'h00;
                            tx_data_length[15:8] <= 8'h00;
                            tx_data_length[7:0] <= 8'h00;
                            tx_checksum <= 8'hDB;
                        end
                        // Set settings. Return ACK.
                        CMD_SET_SETTINGS: begin
                            tx_command[15:8] <= 8'hFF;
                            tx_command[7:0] <= 8'h00;
                            tx_data_length[15:8] <= 8'h00;
                            tx_data_length[7:0] <= 8'h00;
                            tx_checksum <= 8'hDB;
                        end
                        CMD_GET_DATA:begin
                            tx_command[15:8] <= 8'h02;
                            tx_command[7:0] <= {4'h0, s_mode[3:0]};
                            if(store_data_cnt >= 11'd1024)
                                tx_data_length <= 12'd1024;
                            else
                                // every event uses 8bytes.
                                tx_data_length <= (store_data_cnt&16'hFFF8);
                            tx_checksum <= 8'hDB;
                        end
                        // Default. Return ACK.
                        default: begin
                            tx_command[15:8] <= 8'hFF;
                            tx_command[7:0] <= 8'h00;
                            tx_data_length[15:8] <= 8'h00;
                            tx_data_length[7:0] <= 8'h00;
                            tx_checksum <= 8'hDB;
                        end
                    endcase
                    tx_frame_end <= 8'h0A;
                    tx_sys_clk_cnt <= 32'd0;
                    tx_state <= SEND_HEADER;
                end
                // Transmit data when timeout or fifo larger than 1.2kB 
                // (4 * 256 position data or 8 * 128 list data).
                else if((store_data_cnt >= 11'd1024) 
                    || (tx_sys_clk_cnt > SEND_PERIOD_CYCLE - 1'b1)) begin
                    tx_header <= 8'h24;
                    tx_address <= 8'h00;
                    tx_command[15:8] <= 8'h02;
                    tx_command[7:0] <= {4'h0, s_mode[3:0]};
                            if(store_data_cnt >= 11'd1024)
                                tx_data_length <= 11'd1024;
                            else
                                tx_data_length <= (store_data_cnt&16'hFFF8);

                    tx_frame_end <= 8'h0A;
                    tx_sys_clk_cnt <= 32'd0;
                    tx_state <=SEND_HEADER;
                end
                else if(s_enable == 1'b1) begin
                    tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                end
            end
            SEND_HEADER:begin
		    	case(tx_sys_clk_cnt)
		    		16'd0: begin
		    			tx_fifo_din <= tx_header;
                        if(tx_fifo_full == 0 && tx_fifo_busy == 1'b0) begin
		    			    tx_fifo_wr_en <= 1'b1;
		    			    tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                        end
		    		end
		    		16'd1: begin
		    			tx_fifo_din <= tx_address;
		    			tx_fifo_wr_en <= 1'b1;
		    			tx_sys_clk_cnt <= 32'd0;
                        tx_state <= SEND_COMMAND;
		    		end
                endcase
            end
            SEND_COMMAND:begin
		    	case(tx_sys_clk_cnt)
		    		16'd0: begin
		    			tx_fifo_din <= tx_command[15:8];
		    			tx_fifo_wr_en <= 1'b1;
		    			tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
		    		end
		    		16'd1: begin
		    			tx_fifo_din <= tx_command[7:0];
		    			tx_fifo_wr_en <= 1'b1;
		    			tx_sys_clk_cnt <= 32'd0;
                        tx_state <= SEND_LENGTH;
		    		end
                endcase
            end
            SEND_LENGTH: begin
		    	case(tx_sys_clk_cnt)
		    		16'd0: begin
		    			tx_fifo_din <= tx_data_length[15:8];
		    			tx_fifo_wr_en <= 1'b1;
		    			tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
		    		end
		    		16'd1: begin
                        if(tx_data_length > 0)begin
                            // write the last byte of tx_data_length.
		    			    tx_fifo_din <= tx_data_length[7:0];
                            tx_fifo_wr_en <= 1'b1;
                            case(tx_command)
                                CMD_RESPONSE: begin
		    			            tx_sys_clk_cnt <= 32'd0;
                                    tx_state <= SEND_DATA;
                                end
                                CMD_POS_DATA,CMD_LIST_DATA: begin
                                    // ask the store module to read data.
                                    store_rd_req <= 1'b1;
                                    tx_state <= SEND_DATA_WAIT;
                                end 
                                default: begin
		    			            tx_sys_clk_cnt <= 32'd0;
                                    tx_state <= SEND_END;
                                end
                            endcase
                        end
                        else begin
		    			    tx_fifo_din <= tx_data_length[7:0];
                            tx_fifo_wr_en <= 1'b1;
		    			    tx_sys_clk_cnt <= 32'd0;
                            tx_state <= SEND_END;
                        end
		    		end
                endcase
            end
            SEND_DATA_WAIT: begin
                tx_fifo_wr_en <= 1'b0;
                if(store_rd_ack) begin
                    store_rd_req <= 1'b0;
                    // clock out first position data.
                    store_rd_en <= 1'b1;
		    	    tx_sys_clk_cnt <= 32'd0;
                    tx_state <= SEND_DATA_DELAY;
                end
            end
            SEND_DATA_DELAY: begin
                // enable read next clock.
                store_rd_en <= 1'b1;
                tx_state <= SEND_DATA;
            end
            SEND_DATA: begin
                case(tx_command)
                    CMD_RESPONSE: begin
                        if(tx_sys_clk_cnt < 4'd15) begin
                            case(tx_sys_clk_cnt)
                                16'd0:      tx_fifo_din <= tx_data[0];
                                16'd1:      tx_fifo_din <= tx_data[1];
                                16'd2:      tx_fifo_din <= tx_data[2];
                                16'd3:      tx_fifo_din <= tx_data[3];
                                16'd4:      tx_fifo_din <= tx_data[4];
                                16'd5:      tx_fifo_din <= tx_data[5];
                                16'd6:      tx_fifo_din <= tx_data[6];
                                16'd7:      tx_fifo_din <= tx_data[7];
                                16'd8:      tx_fifo_din <= tx_data[8];
                                16'd9:      tx_fifo_din <= tx_data[9];
                                16'd10:      tx_fifo_din <= tx_data[10];
                                16'd11:      tx_fifo_din <= tx_data[11];
                                16'd12:      tx_fifo_din <= tx_data[12];
                                16'd13:      tx_fifo_din <= tx_data[13];
                                16'd14:      tx_fifo_din <= tx_data[14];
                            endcase
		    	        	tx_fifo_wr_en <= 1'b1;
		    	        	tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                        end
                        // If the last byte.
                        else if(tx_sys_clk_cnt == 4'd15) begin
                            // buffer the former data.
                            tx_fifo_din <= tx_data[15];
		    	        	tx_fifo_wr_en <= 1'b1;
		    	        	tx_sys_clk_cnt <= 32'd0;
                            // change to next state.
                            tx_state <= SEND_END;
                        end
                    end
                    // CMD_ACK_OK, CMD_ACK_ERROR: begin
		            //     tx_state <= TX_END;
                    // end
                    CMD_POS_DATA,CMD_LIST_DATA: begin
                        // buffer the former data.
                        tx_fifo_din <= store_dout;
		    	        tx_fifo_wr_en <= 1'b1;
                        if(tx_sys_clk_cnt < tx_data_length - 2'd2) begin
		    	        	tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                            // enable read next clock.
                            store_rd_en <= 1'b1;
                        end
                        // If the second last byte.
                        else if(tx_sys_clk_cnt == tx_data_length - 2'd2) begin
		    	        	tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                            // disable read next clock.
                            store_rd_en <= 1'b0;
                        end
                        // If the last byte.
                        else if(tx_sys_clk_cnt == tx_data_length - 1'b1) begin
		    	        	tx_sys_clk_cnt <= 16'd0;
                            // change to next state.
		    	        	tx_sys_clk_cnt <= 32'd0;
                            tx_state <= SEND_END;
                        end
                    end
                    default: begin
                        store_rd_en <= 1'b0;
		    	        tx_sys_clk_cnt <= 32'd0;
                        tx_state <= SEND_END;
                    end
                endcase
            end
            SEND_END: begin
                case(tx_sys_clk_cnt)
                    16'd0: begin
                        tx_fifo_din <= tx_checksum;
		    	        tx_fifo_wr_en <= 1'b1;
		    	        tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                    end
                    16'd1: begin
                        tx_fifo_din <= 8'h0A;
                        tx_fifo_wr_en <= 1'b1;
                        tx_sys_clk_cnt <= 32'd0;
		                tx_state <= TX_END;
                    end
                endcase
            end
            TX_END: begin
                tx_fifo_wr_en <= 1'b0;
                // delay one clock for fifo write complete.
                if(tx_sys_clk_cnt < 2'd1) begin
                    tx_frame_valid <= 1'b0;
                    tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                end
                // Wait 40ns two avoid error between two clock.
                else if(tx_sys_clk_cnt < 4'd7) begin
                    tx_frame_valid <= 1'b1;
                    tx_sys_clk_cnt <= tx_sys_clk_cnt + 1'b1;
                end
                else begin
                    tx_sys_clk_cnt <= 32'd0;
                    tx_frame_valid <= 1'b0;
                    tx_state <= TX_IDLE;
                end
            end
        endcase
    end
end
endmodule
