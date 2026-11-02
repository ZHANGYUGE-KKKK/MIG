`timescale 1ns/1ps
// Board input clock and reset handling; memory traffic is a separate BD block.
module board_control (
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 BADJ_CLK_clk_p CLK", X_INTERFACE_PARAMETER="FREQ_HZ 250000000" *) input wire BADJ_CLK_clk_p,
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 BADJ_CLK_clk_n CLK", X_INTERFACE_PARAMETER="FREQ_HZ 250000000" *) input wire BADJ_CLK_clk_n,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 sys_rst RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_HIGH" *) input wire sys_rst,
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 ref_clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 250000000, ASSOCIATED_RESET mig_rst" *) output wire ref_clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 mig_rst RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_HIGH" *) output wire mig_rst,
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 ui_clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 100000000, ASSOCIATED_RESET app_reset" *) input wire ui_clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 app_reset RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_HIGH" *) output wire app_reset
);
 wire ref_clk_ibuf;
 IBUFDS ref_clk_ibufds (.I(BADJ_CLK_clk_p),.IB(BADJ_CLK_clk_n),.O(ref_clk_ibuf));
 BUFG ref_clk_bufg (.I(ref_clk_ibuf),.O(ref_clk));
 reg [15:0] por_count=0;
 (* ASYNC_REG="TRUE" *) reg [1:0] reset_sync=2'b11;
 always @(posedge ref_clk or posedge sys_rst)
  if(sys_rst)reset_sync<=2'b11;else reset_sync<={reset_sync[0],1'b0};
 always @(posedge ref_clk)
  if(reset_sync[1])por_count<=0;else if(!(&por_count))por_count<=por_count+1'b1;
 assign mig_rst=reset_sync[1] || !(&por_count);
 (* ASYNC_REG="TRUE" *) reg [2:0] app_reset_sync=3'b111;
 always @(posedge ui_clk or posedge mig_rst)
  if(mig_rst)app_reset_sync<=3'b111;else app_reset_sync<={app_reset_sync[1:0],1'b0};
 assign app_reset=app_reset_sync[2];
endmodule
