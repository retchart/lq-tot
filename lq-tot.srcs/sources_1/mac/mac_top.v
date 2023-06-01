//////////////////////////////////////////////////////////////////////////////////////
//Module Name : mac_top
//Description :
//
//////////////////////////////////////////////////////////////////////////////////////
`timescale 1 ns/1 ns
module mac_top
       (
         input                gmii_tx_clk  ,
         input                gmii_rx_clk  ,
         input                rst_n     ,

         input  [15:0]        identify_code,        // identify the sequence of packet.
         input  [47:0]        source_mac_addr ,     // Source mac address
         input  [7:0]         TTL,                  // Time to live.
         input  [31:0]        source_ip_addr,       // Source ip address.
         input  [31:0]        destination_ip_addr,  // Destination ip address.
         input  [15:0]        udp_send_source_port, // Source port.
         input  [15:0]        udp_send_destination_port,    // Destination port.

         input  [7:0]         ram_wr_data,          // UDP transmit ram data bus.
         input                ram_wr_en,            // UDP transmit ram write enable.
         output               almost_full,          // UDP transmit ram almost full.
         output               udp_ram_data_req,     // UDP header has transmit, request data.
         input  [15:0]        udp_send_data_length, // UDP data length to transmit.
         output               udp_tx_end,           // UDP transmit finished.
         
         input                udp_tx_req,           // The tx request start transmit.
         input                arp_request_req,      // The arp request start arp.
         
         output               mac_data_valid,       // MAC data is valid, enable GMII transmit.
         output [7:0]         mac_tx_data,          // MAC data to be transmit for the GMII interface.
         output               mac_send_end,         // MAC transmit has finished.
         
         input                rx_dv,                // Last bit of received GMII data. Since a packet starts with 0x55, 
                                                    // rx_dv means received GMII data.
         input  [7:0]         mac_rx_datain,        // Complete received GMII data.
         
         output [7:0]         udp_rec_ram_rdata ,   // UDP rx ram data bus of received GMII data.
         input  [10:0]        udp_rec_ram_read_addr,// UDP rx ram address bus.
         output [15:0]        udp_rec_data_length,  // UDP rx ram valid data length.
         output               udp_rec_data_valid,   // UDP rx finished and data is valid.
         
         output               arp_found,            // ARP found flag.
         output               mac_not_exist         // Destination MAC not found. 
         
       ) ;
       
       
wire                  arp_reply_ack ;
wire                  arp_reply_req ;
wire  [31:0]          arp_rec_source_ip_addr ;
wire  [47:0]          arp_rec_source_mac_addr ;
wire   [47:0]         destination_mac_addr ;

wire [7:0]            mac_rx_dataout ;
wire [15:0]           upper_layer_data_length ;
wire                  icmp_rx_req ;
wire                  icmp_rev_error ;
wire                  upper_data_req ;
wire                  icmp_tx_ready ;
wire  [7:0]           icmp_tx_data ;
wire                  icmp_tx_end ;
wire                  icmp_tx_req ;
wire                  icmp_tx_ack ;
wire [15:0]           icmp_send_data_length ;

mac_tx_top mac_tx0
           (
             .clk                         (gmii_tx_clk)                  ,
             .rst_n                       (rst_n)  ,
             
             .destination_mac_addr        (destination_mac_addr)   , //destination mac address
             .source_mac_addr             (source_mac_addr)   ,       //source mac address
             
             .TTL                         (TTL),
             .source_ip_addr              (source_ip_addr),
             .destination_ip_addr         (destination_ip_addr),
             
             .udp_send_source_port        (udp_send_source_port),
             .udp_send_destination_port   (udp_send_destination_port),
             
             .arp_reply_ack               (arp_reply_ack ),
             .arp_reply_req               (arp_reply_req ),
             .arp_rec_source_ip_addr      (arp_rec_source_ip_addr ),
             .arp_rec_source_mac_addr     (arp_rec_source_mac_addr ),
             .arp_request_req             (arp_request_req ),
             

             .ram_wr_data                 (ram_wr_data) ,
             .ram_wr_en                   (ram_wr_en),
             .udp_tx_req                  (udp_tx_req),
             .udp_send_data_length        (udp_send_data_length       ),
             .udp_ram_data_req            (udp_ram_data_req           ),
             .udp_tx_end                  (udp_tx_end                 ),
             .almost_full                 (almost_full                ),  
            
             .upper_data_req              (upper_data_req ),
             .icmp_tx_ready               (icmp_tx_ready ),
             .icmp_tx_data                (icmp_tx_data  ),
             .icmp_tx_end                 (icmp_tx_end  ),
             .icmp_tx_req                 (icmp_tx_req  ),
             .icmp_tx_ack                 (icmp_tx_ack  ),
             .icmp_send_data_length       (icmp_send_data_length),

             .identify_code               (identify_code       ),
             .mac_data_valid              (mac_data_valid),
             .mac_send_end                (mac_send_end),
             .mac_tx_data                 (mac_tx_data)
           ) ;
           
           
           
           
           
           
mac_rx_top mac_rx0
           (
             .clk                      (gmii_rx_clk)                  ,
             .rst_n                    (rst_n)  ,
             
             .rx_dv                    (rx_dv   ),
             .mac_rx_datain            (mac_rx_datain ),
             
             .local_ip_addr            (source_ip_addr ),
             .local_mac_addr           (source_mac_addr),
             
             .arp_reply_ack            (arp_reply_ack ),
             .arp_reply_req            (arp_reply_req ),
             .arp_rec_source_ip_addr   (arp_rec_source_ip_addr ),
             .arp_rec_source_mac_addr  (arp_rec_source_mac_addr ),
             
             .udp_rec_ram_rdata        (udp_rec_ram_rdata),
             .udp_rec_ram_read_addr    (udp_rec_ram_read_addr),
             .udp_rec_data_length      (udp_rec_data_length ),
             .udp_rec_data_valid       (udp_rec_data_valid),
             
             .mac_rx_dataout           (mac_rx_dataout ),
             .upper_layer_data_length  (upper_layer_data_length  ),
             .ip_total_data_length     (icmp_send_data_length),
             .icmp_rx_req              (icmp_rx_req ),
             .icmp_rev_error           (icmp_rev_error ),
             
             .arp_found                (arp_found  )
           ) ;
           
           
icmp_reply icmp0
           (
             .clk                      (gmii_rx_clk)                  ,
             .rst_n                    (rst_n)  ,
             .mac_send_end             (mac_send_end   ),
             .icmp_rx_data             (mac_rx_dataout ),
             .icmp_rx_req              (icmp_rx_req ),
             .icmp_rev_error           (icmp_rev_error ),
             
             .upper_layer_data_length  (upper_layer_data_length  ),
             
             .icmp_data_req            (upper_data_req  ),
             .icmp_tx_ready            (icmp_tx_ready ),
             .icmp_tx_data             (icmp_tx_data  ),
             .icmp_tx_end              (icmp_tx_end  ),
             .ip_tx_ack              (icmp_tx_ack  ),
             .icmp_tx_req              (icmp_tx_req  )
             
             
           );
           
           
arp_cache cache0
          (
            .clk                         (gmii_tx_clk),
            .rst_n                       (rst_n),
            .arp_found                   (arp_found  ),
            .arp_rec_source_ip_addr      (arp_rec_source_ip_addr ),
            .arp_rec_source_mac_addr     (arp_rec_source_mac_addr ),
            .destination_ip_addr         (destination_ip_addr),
            .destination_mac_addr        (destination_mac_addr)   ,
            .mac_not_exist               (mac_not_exist )
          );
endmodule
