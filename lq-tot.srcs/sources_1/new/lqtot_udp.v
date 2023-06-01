/**
	******************************************************************************
 * Copyright(c) 2019 liulx
 * All rights reserved
 *
 * mwpc_readout_v01.v: top module of mwpc readout.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.11.19
	******************************************************************************
*/

module lqtot_udp(
	//Differential system clocks
	input   		sys_clk_p,
	input   		sys_clk_n,
    // input           sys_clk,
	input   		reset_n,

	output			led,

    output          e_reset,
	output          e_mdc,
	inout           e_mdio,

	output[3:0]     rgmii_txd,
	output          rgmii_txctrl,
	output          rgmii_txc,
	input[3:0]      rgmii_rxd,
	input           rgmii_rxctrl,
	input           rgmii_rxc,

	(*mark_debug = "true"*)input		    gate,
    (*mark_debug = "true"*)input            sync,

	input[31:0]		din_A,
	output			lpwm_A,

	input[31:0]		din_B,
	output			lpwm_B

	// output			hold_A,
	// output			dreset_A,
	// output			shift_in_A,
	// output			ck_A,
	// output			test_on_A,

	// output			hold_B,
	// output			dreset_B,
	// output			shift_in_B,
	// output			ck_B,
	// output			test_on_B
);

// Defines
parameter	CLK_FRE				= 200;
parameter 	PWM_PERIOD 			= 16'd1024;	// pwm period.
parameter	SHIFT_FRE			= 1;
parameter	ADC_FRE				= 50;
parameter	IDE1162_CHANNELS	= 32;
parameter	TEST_ON 			= 1'b1;
parameter	TEST_OFF 			= 1'b0;

// Baudrate of UART
parameter	BAUD_RATE 			= 3000000;

// Polarity of hit signals.
parameter   POLARITY_POS        = 1'b0;
parameter   POLARITY_NEG        = 1'b1;

// Time stamp's period (nS).
parameter  TIME_STAMP_PERIOD   = 5;
// Time to avoid invalid events caused by jitter(10ns)
parameter  JITTER_TIME   = 200;

// Total pulse height spectrum channels.
parameter	PHS_CHANNELS		= 256;

// Global wires and registers
// default io is wire. So if io port is only one bit, leave it as default.

// wire 			enable;
// wire[15:0]		lthd;
// wire 			lpwm;
// wire[31:0] 		din;
// wire 			trigger;
// wire[31:0] 		trigger_pos;
// wire[7:0]		channel;
// wire				test_enable;
// wire 			trigger;
// wire 			height_valid;
// wire[7:0]		height;
// wire 			hold_b;
// wire 			dreset_b;
// wire 			shift_in_b;
// wire 			ck_b;
// wire 			test_on_b;
// wire[15:0] 		lthd;

// Convert differetial clock to single clock.
(*mark_debug = "true"*)wire sys_clk;
IBUFDS sys_clk_ibufgds
(
	.O                          (sys_clk                  ),
	.I                          (sys_clk_p                ),
	.IB                         (sys_clk_n                )
);

// convert reset into region clock.
wire rst_n;
BUFG BUFG_inst_rst (
   .O(rst_n),     // 1-bit output: Clock output port
   .I(reset_n)      // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);

// 
// global gate signal. The gate signal has an INVERTOR in electronic, so here
// needs to invert again. 
reg gate_buf = 1'b1;
always@(posedge sys_clk)
begin
    begin
        gate_buf <= ~gate;
    end
end

// synchronization buffer.
reg sync_buf = 1'b0;
always@(posedge sys_clk)
begin
    begin
        sync_buf <= ~sync;
    end
end

// LED indicator
led_test led_test_inst(  
	.sys_clk(sys_clk),
	.rst_n(rst_n),         
	.led(led)   // LED,use for control the LED signal on board
 );

// Add delay to the rgmii receive clock.
wire rgmii_rxc_delay;
idelay#
(
	.CLK_FRE(CLK_FRE)        	//clock frequency(Mhz)
) idelay_inst
(
    .ref_clk(sys_clk),
    .rst_n(rst_n),
    .delay_tap(5'b01100),

    .io(~rgmii_rxc),
    .io_delay(rgmii_rxc_delay)
);

// convert ethernet clock into region clock.
wire rgmii_rxc_bufg;
BUFG BUFG_rgmii_rxc (
   .O(rgmii_rxc_bufg),     // 1-bit output: Clock output port
   .I(rgmii_rxc_delay)      // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);

/*
BUFR #(
   .BUFR_DIVIDE("BYPASS"),   // Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8" 
   .SIM_DEVICE( "7SERIES" )  // Must be set to "7SERIES" 
) BUFR_inst (
   .O(rgmii_rxc_bufg),      // 1-bit output: Clock output port
   .CE(1'b1),               // 1-bit input: Active high, clock enable (Divided modes only)
   .CLR(1'b0),              // 1-bit input: Active high, asynchronous clear (Divided modes only)
   .I(rgmii_rxc_delay)      // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);
*/

// GMII to RGMII.
wire gmii_rx_clk;
wire[7:0] gmii_txd;
wire gmii_tx_en;
wire gmii_tx_clk;
wire gmii_crs;
wire gmii_col;
wire[7:0] gmii_rxd;
wire gmii_rxc;
wire gmii_rx_dv;
wire gmii_rx_er;
wire[1:0] speed_selection;
wire duplex_mode;
assign speed_selection = 2'b10;
assign duplex_mode = 1'b1;
util_gmii_to_rgmii util_gmii_to_rgmii_m0(
    .reset(1'b0),
    
    .rgmii_td(rgmii_txd),
    .rgmii_tx_ctl(rgmii_txctrl),
    .rgmii_txc(rgmii_txc),
    .rgmii_rd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rxctrl),
    .rgmii_rxc(rgmii_rxc_bufg),

    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(1'b0),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_crs(gmii_crs),
    .gmii_col(gmii_col),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_rx_clk(gmii_rx_clk),
    .speed_selection(speed_selection),
    .duplex_mode(duplex_mode)
);

//MDIO config
// assign speed_selection = 2'b10;
// assign duplex_mode = 1'b1;
miim_top miim_top_m0(
    .reset_i            (1'b0),
    .miim_clock_i       (gmii_tx_clk),
    .mdc_o              (e_mdc),
    .mdio_io            (e_mdio),
    .link_up_o          (),                  //link status
    .speed_o            (),                  //link speed
    .speed_override_i   (2'b10)              //10: 1000MBPS; 11: autonegoation
); 

//reset ethernet
eth_reset reset_inst
(
    .sys_clk(sys_clk),
    .key(rst_n),
    .rst_n(e_reset)
);

// modbus_udp
wire[7:0] rx_fifo_dout;
wire[10:0] rx_fifo_cnt;
wire[7:0] tx_fifo_din;

modbus_udp#
(
	.CLK_FRE(CLK_FRE)
) modbus_udp_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.gmii_rx_clk(gmii_rx_clk),
    .gmii_tx_clk(gmii_tx_clk),

    .gmii_tx_en(gmii_tx_en),
    .gmii_txd(gmii_txd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rxd(gmii_rxd),

    .modbus_ready(modbus_ready),

    .rx_frame_valid(rx_frame_valid),
    .rx_fifo_dout(rx_fifo_dout),
    .rx_fifo_rd_en(rx_fifo_rd_en),
    .rx_fifo_cnt(rx_fifo_cnt),

    .tx_frame_valid(tx_frame_valid),
    .tx_fifo_din(tx_fifo_din),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_busy(tx_fifo_busy),
    .tx_fifo_full(tx_fifo_full)
);

// Core.
wire[15:0]			s_name;
wire[31:0]			s_ip;
wire[7:0]			s_mode;
wire[7:0]			s_channel;
wire[15:0]			s_hv;
wire[15:0]			s_lthd_a;
wire[15:0]			s_lthd_b;
wire[7:0]			s_coin_time_a;
wire[7:0]			s_coin_time_b;
wire[7:0]			store_dout;
wire[10:0]   		store_data_cnt;
wire[9:0]			phs_rd_addr;
wire[31:0]			phs_out;

core_udp #
(
	.CLK_FRE(CLK_FRE),        //clock frequency(Mhz)
	.PHS_CHANNELS(PHS_CHANNELS)
) core_udp_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),
    .modbus_ready(modbus_ready),

	.rx_frame_valid(rx_frame_valid),
	.rx_fifo_dout(rx_fifo_dout),
    .rx_fifo_rd_en(rx_fifo_rd_en),
    .rx_fifo_cnt(rx_fifo_cnt),

	.tx_frame_valid(tx_frame_valid),
    .tx_fifo_din(tx_fifo_din),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_busy(tx_fifo_busy),
    .tx_fifo_full(tx_fifo_full),

    .gate(gate_buf),
    // .sync(sync),
    .enable(enable),

	.s_name(s_name),
	.s_ip(s_ip),
	.s_mode(s_mode),
	.s_channel(s_channel),
	.s_hv(s_hv),
	.s_lthd_a(s_lthd_a),
	.s_lthd_b(s_lthd_b),
	.s_coin_time_a(s_coin_time_a),
	.s_coin_time_b(s_coin_time_b),

	.store_rd_req(store_rd_req),
	.store_rd_ack(store_rd_ack),
	.store_rd_en(store_rd_en),
	.store_dout(store_dout),
	.store_full(store_full),
	.store_empty(store_empty),
	.store_data_cnt(store_data_cnt),

	.phs_rd_req(phs_rd_req),
	.phs_rd_addr(phs_rd_addr),
	.phs_rd_busy(phs_rd_busy),
	.phs_out(phs_out)
	);

// Generate 7 clock for every 45 degree.
wire clk1;
wire clk2;
wire clk3;
wire clk4;
wire clk5;
wire clk6;
wire clk7;
clk_phase_7 clk_mp_instA
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

// The 32 anode channels.
// wire[15:0] s_althd;
pwm 
#(
	.CLK_FRE(CLK_FRE),        		//clock frequency(Mhz)
	.PWM_PERIOD(PWM_PERIOD)			// pwm period.
) pwm_instA
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.width(s_althd),
	.pwm(lpwm_A)
	);

wire[7:0] store_data_A;
trigger
#(
	.CLK_FRE(CLK_FRE),                      //clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(5nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY_POS)                 // Polarity of hit.
) triggerA
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

	.enable(enable),                    // High valid.
    .sync(sync_buf),               // synchronization.
    .mode(s_mode[3:0]),                 // 0 - position mode; 1 - list mode.

	.din(din_A),                        // trigger wires.
    .polarity(1'b0),                    // high level votage valid.
    .number_shift(3'b000),
	.lthd(s_lthd_a),                     // lower level threshold.

    .store_wr_req(store_wr_req_A),      // store fifo write enable.
    .store_wr_ack(store_wr_ack_A),        // store fifo write compelete ack.
    .store_data(store_data_A),           // list mode: pulse width
	.store_wr_en(store_wr_en_A)            // fifo write enable.
	);

// The 32 cathode channels.
// wire[15:0] s_clthd;
pwm 
#(
	.CLK_FRE(CLK_FRE),        		//clock frequency(Mhz)
	.PWM_PERIOD(PWM_PERIOD)			// pwm period.
) pwm_instB
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

	.width(s_clthd),
	.pwm(lpwm_B)
	);

wire[7:0] store_data_B;
trigger
#(
	.CLK_FRE(CLK_FRE),                      //clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(5nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY_NEG)                 // Polarity of hit.
) triggerB
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

	.enable(enable),         // High valid.
    .sync(sync_buf),               // synchronization.
    .mode(s_mode[3:0]),                 // 0 - position mode; 1 - list mode.
	
    .din(din_B),                        // trigger wires.
    .polarity(1'b1),                    // Low level votage valid.
    .number_shift(3'b001),
	.lthd(s_lthd_b),        // jitter time along one event.

    .store_wr_req(store_wr_req_B),      // store fifo write enable.
    .store_wr_ack(store_wr_ack_B),        // store fifo write compelete ack.
    .store_data(store_data_B),           // list mode: pulse width
	.store_wr_en(store_wr_en_B)            // fifo write enable.
	);

// negedge of coincidence means position valid.
reg store_wr_req_pos = 1'b0;
reg[7:0] store_data_pos = 8'h0;
reg store_wr_en_pos = 1'b0;
// wire[10:0] store_data_cnt;
position_store
#(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD)   //clock frequency(50nS)
) position_store_inst
(
	.sys_clk(sys_clk),
	.rst_n(rst_n),

    .mode(s_mode[3:0]),                     // 0 - position mode; 1 - list mode.

	.store_wr_req_A(store_wr_req_A),            // position write request.
    .store_wr_ack_A(store_wr_ack_A),            // fifo write complete ack.
    .store_data_A(store_data_A),                // list mode: trigger wire; 
    .store_wr_en_A(store_wr_en_A),              // list mode: pulse width
	.store_wr_req_B(store_wr_req_B),            // position write request.
    .store_wr_ack_B(store_wr_ack_B),            // fifo write complete ack.
    .store_data_B(store_data_B),                // list mode: trigger wire; 
    .store_wr_en_B(store_wr_en_B),              // list mode: pulse width

	.store_wr_req_pos(store_wr_req_pos),        // position write request.
    .store_wr_ack_pos(store_wr_ack_pos),        // fifo write complete ack.
    .store_data_pos(store_data_pos),            // list mode: pulse width
	.store_wr_en_pos(store_wr_en_pos),          // fifo write enable.

	.store_rd_req(store_rd_req),            // fifo read request.
    .store_rd_ack(store_rd_ack),            // fifo read ack.
	.store_rd_en(store_rd_en),              // fifo read enable.
	.store_dout(store_dout),                // fifo dout.
	.store_full(store_full),                // fifo full.
	.store_empty(store_empty),              // fifo empty.
	.store_data_cnt(store_data_cnt)         // fifo counts.
	);

endmodule
