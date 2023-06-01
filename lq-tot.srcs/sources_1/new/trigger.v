/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * ide1162.v: ide1162 readout and test.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2019.12.31
 * trigger pulse width's unit is 5/8 ns. The max pulse width is 20.48 us.
	******************************************************************************
*/

module trigger
#(
	parameter CLK_FRE = 200,        	//clock frequency(Mhz)
	parameter TIME_STAMP_PERIOD = 10,  	//clock period(50 nS)
    parameter JITTER_TIME = 10,        // Time to avoid invalid events caused by jitter.
    parameter POLARITY = 1'b0           // Polarity of hit.
)
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

	input				enable,         // High valid.
    input               sync,           // synchronization.
    input[3:0]          mode,           // 0 - position mode; 1 - list mode.
    
	(*mark_debug = "true"*)input[31:0]			din,            // trigger wires.
    input               polarity,       // Polarity of hit
    input[2:0]          number_shift,   // Address shift.
	input[7:0]			lthd,           // lower level threshold.
    
    (*mark_debug = "true"*)output reg          store_wr_req,   // store fifo write enable.
    (*mark_debug = "true"*)input               store_wr_ack,   // store fifo write compelete ack.
    (*mark_debug = "true"*)output reg[7:0]     store_data,    // list mode: pulse width
    (*mark_debug = "true"*)output reg          store_wr_en   // store fifo write enable.
	);

/*
// Phase counter used to synchrotron the phase of 8 clocks.
reg[7:0] phase_count = 8'b0;
always@(posedge sys_clk)
begin
	phase_count <= phase_count + 1'b1;
end

// buffer the state of each clock.
wire[7:0] q;
wire[7:0] q_n;
assign q[7] = phase_count[0];
assign q_n[7] = ~phase_count[0];
tdc_dff dff7_cnt(
    .clk(clk7), 
    .din(phase_count[0]),
    .q(q[0]),
    .q_n(q_n[0])
);
tdc_dff dff6_cnt(
    .clk(clk6), 
    .din(q_n[0]),
    .q(q[1]),
    .q_n(q_n[1])
);
tdc_dff dff5_cnt(
    .clk(clk5), 
    .din(q_n[1]),
    .q(q[2]),
    .q_n(q_n[2])
);
tdc_dff dff4_cnt(
    .clk(clk4), 
    .din(q_n[2]),
    .q(q[3]),
    .q_n(q_n[3])
);
tdc_dff dff3_cnt(
    .clk(clk3), 
    .din(q_n[3]),
    .q(q[4]),
    .q_n(q_n[4])
);
tdc_dff dff2_cnt(
    .clk(clk2), 
    .din(q_n[4]),
    .q(q[5]),
    .q_n(q_n[5])
);
tdc_dff dff1_cnt(
    .clk(clk1), 
    .din(q_n[5]),
    .q(q[6]),
    .q_n(q_n[6])
);
*/
// trigger pos analysis in list mode.
localparam IDLE                 = 5'b00000;
localparam FIFO_CHECK           = 5'b00001;
localparam WAIT                 = 5'b00010;
localparam WAIT1                = 5'b00100;
localparam STORE                = 5'b01000;
localparam STOP                 = 5'b10000;

reg[31:0] tdc_mpcs_enable = 32'd0;
wire[31:0] fifo_busy;
wire fifo_full[31:0];
reg[31:0] fifo_rd_en = 32'd0;
wire[7:0] fifo_dout[31:0];
wire[6:0] fifo_count[31:0];

(*mark_debug = "true"*)reg[4:0] state = IDLE;
(*mark_debug = "true"*)reg[11:0] state_clk_cnt = 12'd0;
(*mark_debug = "true"*)reg[5:0] channel_cnt = 6'd0;
reg[5:0] fifo_rd_cnt = 6'd0;
reg[7:0] state_wait_clk_cnt = 8'd0;

initial state <= IDLE;
initial fifo_rd_en <= 32'b0;
initial tdc_mpcs_enable = 32'h00000000;
initial store_wr_en = 1'b0;      // Initial is 1 for simulation and 0 for other.

always@(posedge sys_clk)
begin
    case(state)
        IDLE: begin
            channel_cnt <= 6'b0;
            if(enable && (mode == 4'b1)) begin
                // Check fifo every 10 us.
                if(state_clk_cnt > 11'd2000) begin
                    state <= FIFO_CHECK;
                    state_clk_cnt <= 12'd0;
                end
                else begin
                    state_clk_cnt <= state_clk_cnt + 1'b1;
                    tdc_mpcs_enable = 32'hFFFFFFFF;
                end
            end
            else begin
                tdc_mpcs_enable = 32'h00000000;
            end
        end
        FIFO_CHECK: begin
            case(channel_cnt)
                5'd0: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[0][6:3] || fifo_full[0]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[0] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd1: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[1][6:3] || fifo_full[1]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[1] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd2: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[2][6:3] || fifo_full[2]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[2] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd3: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[3][6:3] || fifo_full[3]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[3] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd4: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[4][6:3] || fifo_full[4]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[4] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd5: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[5][6:3] || fifo_full[5]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[5] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd6: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[6][6:3] || fifo_full[6]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[6] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd7: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[7][6:3] || fifo_full[7]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[7] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd8: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[8][6:3] || fifo_full[8]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[8] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd9: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[9][6:3] || fifo_full[9]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[9] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd10: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[10][6:3] || fifo_full[10]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[10] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd11: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[11][6:3] || fifo_full[11]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[11] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd12: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[12][6:3] || fifo_full[12]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[12] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd13: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[13][6:3] || fifo_full[13]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[13] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd14: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[14][6:3] || fifo_full[14]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[14] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd15: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[15][6:3] || fifo_full[15]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[15] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd16: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[16][6:3] || fifo_full[16]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[16] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd17: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[17][6:3] || fifo_full[17]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[17] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd18: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[18][6:3] || fifo_full[18]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[18] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd19: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[19][6:3] || fifo_full[19]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[19] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd20: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[20][6:3] || fifo_full[20]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[20] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd21: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[21][6:3] || fifo_full[21]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[21] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd22: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[22][6:3] || fifo_full[22]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[22] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd23: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[23][6:3] || fifo_full[23]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[23] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd24: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[24][6:3] || fifo_full[24]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[24] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd25: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[25][6:3] || fifo_full[25]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[25] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd26: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[26][6:3] || fifo_full[26]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[26] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd27: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[27][6:3] || fifo_full[27]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[27] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd28: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[28][6:3] || fifo_full[28]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[28] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd29: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[29][6:3] || fifo_full[29]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[29] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd30: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[30][6:3] || fifo_full[30]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[30] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                5'd31: begin
                    // if fifo has data, save all the data.
                    if(fifo_count[31][6:3] || fifo_full[31]) begin
                        // request the total store fifo to save data.
                        tdc_mpcs_enable[31] <= 1'b0;
                        store_wr_req <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        channel_cnt <= channel_cnt + 1'b1;
                    end
                end
                default: begin
                    channel_cnt <= 6'd0;
                    state <= IDLE;
                end
            endcase
        end
        WAIT: begin
            if(store_wr_ack && (!fifo_busy)) begin
                store_wr_req <= 1'b0;
                case(channel_cnt)
                    5'd0: fifo_rd_en[0] <= 1'b1;
                    5'd1: fifo_rd_en[1] <= 1'b1;
                    5'd2: fifo_rd_en[2] <= 1'b1;
                    5'd3: fifo_rd_en[3] <= 1'b1;
                    5'd4: fifo_rd_en[4] <= 1'b1;
                    5'd5: fifo_rd_en[5] <= 1'b1;
                    5'd6: fifo_rd_en[6] <= 1'b1;
                    5'd7: fifo_rd_en[7] <= 1'b1;
                    5'd8: fifo_rd_en[8] <= 1'b1;
                    5'd9: fifo_rd_en[9] <= 1'b1;
                    5'd10: fifo_rd_en[10] <= 1'b1;
                    5'd11: fifo_rd_en[11] <= 1'b1;
                    5'd12: fifo_rd_en[12] <= 1'b1;
                    5'd13: fifo_rd_en[13] <= 1'b1;
                    5'd14: fifo_rd_en[14] <= 1'b1;
                    5'd15: fifo_rd_en[15] <= 1'b1;
                    5'd16: fifo_rd_en[16] <= 1'b1;
                    5'd17: fifo_rd_en[17] <= 1'b1;
                    5'd18: fifo_rd_en[18] <= 1'b1;
                    5'd19: fifo_rd_en[19] <= 1'b1;
                    5'd20: fifo_rd_en[20] <= 1'b1;
                    5'd21: fifo_rd_en[21] <= 1'b1;
                    5'd22: fifo_rd_en[22] <= 1'b1;
                    5'd23: fifo_rd_en[23] <= 1'b1;
                    5'd24: fifo_rd_en[24] <= 1'b1;
                    5'd25: fifo_rd_en[25] <= 1'b1;
                    5'd26: fifo_rd_en[26] <= 1'b1;
                    5'd27: fifo_rd_en[27] <= 1'b1;
                    5'd28: fifo_rd_en[28] <= 1'b1;
                    5'd29: fifo_rd_en[29] <= 1'b1;
                    5'd30: fifo_rd_en[30] <= 1'b1;
                    5'd31: fifo_rd_en[31] <= 1'b1;
                endcase
                fifo_rd_cnt <= 1'd0;
                state <= WAIT1;
            end
            // if 16 clock timeout, reset the state.
            else if(state_clk_cnt >= 4'd15) begin
                state_clk_cnt <= 12'd0;
                store_wr_req <= 1'b0;
                state <= FIFO_CHECK;
            end
            else 
                state_clk_cnt <= state_clk_cnt + 1'b1;
        end
        WAIT1: begin
            fifo_rd_cnt <= fifo_rd_cnt + 1'd1;
            state <= STORE;
        end
        STORE: begin
            case(channel_cnt)
                5'd0: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[0];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[0][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[0] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd1: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[1];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[1][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[1] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd2: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[2];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[2][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[2] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd3: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[3];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[3][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[3] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd4: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[4];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[4][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[4] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd5: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[5];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[5][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[5] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd6: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[6];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[6][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[6] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd7: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[7];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[7][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[7] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd8: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[8];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[8][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[8] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd9: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[9];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[9][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[9] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd10: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[10];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[10][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[10] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                        fifo_rd_cnt <= 6'd0;
                    end
                end
                5'd11: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[11];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[11][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[11] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd12: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[12];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[12][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[12] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd13: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[13];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[13][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[13] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd14: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[14];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[14][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[14] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd15: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[15];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[15][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[15] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd16: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[16];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[16][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[16] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd17: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[17];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[17][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[17] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd18: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[18];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[18][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[18] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd19: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[19];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[19][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[19] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd20: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[20];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[20][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[20] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd21: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[21];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[21][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[21] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd22: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[22];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[22][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[22] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd23: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[23];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[23][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[23] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd24: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[24];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[24][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[24] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd25: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[25];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[25][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[25] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd26: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[26];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[26][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[26] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd27: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[27];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[27][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[27] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd28: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[28];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[28][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[28] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd29: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[29];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[29][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[29] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd30: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[30];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[30][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[30] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                5'd31: begin
                    store_wr_en <= 1'b1;
                    store_data <= fifo_dout[31];
                    if(fifo_rd_cnt < 3'd7)
                        fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                    else if(fifo_rd_cnt == 4'd7) begin
                        // check whether a valid frame remain.
                        if(fifo_count[31][6:3])  
                            fifo_rd_cnt <= 6'd0;
                        else begin
                            fifo_rd_en[31] <= 1'b0;
                            fifo_rd_cnt <= fifo_rd_cnt + 1'b1;
                        end
                    end
                    else begin
                        state <= STOP;
                    end
                end
                default: begin
                    fifo_rd_en <= 32'h00000000;
                    state <= STOP;
                end
            endcase
        end
        STOP: begin
            fifo_rd_cnt <= 6'd0;
            store_wr_en <= 1'b0;
            store_data <= 8'd0;
            tdc_mpcs_enable <= 32'hFFFFFFFF;
            state_clk_cnt <= 12'd0;
            // wait 1 clock.
            if(state_clk_cnt > 1'b1) begin
                // Next channel.
                channel_cnt <= channel_cnt + 1'b1;
                // Check the fifo of next channel.
                state <= FIFO_CHECK;
            end
            else 
                state_clk_cnt <= state_clk_cnt + 1'b1;
        end
        default: begin
            state <= IDLE;
        end
    endcase
end

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(5nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs0
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[0]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),

    .hit(din[0]),
    .number({number_shift, 5'd0}),

    .fifo_busy(fifo_busy[0]),      // busy indicator.
    .fifo_full(fifo_full[0]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[0]),     // fifo read enable.
    .fifo_dout(fifo_dout[0]),      // fifo data output.
    .fifo_data_count(fifo_count[0]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs1
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[1]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[1]),
    .number({number_shift, 5'd1}),

    .fifo_busy(fifo_busy[1]),      // busy indicator.
    .fifo_full(fifo_full[1]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[1]),     // fifo read enable.
    .fifo_dout(fifo_dout[1]),      // fifo data output.
    .fifo_data_count(fifo_count[1]) // fifo data counts. 
	);
    
tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs2
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[2]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[2]),
    .number({number_shift, 5'd2}),

    .fifo_busy(fifo_busy[2]),      // busy indicator.
    .fifo_full(fifo_full[2]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[2]),     // fifo read enable.
    .fifo_dout(fifo_dout[2]),      // fifo data output.
    .fifo_data_count(fifo_count[2]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs3
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[3]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[3]),
    .number({number_shift, 5'd3}),

    .fifo_busy(fifo_busy[3]),      // busy indicator.
    .fifo_full(fifo_full[3]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[3]),     // fifo read enable.
    .fifo_dout(fifo_dout[3]),      // fifo data output.
    .fifo_data_count(fifo_count[3]) // fifo data counts. 
	);
    
tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs4
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[4]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[4]),
    .number({number_shift, 5'd4}),

    .fifo_busy(fifo_busy[4]),      // busy indicator.
    .fifo_full(fifo_full[4]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[4]),     // fifo read enable.
    .fifo_dout(fifo_dout[4]),      // fifo data output.
    .fifo_data_count(fifo_count[4]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs5
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[5]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[5]),
    .number({number_shift, 5'd5}),

    .fifo_busy(fifo_busy[5]),      // busy indicator.
    .fifo_full(fifo_full[5]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[5]),     // fifo read enable.
    .fifo_dout(fifo_dout[5]),      // fifo data output.
    .fifo_data_count(fifo_count[5]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs6
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[6]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[6]),
    .number({number_shift, 5'd6}),

    .fifo_busy(fifo_busy[6]),      // busy indicator.
    .fifo_full(fifo_full[6]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[6]),     // fifo read enable.
    .fifo_dout(fifo_dout[6]),      // fifo data output.
    .fifo_data_count(fifo_count[6]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs7
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[7]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[7]),
    .number({number_shift, 5'd7}),

    .fifo_busy(fifo_busy[7]),      // busy indicator.
    .fifo_full(fifo_full[7]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[7]),     // fifo read enable.
    .fifo_dout(fifo_dout[7]),      // fifo data output.
    .fifo_data_count(fifo_count[7]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs8
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[8]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[8]),
    .number({number_shift, 5'd8}),

    .fifo_busy(fifo_busy[8]),      // busy indicator.
    .fifo_full(fifo_full[8]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[8]),     // fifo read enable.
    .fifo_dout(fifo_dout[8]),      // fifo data output.
    .fifo_data_count(fifo_count[8]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs9
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[9]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[9]),
    .number({number_shift, 5'd9}),

    .fifo_busy(fifo_busy[9]),      // busy indicator.
    .fifo_full(fifo_full[9]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[9]),     // fifo read enable.
    .fifo_dout(fifo_dout[9]),      // fifo data output.
    .fifo_data_count(fifo_count[9]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs10
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[10]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[10]),
    .number({number_shift, 5'd10}),

    .fifo_busy(fifo_busy[10]),      // busy indicator.
    .fifo_full(fifo_full[10]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[10]),     // fifo read enable.
    .fifo_dout(fifo_dout[10]),      // fifo data output.
    .fifo_data_count(fifo_count[10]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs11
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[11]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[11]),
    .number({number_shift, 5'd11}),

    .fifo_busy(fifo_busy[11]),      // busy indicator.
    .fifo_full(fifo_full[11]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[11]),     // fifo read enable.
    .fifo_dout(fifo_dout[11]),      // fifo data output.
    .fifo_data_count(fifo_count[11]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs12
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[12]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[12]),
    .number({number_shift, 5'd12}),

    .fifo_busy(fifo_busy[12]),      // busy indicator.
    .fifo_full(fifo_full[12]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[12]),     // fifo read enable.
    .fifo_dout(fifo_dout[12]),      // fifo data output.
    .fifo_data_count(fifo_count[12]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs13
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[13]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[13]),
    .number({number_shift, 5'd13}),

    .fifo_busy(fifo_busy[13]),      // busy indicator.
    .fifo_full(fifo_full[13]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[13]),     // fifo read enable.
    .fifo_dout(fifo_dout[13]),      // fifo data output.
    .fifo_data_count(fifo_count[13]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs14
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[14]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[14]),
    .number({number_shift, 5'd14}),

    .fifo_busy(fifo_busy[14]),      // busy indicator.
    .fifo_full(fifo_full[14]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[14]),     // fifo read enable.
    .fifo_dout(fifo_dout[14]),      // fifo data output.
    .fifo_data_count(fifo_count[14]) // fifo data counts. 
	);
    
tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs15
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[15]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[15]),
    .number({number_shift, 5'd15}),

    .fifo_busy(fifo_busy[15]),      // busy indicator.
    .fifo_full(fifo_full[15]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[15]),     // fifo read enable.
    .fifo_dout(fifo_dout[15]),      // fifo data output.
    .fifo_data_count(fifo_count[15]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs16
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[16]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[16]),
    .number({number_shift, 5'd16}),

    .fifo_busy(fifo_busy[16]),      // busy indicator.
    .fifo_full(fifo_full[16]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[16]),     // fifo read enable.
    .fifo_dout(fifo_dout[16]),      // fifo data output.
    .fifo_data_count(fifo_count[16]) // fifo data counts. 
	);
    
tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs17
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[17]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[17]),
    .number({number_shift, 5'd17}),

    .fifo_busy(fifo_busy[17]),      // busy indicator.
    .fifo_full(fifo_full[17]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[17]),     // fifo read enable.
    .fifo_dout(fifo_dout[17]),      // fifo data output.
    .fifo_data_count(fifo_count[17]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs18
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[18]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[18]),
    .number({number_shift, 5'd18}),

    .fifo_busy(fifo_busy[18]),      // busy indicator.
    .fifo_full(fifo_full[18]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[18]),     // fifo read enable.
    .fifo_dout(fifo_dout[18]),      // fifo data output.
    .fifo_data_count(fifo_count[18]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs19
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[19]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[19]),
    .number({number_shift, 5'd19}),

    .fifo_busy(fifo_busy[19]),      // busy indicator.
    .fifo_full(fifo_full[19]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[19]),     // fifo read enable.
    .fifo_dout(fifo_dout[19]),      // fifo data output.
    .fifo_data_count(fifo_count[19]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs20
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[20]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[20]),
    .number({number_shift, 5'd20}),

    .fifo_busy(fifo_busy[20]),      // busy indicator.
    .fifo_full(fifo_full[20]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[20]),     // fifo read enable.
    .fifo_dout(fifo_dout[20]),      // fifo data output.
    .fifo_data_count(fifo_count[20]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs21
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[21]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[21]),
    .number({number_shift, 5'd21}),

    .fifo_busy(fifo_busy[21]),      // busy indicator.
    .fifo_full(fifo_full[21]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[21]),     // fifo read enable.
    .fifo_dout(fifo_dout[21]),      // fifo data output.
    .fifo_data_count(fifo_count[21]) // fifo data counts. 
	);


tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs22
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[22]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[22]),
    .number({number_shift, 5'd22}),

    .fifo_busy(fifo_busy[22]),      // busy indicator.
    .fifo_full(fifo_full[22]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[22]),     // fifo read enable.
    .fifo_dout(fifo_dout[22]),      // fifo data output.
    .fifo_data_count(fifo_count[22]) // fifo data counts. 
	);


tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs23
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[23]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[23]),
    .number({number_shift, 5'd23}),

    .fifo_busy(fifo_busy[23]),      // busy indicator.
    .fifo_full(fifo_full[23]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[23]),     // fifo read enable.
    .fifo_dout(fifo_dout[23]),      // fifo data output.
    .fifo_data_count(fifo_count[23]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs24
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[24]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[24]),
    .number({number_shift, 5'd24}),

    .fifo_busy(fifo_busy[24]),      // busy indicator.
    .fifo_full(fifo_full[24]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[24]),     // fifo read enable.
    .fifo_dout(fifo_dout[24]),      // fifo data output.
    .fifo_data_count(fifo_count[24]) // fifo data counts. 
	);


tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs25
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[25]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[25]),
    .number({number_shift, 5'd25}),

    .fifo_busy(fifo_busy[25]),      // busy indicator.
    .fifo_full(fifo_full[25]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[25]),     // fifo read enable.
    .fifo_dout(fifo_dout[25]),      // fifo data output.
    .fifo_data_count(fifo_count[25]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs26
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[26]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[26]),
    .number({number_shift, 5'd26}),

    .fifo_busy(fifo_busy[26]),      // busy indicator.
    .fifo_full(fifo_full[26]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[26]),     // fifo read enable.
    .fifo_dout(fifo_dout[26]),      // fifo data output.
    .fifo_data_count(fifo_count[26]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs27
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[27]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[27]),
    .number({number_shift, 5'd27}),

    .fifo_busy(fifo_busy[27]),      // busy indicator.
    .fifo_full(fifo_full[27]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[27]),     // fifo read enable.
    .fifo_dout(fifo_dout[27]),      // fifo data output.
    .fifo_data_count(fifo_count[27]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs28
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[28]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[28]),
    .number({number_shift, 5'd28}),

    .fifo_busy(fifo_busy[28]),      // busy indicator.
    .fifo_full(fifo_full[28]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[28]),     // fifo read enable.
    .fifo_dout(fifo_dout[28]),      // fifo data output.
    .fifo_data_count(fifo_count[28]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs29
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[29]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[29]),
    .number({number_shift, 5'd29}),

    .fifo_busy(fifo_busy[29]),      // busy indicator.
    .fifo_full(fifo_full[29]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[29]),     // fifo read enable.
    .fifo_dout(fifo_dout[29]),      // fifo data output.
    .fifo_data_count(fifo_count[29]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs30
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[30]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[30]),
    .number({number_shift, 5'd30}),

    .fifo_busy(fifo_busy[30]),      // busy indicator.
    .fifo_full(fifo_full[30]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[30]),     // fifo read enable.
    .fifo_dout(fifo_dout[30]),      // fifo data output.
    .fifo_data_count(fifo_count[30]) // fifo data counts. 
	);

tdc_mpcs #(
	.CLK_FRE(CLK_FRE),        				//clock frequency(Mhz)
	.TIME_STAMP_PERIOD(TIME_STAMP_PERIOD),  //clock frequency(50nS)
    .JITTER_TIME(JITTER_TIME),              // Time to avoid invalid events caused by jitter.
    .POLARITY(POLARITY)                     // Polarity of hit.
) tdc_mpcs31
(
    .sys_clk(sys_clk),
    .rst_n(rst_n),

	.enable(tdc_mpcs_enable[31]),         // High valid.
    .sync(sync),                            // synchronization.
    .clk1(clk1),
    .clk2(clk2),
    .clk3(clk3),
    .clk4(clk4),
    .clk5(clk5),
    .clk6(clk6),
    .clk7(clk7),
    // .q(q),
    
    .hit(din[31]),
    .number({number_shift, 5'd31}),

    .fifo_busy(fifo_busy[31]),      // busy indicator.
    .fifo_full(fifo_full[31]),       // fifo full.
    .fifo_rd_en(fifo_rd_en[31]),     // fifo read enable.
    .fifo_dout(fifo_dout[31]),      // fifo data output.
    .fifo_data_count(fifo_count[31]) // fifo data counts. 
	);

// analyze trigger
endmodule
