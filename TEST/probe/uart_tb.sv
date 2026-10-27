`timescale 1ns/1ps
module uart_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,record_valid=0;reg [511:0] record_data;
 wire record_ready,tx;
 probe_uart #(.CLK_HZ(1000000),.BAUD(100000)) dut(.*);
 reg [7:0] c;integer i,k;string line;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  record_data=512'h00000001000000000000000000000001000000000000000200000000000000030000000000000004000000000000000500000000000000060000000000000007;
  record_valid=1;@(negedge clk);record_valid=0;
  for(i=0;i<139;i++)begin
   @(negedge tx);repeat(15)@(posedge clk);
   for(k=0;k<8;k++)begin c[k]=tx;repeat(10)@(posedge clk);end
   if(tx!=1)$fatal(1,"UART stop bit");line={line,string'(c)};
  end
  if(line!="D 0000000100000000 0000000000000001 0000000000000002 0000000000000003 0000000000000004 0000000000000005 0000000000000006 0000000000000007\r\n")$fatal(1,"UART record mismatch %s",line);
  $display("UART SERIALIZATION PASSED");$finish;
 end
 initial begin #2000000;$fatal(1,"UART timeout");end
endmodule
