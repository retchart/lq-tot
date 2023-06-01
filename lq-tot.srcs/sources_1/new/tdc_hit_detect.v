/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_hit_rising_detector.v: D type latch.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * The output delays 1 sys_clk.
	******************************************************************************
*/

module tdc_hit_detect(
    input               clk,
    input               hit, 
    output              hit_rising,
    output              hit_falling
);

// reg q0; 
reg q1;
reg q2;
wire q1_n;
wire q2_n;
always @(posedge clk)
begin
    // q0 <= hit;
    q1 <= hit;
    q2 <= q1;
end
assign q1_n = ~q1;
assign q2_n = ~q2;

assign hit_rising = q2_n & q1;
assign hit_falling = q2 & q1_n;

endmodule