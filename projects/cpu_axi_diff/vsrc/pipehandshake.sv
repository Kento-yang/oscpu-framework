//CODER-YCT R1.0

//handshake for 5 pipeline CPU
//    --VALID->   --VALID->  --VALID->   --VALID->
//  IF          ID         EX         MEM         WB
//    <--READY-   <--READY-  <--READY-   <--READY-

//ready depends on valid but valid is free, so avoid lock.
`include "rvseed_defines.sv"
module pipehandshake(
    input clk,
    input rst_n,
    input valid_pre_i,
    input ready_next_i,
    //input data_in, 
    
    output logic valid_o_next,
    output logic ready_o_pre
    //output data_out
);

assign ready_o_pre = ~valid_o_next || ready_next_i;//pre-fetch   A + ~AB = A+B

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        valid_o_next <= 0;
    else if(ready_o_pre) //ready_next_i
        valid_o_next <= valid_pre_i; 
end

endmodule