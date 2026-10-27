`timescale 1ns/1ps
module databit_uart_tb;
 parameter integer CLK_HZ=100000000;
 localparam integer DIV=(CLK_HZ+57600)/115200;
 reg clk=0;always #(500000000.0/CLK_HZ) clk=~clk;
 reg rst=1,record_valid=0;reg [511:0] record_data;
 wire record_ready,tx;
 probe_uart #(.CLK_HZ(CLK_HZ),.BAUD(115200)) dut(.*);
 reg [7:0] c;integer i,k;string line;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  record_data=512'h000000094450494e00000000000000010000000005f5e10000000000000000640000000000000020000000000000010400000000000000800000000000000320;
  if(!record_ready)$fatal(1,"UART not ready after reset");
  record_valid=1;@(negedge clk);record_valid=0;
  for(i=0;i<139;i++)begin
   @(negedge tx);repeat(DIV+DIV/2)@(posedge clk);
   for(k=0;k<8;k++)begin c[k]=tx;repeat(DIV)@(posedge clk);end
   if(tx!=1)$fatal(1,"UART stop bit");line={line,string'(c)};
  end
  if(line!="D 000000094450494E 0000000000000001 0000000005F5E100 0000000000000064 0000000000000020 0000000000000104 0000000000000080 0000000000000320\r\n")$fatal(1,"UART record mismatch %s",line);
  $display("UART SERIALIZATION PASSED");$finish;
 end
 initial begin #50000000;$fatal(1,"UART timeout");end
endmodule
