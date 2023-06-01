/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * modbus_udp.v: Modbus tcp/ip similar receive control. This module 
	 buffer data to fifo until no data come along timeout. This module set
	 rx_frame_come flag after timeout.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2021.1.3
	******************************************************************************
*/

module modbus_udp
#(
	parameter CLK_FRE = 200       	//clock frequency(Mhz)
)
(
    input                   sys_clk,
    input                   rst_n  ,

	(*mark_debug = "true"*)input                   gmii_rx_clk,
    input                   gmii_tx_clk,

    (*mark_debug = "true"*)output                  gmii_tx_en,
    (*mark_debug = "true"*)output [7:0]            gmii_txd,
    (*mark_debug = "true"*)input                   gmii_rx_dv,
    (*mark_debug = "true"*)input [7:0]             gmii_rxd,

    output reg              modbus_ready,          // When arp found, then mac can send data.

    output                  rx_frame_valid,
    output [7:0]            rx_fifo_dout,
    input                   rx_fifo_rd_en,
    output [10:0]           rx_fifo_cnt,

    input                   tx_frame_valid,
    input [7:0]             tx_fifo_din,
    input                   tx_fifo_wr_en,
    output reg              tx_fifo_busy,
    output                  tx_fifo_full
);

// Some parameters.
localparam CYCLE_1S_1000MBPS        = 32'd125000000;
localparam CYCLE_1S_100MBPS         = 32'd25000000;
localparam CYCLE_1S_10MBPS          = 32'd2500000;
localparam CYCLE_100mS_1000MBPS     = 32'd12500000;
localparam CYCLE_10mS_1000MBPS      = 32'd1250000;
localparam CYCLE_1mS_1000MBPS       = 32'd125000;
localparam CYCLE_100uS_1000MBPS     = 32'd12500;
localparam CYCLE_10uS_1000MBPS      = 32'd1250; // used for simulation.
localparam CYCLE_1uS_1000MBPS       = 32'd125; // used for simulation.

// Ethernet related parameters.
localparam LOCAL_IP_ADDR    = 32'hc0a80002     ;
localparam LOCAL_MAC_ADDR   = 48'h000a3501fec0 ;
localparam DST_IP_ADDR      = 32'hc0a80003     ;
localparam UDP_SRC_PORT     = 16'h1f90         ;
localparam UDP_DST_PORT     = 16'h1f90         ;
localparam TTL              = 8'h80            ;

// Modbus Receive.
localparam RX_IDLE                  = 7'b000_0001;
localparam RX_READ                  = 7'b000_0010;
localparam RX_WAIT                  = 7'b000_0100;
localparam RX_CHECK                 = 7'b000_1000;
localparam RX_REPLY_WAIT            = 7'b001_0000;
localparam RX_REPLY                 = 7'b010_0000;
localparam RX_END                   = 7'b100_0000;
(*mark_debug = "true"*)reg[6:0] rx_state = RX_IDLE;
reg[10:0] rx_wait_cnt = 11'd0;
reg[10:0] udp_rec_ram_read_addr;
wire[15:0] udp_rec_data_length;
wire udp_rec_data_valid_posedge;
always @(posedge gmii_rx_clk or negedge rst_n)
begin
    if (~rst_n) begin
        rx_state <= RX_IDLE ;
    end
    else begin
        case(rx_state)
            RX_IDLE      : begin
                if (udp_rec_data_valid_posedge) begin
                    rx_state <= RX_READ ;
                    rx_wait_cnt <= 11'd0;
                end
                else
                    rx_state <= RX_IDLE ;
            end
            RX_READ    : begin
                if(rx_wait_cnt == udp_rec_data_length - 4'd9) begin
                    rx_state <= RX_WAIT ;
                    rx_wait_cnt <= 11'd0;
                end
                else
                    rx_wait_cnt <= rx_wait_cnt + 1'b1;
            end
            RX_WAIT: begin
                // Wait 8 clcok to avoid different clock error.
                if(rx_wait_cnt == 4'd7) begin
                    rx_state <= RX_END;
                    rx_wait_cnt <= 11'd0;
                end
                else 
                    rx_wait_cnt <= rx_wait_cnt + 1'b1;
            end
            RX_END: begin
                rx_state <= RX_IDLE;
                rx_wait_cnt <= 11'd0;
            end
            default     :
                rx_state <= RX_IDLE;
        endcase
    end
end
  
// Check udp receive ram data is valid or not.
reg[1:0] udp_rec_data_valid_buf = 2'b0;
always @(posedge gmii_rx_clk)
begin
    udp_rec_data_valid_buf[0] <= udp_rec_data_valid ;
    udp_rec_data_valid_buf[1] <= udp_rec_data_valid_buf[0] ;
end
  
assign udp_rec_data_valid_posedge = ~udp_rec_data_valid_buf[1] & udp_rec_data_valid_buf[0];

// Buffer data to fifo. 
reg rx_fifo_wr_en;
always @(posedge gmii_rx_clk or negedge rst_n)
begin
    if(~rst_n) begin
        rx_fifo_wr_en <= 1'b0;
        udp_rec_ram_read_addr <= 11'b0;
    end
    else if(rx_state == RX_READ) begin
        rx_fifo_wr_en <= 1'b1;
        udp_rec_ram_read_addr <= udp_rec_ram_read_addr + 1'b1;
    end
    else begin
        rx_fifo_wr_en <= 1'b0;
        udp_rec_ram_read_addr <= 11'b0;
    end
end

assign rx_frame_valid = (rx_state == RX_WAIT);

// Modbus transmit.
localparam TX_IDLE          = 9'b0_0000_0001 ;
localparam TX_ARP_REQ       = 9'b0_0000_0010 ;
localparam TX_ARP_SEND      = 9'b0_0000_0100 ;
localparam TX_ARP_WAIT      = 9'b0_0000_1000 ;
localparam TX_GEN_REQ       = 9'b0_0001_0000 ;
localparam TX_WRITE_RAM     = 9'b0_0010_0000 ;
localparam TX_WAIT_FRAME    = 9'b0_0100_0000 ;
localparam TX_CHECK_FIFO    = 9'b0_1000_0000 ;
localparam TX_CHECK_ARP     = 9'b1_0000_0000 ;

(*mark_debug = "true"*)reg[8:0] tx_state  ;
reg[31:0] tx_wait_cnt = 32'd0;
reg udp_tx_req;
reg arp_request_req;
wire tx_frame_valid_posedge;
reg[15:0] udp_send_data_length = 16'd0;
wire udp_ram_data_req;
// wire write_ram_end;
wire mac_send_end;
wire[10:0] tx_fifo_cnt;
wire mac_not_exist;
wire arp_found;

always @(posedge gmii_tx_clk or negedge rst_n)
begin
    if(~rst_n) begin
        tx_state <= TX_IDLE;
        modbus_ready <= 1'b0;
        arp_request_req <= 1'b0;
        udp_tx_req <= 1'b0;
    end
    else begin
        case(tx_state)
            TX_IDLE        : begin
                // Wait for 10ms
                // if (tx_wait_cnt == CYCLE_10uS_1000MBPS - 1'b1) begin // used for simulation.
                if (tx_wait_cnt == CYCLE_1S_1000MBPS - 1'b1) begin
                    tx_state <= TX_ARP_REQ ;
                    arp_request_req <= 1'b1;
                    tx_wait_cnt <= 32'd0;
                end
                else begin
                    tx_state <= TX_IDLE ;
                    tx_wait_cnt <= tx_wait_cnt + 1'b1;
                end
            end
            TX_ARP_REQ     : begin
                tx_state <= TX_ARP_SEND;
                arp_request_req <= 1'b0;
            end
            TX_ARP_SEND    : begin
                if (mac_send_end)
                    tx_state <= TX_ARP_WAIT ;
                else
                    tx_state <= TX_ARP_SEND ;
            end
            TX_ARP_WAIT    : begin
                // tx_state <= TX_WAIT_FRAME;  // used for simulation.
                if (arp_found) begin
                    tx_state <= TX_WAIT_FRAME;
                    modbus_ready <= 1'b1;
                    tx_wait_cnt <= 32'd0;
                end
                else if (tx_wait_cnt == CYCLE_1S_1000MBPS - 1'b1) begin
                    tx_state <= TX_ARP_REQ ;
                    arp_request_req <= 1'b1;
                    tx_wait_cnt <= 32'd0;
                end
                else begin
                    tx_state <= TX_ARP_WAIT ;
                    tx_wait_cnt <= tx_wait_cnt + 1'b1;
                end
            end
            TX_WAIT_FRAME: begin
                if(tx_frame_valid_posedge)
                    tx_state <= TX_CHECK_FIFO;
                else 
                    tx_state <= TX_WAIT_FRAME; 
            end
            TX_CHECK_FIFO : begin
                tx_state <= TX_GEN_REQ;
                tx_wait_cnt <= 32'd0;
                // if(tx_fifo_cnt > 1'b0) begin
                //     tx_state <= TX_GEN_REQ;
                //     tx_wait_cnt <= 32'd0;
                // end
                // else if(tx_wait_cnt == CYCLE_1mS_1000MBPS - 1'b1) begin
                //     tx_state <= TX_WAIT_FRAME;
                //     tx_wait_cnt <= 32'd0;
                // end
                // else begin
                //     tx_state <= TX_CHECK_FIFO;
                //     tx_wait_cnt <= tx_wait_cnt + 1'b1;
                // end
            end
            TX_GEN_REQ : begin
                udp_tx_req <= 1'b1;
                if (udp_ram_data_req) begin
                    tx_state <= TX_WRITE_RAM ;
                    tx_wait_cnt <= 32'd0;
                end
                else
                    tx_state <= TX_GEN_REQ ;
            end
            TX_WRITE_RAM   : begin
                udp_tx_req <= 1'b0;
	        	if (tx_wait_cnt == udp_send_data_length - 1'b1) begin
                    tx_state <= TX_CHECK_ARP;
                    tx_wait_cnt <= 32'd0;
                end
                else begin
                    tx_state <= TX_WRITE_RAM ;
                    tx_wait_cnt <= tx_wait_cnt + 1'b1;
                end
            end
            TX_CHECK_ARP: begin
                if (mac_not_exist)
                    tx_state <= TX_ARP_REQ ;
                else
                    if(tx_wait_cnt < CYCLE_1uS_1000MBPS) begin
                        tx_wait_cnt <= tx_wait_cnt + 1'b1;
                    end
                    else begin
                        tx_state <= TX_WAIT_FRAME;
                        tx_wait_cnt <= 32'd0;
                    end
            end
            default     :
                tx_state <= TX_IDLE ;
        endcase
    end
end

// tx frame data valid needs two clock buffer to avoid error between two clocks.
reg tx_frame_valid_buf[1:0];
always @(posedge gmii_tx_clk or negedge rst_n)
begin
    if(~rst_n) begin
        tx_frame_valid_buf[0] <= 1'b0;
        tx_frame_valid_buf[1] <= 1'b0;
    end
    else begin
        tx_frame_valid_buf[0] <= tx_frame_valid;
        tx_frame_valid_buf[1] <= tx_frame_valid_buf[0];
    end
end

assign tx_frame_valid_posedge = ~tx_frame_valid_buf[1] & tx_frame_valid_buf[0];

// UDP transmit request or ARP request flags.
// wire udp_tx_req;
// wire arp_request_req;
// assign udp_tx_req    = (tx_state == TX_GEN_REQ) ;
// assign arp_request_req  = (tx_state == TX_ARP_REQ) ;

// update udp send data length.
always @(posedge gmii_tx_clk)
begin
    if(tx_state == TX_CHECK_FIFO || tx_state == TX_IDLE) begin
        udp_send_data_length <= 16'd0;
    end
    else if(tx_state == TX_GEN_REQ) begin
        udp_send_data_length <= tx_fifo_cnt;
    end
end

// write data to tx ram. 
reg tx_fifo_rd_en = 1'b0;
reg ram_wr_en = 1'b0;
always @(posedge gmii_tx_clk or negedge rst_n)
begin
    if(~rst_n) begin
        tx_fifo_rd_en <= 1'b0;
        ram_wr_en <= 1'b0;
    end
    else begin
        if(udp_ram_data_req) begin
            tx_fifo_rd_en <= 1'b1;
        end
        else if(tx_state == TX_WRITE_RAM)begin
            ram_wr_en <= 1'b1;
            if(tx_wait_cnt == udp_send_data_length - 1'b1)
                tx_fifo_rd_en <= 1'b0;
        end
        else begin
            tx_fifo_rd_en <= 1'b0;
            ram_wr_en <= 1'b0;
        end
    end
end
always @(posedge gmii_tx_clk or negedge rst_n)
begin
    if(~rst_n) begin
        tx_fifo_busy <= 1'b1;
    end
    else begin
        if(tx_state == TX_WAIT_FRAME)begin
            tx_fifo_busy <= 1'b0;
        end
        else if(tx_state == TX_GEN_REQ) begin
            tx_fifo_busy <= 1'b1;
        end
    end
end


// mac related variables.
reg[15:0] identify_code = 16'h0;
wire[7:0] ram_wr_data;
// wire ram_wr_en;
wire almost_full;
// wire udp_ram_data_req;
wire udp_tx_end;
// wire udp_tx_req;
// wire arp_request_req;
// wire mac_send_end;
wire[7:0] udp_rec_ram_rdata;
// wire udp_rec_data_valid;
// wire mac_not_exist;
// wire arp_found;
mac_top mac_top0
(
    .gmii_tx_clk                 (gmii_tx_clk)                  ,
    .gmii_rx_clk                 (gmii_rx_clk)                  ,
    .rst_n                       (rst_n)  ,
    
    .identify_code               (identify_code),
    .source_mac_addr             (LOCAL_MAC_ADDR), 
    .source_ip_addr              (LOCAL_IP_ADDR),      //source mac address
    .TTL                         (TTL),
    .destination_ip_addr         (DST_IP_ADDR),
    .udp_send_source_port        (UDP_SRC_PORT),
    .udp_send_destination_port   (UDP_DST_PORT),
    
    .ram_wr_data                 (ram_wr_data) ,
    .ram_wr_en                   (ram_wr_en),
    .almost_full                 (almost_full), 
    .udp_ram_data_req            (udp_ram_data_req),
    .udp_send_data_length        (udp_send_data_length),
    .udp_tx_end                  (udp_tx_end),
    
    .udp_tx_req                  (udp_tx_req),
    .arp_request_req             (arp_request_req ),
    
    .mac_data_valid              (gmii_tx_en),
    .mac_tx_data                 (gmii_txd),
    .mac_send_end                (mac_send_end),

    .rx_dv                       (gmii_rx_dv),
    .mac_rx_datain               (gmii_rxd),
    
    .udp_rec_ram_rdata           (udp_rec_ram_rdata),
    .udp_rec_ram_read_addr       (udp_rec_ram_read_addr),
    .udp_rec_data_length         (udp_rec_data_length ),
    .udp_rec_data_valid          (udp_rec_data_valid),

    .arp_found                   (arp_found ),
    .mac_not_exist               (mac_not_exist )
) ;

// FIFO to buffer the received data.
wire fifo_rst;
assign fifo_rst = ~rst_n;
eth_rx_fifo eth_rx_fifo_inst(
    .rst(fifo_rst),
    .wr_clk(gmii_rx_clk),
    .rd_clk(sys_clk),
    .din(udp_rec_ram_rdata),
    .wr_en(rx_fifo_wr_en),
    .rd_en(rx_fifo_rd_en),
    .dout(rx_fifo_dout),
    .full(),
    .empty(),
    .wr_data_count(rx_fifo_cnt),
    .wr_rst_busy(),
    .rd_rst_busy()
  );

// FIFO to buffer the transmit data.
eth_tx_fifo eth_tx_fifo_inst(
    .rst(fifo_rst),
    .wr_clk(sys_clk),
    .rd_clk(gmii_tx_clk),
    .din(tx_fifo_din),
    .wr_en(tx_fifo_wr_en),
    .rd_en(tx_fifo_rd_en),
    .dout(ram_wr_data),
    .full(tx_fifo_full),
    .empty(),
    .wr_data_count(tx_fifo_cnt),
    .wr_rst_busy(),
    .rd_rst_busy()
  );

endmodule
 