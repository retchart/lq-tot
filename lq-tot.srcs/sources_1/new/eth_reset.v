/**
	******************************************************************************
 * Copyright(c) 2019 liulx
 * All rights reserved
 *
 * eth_reset.v: The minimum reset pulse width is 10ms.
 * author: liulixing, liulx18@mails.tsinghua.edu.cn
 * date: 2021.1.2
	******************************************************************************
*/
module eth_reset
(
	input sys_clk,
	input key,
	output reg rst_n
);

// delay about 20ms for sure.
// the clock frequency is 200 Mhz. Thus the delay clock counts is 
reg[23:0] cnt = 24'd0;
always@(posedge sys_clk) begin
    if(key == 1'b0) begin
        rst_n <= 1'b0;
    end
    else begin
    	if(cnt == 24'h400000) begin
            rst_n <= 1'b1;
	    end
	    else
		    cnt <= cnt + 1'b1;
    end
end
       
endmodule 
