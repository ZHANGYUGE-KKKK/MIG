`timescale 1ns/1ps
module tb_board_control;
 reg BADJ_CLK_clk_p=0;always #2 BADJ_CLK_clk_p=~BADJ_CLK_clk_p;
 wire BADJ_CLK_clk_n=~BADJ_CLK_clk_p;
 reg ui_clk=0;always #5 ui_clk=~ui_clk;
 reg sys_rst=0;wire ref_clk,mig_rst,app_reset;
 board_control dut(.*);
 initial begin
  #1;if(!mig_rst || !app_reset)$fatal(1,"missing power-on reset");
  repeat(65530)@(negedge BADJ_CLK_clk_p);
  if(!mig_rst)$fatal(1,"power-on reset too short");
  wait(!mig_rst);
  @(negedge ui_clk);if(!app_reset)$fatal(1,"reset not synchronized");
  repeat(4)@(negedge ui_clk);if(app_reset)$fatal(1,"reset did not release");
  #1;sys_rst=1;#1;if(!mig_rst || !app_reset)$fatal(1,"async reset assertion");
  #7;sys_rst=0;
  wait(!mig_rst);repeat(4)@(negedge ui_clk);if(app_reset)$fatal;
  $display("BOARD CONTROL PASSED");$finish;
 end
 always @(negedge ui_clk)if(ref_clk!==BADJ_CLK_clk_p)$fatal(1,"clock path");
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
module IBUFDS(input wire I,IB,output wire O);
 assign O=I;
 wire unused_n=IB;
endmodule
module BUFG(input wire I,output wire O);
 assign O=I;
endmodule
