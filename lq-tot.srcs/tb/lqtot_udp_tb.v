/**
	******************************************************************************
 * Copyright(c) 2019 liulx
 * All rights reserved
 *
 * lqtot_v01.v: top module of mwpc readout.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.11.19
	******************************************************************************
*/

`timescale 1ns / 100ps
module lqtot_udp_tb();

// Parameters
// Input Clock Period
parameter	CLKIN_PERIOD = 5; // nS
parameter	CLK_FRE = 200; // 200Mhz

//Differential system clocks
reg  sys_clk_n;
reg  sys_clk_p;
reg rst_n;

wire led;
wire e_reset;
wire e_mdc;
reg e_mdio = 1'b1;

wire[3:0]    rgmii_txd;
wire         rgmii_txctrl;
wire         rgmii_txc;
reg[3:0]    rgmii_rxd;
reg         rgmii_rxctrl;
reg         rgmii_rxc;

reg         gate;

reg[31:0] din_A;
reg[31:0] din_B;
// initialise
// Clock Generation
initial begin
  sys_clk_n = 1'b0;
  sys_clk_p = 1'b1;
end
always #(2.5)  begin
  sys_clk_n = ~sys_clk_n;
  sys_clk_p = ~sys_clk_p;
end

initial begin
    rgmii_rxc = 1'b0;
end
always #(4) begin
    rgmii_rxc = ~rgmii_rxc;
end

// ide1162 related initialise
initial begin
    rst_n = 0;
    rgmii_rxd = 4'd0;
    rgmii_rxctrl = 0;
    gate = 0;
	din_A = 32'h0000;
	din_B = ~32'h0000;
    # 100
	rst_n = 1;
    /*
	# 200
	rst_n = 0;
	# 200
	rst_n = 1;
	# 10000
	din_A = 32'h0001;
	din_B = ~32'h0002;
	# 20
	din_A = 32'h0000;
	din_B = ~32'h0000;
	# 10000
	din_A = 32'h003;
	din_B = ~32'h004;
	# 20
	din_A = 32'h0000;
	# 30
	din_B = ~32'h0000;
    */
end

// signal
always #(1000)  begin
	din_A = 32'h0001;
    # 200
	din_B = ~32'h0002;
	# 301
	din_A = 32'h0000;
    # 502
	din_B = ~32'h0000;
end

lqtot_udp lqtot_udp_inst(
	//Differential system clocks
	.sys_clk_p(sys_clk_p),
	.sys_clk_n(sys_clk_n),
	.reset_n(rst_n),

	.led(led),

    .e_reset(e_reset),
	.e_mdc(e_mdc),
	.e_mdio(e_mdc),

	.rgmii_txd(rgmii_txd),
	.rgmii_txctrl(rgmii_txctrl),
	.rgmii_txc(rgmii_txc),
	.rgmii_rxd(rgmii_rxd),
	.rgmii_rxctrl(rgmii_rxctrl),
	.rgmii_rxc(rgmii_rxc),

	.gate(gate),
    //.sync(sync),

	.din_A(din_A),
	.lpwm_A(lpwm_A),

	.din_B(din_B),
	.lpwm_B(lpwm_B)
);

endmodule