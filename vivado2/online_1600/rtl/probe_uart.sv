`timescale 1ns/1ps
// Fixed records: D followed by eight 64-bit hexadecimal fields, CRLF.
module probe_uart #(parameter integer CLK_HZ=200000000, BAUD=115200)(
 input wire clk,rst,input wire [511:0] record_data,input wire record_valid,
 output wire record_ready,output wire tx);
 reg active; reg [7:0] pos; reg [511:0] saved;
 wire ready; reg [7:0] data; reg [3:0] nibble;
 assign record_ready=!active;
 uart_tx #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) uart(.clk(clk),.rst(rst),.valid(active),.data(data),.ready(ready),.tx(tx));
 always @* begin
  nibble=saved[511:508];
  data=8'h20;
  if(pos==0) data="D";
  else if(pos==137) data=13;
  else if(pos==138) data=10;
  else if((pos-1)%17!=0) data=(nibble<10)?(8'h30+{4'b0,nibble}):(8'h41+{4'b0,nibble}-10);
 end
 always @(posedge clk) begin
  if(rst) begin active<=0;pos<=0;saved<=0;end
  else if(!active) begin
   if(record_valid) begin active<=1;pos<=0;saved<=record_data;end
  end else if(ready) begin
   if(pos>0 && pos<137 && (pos-1)%17!=0) saved<=saved<<4;
   if(pos==138) active<=0;else pos<=pos+1'b1;
  end
 end
endmodule
