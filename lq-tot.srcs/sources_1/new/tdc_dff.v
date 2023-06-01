/**
	******************************************************************************
 * Copyright(c) 2019 Tsinghua University
 * All rights reserved
 *
 * tdc_dff.v: D flip-fllop.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2023.1.28
 * The output delays 1 sys_clk.
	******************************************************************************
*/

module tdc_dff(
    input           clk, 
    input           din,
    output reg      q,
    output reg      q_n
);
    
always @(posedge clk)
begin
    q <= din;
    q_n <= ~din;
end
endmodule