//===========================================================================
// Module name: led_test.v
//===========================================================================
`timescale 1ns / 1ps

module led_test 
(  
	input               sys_clk,
	input               rst_n,         
    output reg          led   // LED,use for control the LED signal on board
 );
             

//define the time counter
reg[31:0]   timer;                  
// reg          led;
// wire         sys_clk;          

//===========================================================================
// cycle counter:from 0 to 1sec
//===========================================================================
always @(posedge sys_clk)    
begin             // when the reset signal valid,time counter clearing
    if (timer == 32'd399_999_999)    // 2 seconds count(200M-1=199999999)
        timer <= 1'd0;                       //count done,clearing the time counter
    else
	    timer <= timer + 1'b1;            //timer counter = timer counter + 1
end

//===========================================================================
// LED control
//===========================================================================
always @(posedge sys_clk)   
begin        
    if (timer == 1'b0)    //time counter count to 0.25 sec,LED1 lighten 
        led <= 1'b0;                 
    else if (timer == 28'd199_999_999)    //time counter count to 1.0 sec,LED1 off
        led <= 1'b1;                           
end
    
endmodule