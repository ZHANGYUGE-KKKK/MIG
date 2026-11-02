`timescale 1ns/1ps
module uart_block #(parameter integer CLK_HZ=100000000)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 100000000, ASSOCIATED_RESET rst" *) input wire clk,
 input wire rst,input wire [511:0] record_data,input wire record_valid,
 output wire record_ready,output wire tx);
 probe_uart #(.CLK_HZ(CLK_HZ)) transmitter(.clk(clk),.rst(rst),.record_data(record_data),.record_valid(record_valid),.record_ready(record_ready),.tx(tx));
endmodule
