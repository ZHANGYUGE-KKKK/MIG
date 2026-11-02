`timescale 1ns/1ps
// Native-format frontend -> AXI4 single 16-byte burst. No CPU or queues.
// A native write is acknowledged only AFTER the AXI write response succeeds.
module online_axi_diag #(parameter integer REGION_BEATS=65536, LEGS=16, SPARSE_GAP=100, TIMEOUT=100000000) (
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 100000000, ASSOCIATED_RESET rst:axi_aresetn, ASSOCIATED_BUSIF M_AXI" *) input wire clk,
 input wire rst,ui_reset,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 axi_aresetn RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) output wire axi_aresetn,
 input wire start,calib_complete,
 output wire [511:0] debug_summary,debug_legs,debug_dq,
 output wire [319:0] debug_first,
 output wire [127:0] debug_expected,
 output wire done,
 output reg [511:0] record_data,output wire record_valid,input wire record_ready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWID" *) output wire [0:0] m_axi_awid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *) output wire [29:0] m_axi_awaddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *) output wire [7:0] m_axi_awlen,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *) output wire [2:0] m_axi_awsize,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *) output wire [1:0] m_axi_awburst,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWLOCK" *) output wire  m_axi_awlock,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *) output wire [3:0] m_axi_awcache,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *) output wire [2:0] m_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWQOS" *) output wire [3:0] m_axi_awqos,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *) output wire  m_axi_awvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *) input wire  m_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WDATA" *) output wire [127:0] m_axi_wdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *) output wire [15:0] m_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WLAST" *) output wire  m_axi_wlast,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WVALID" *) output wire  m_axi_wvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WREADY" *) input wire  m_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BID" *) input wire [0:0] m_axi_bid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BRESP" *) input wire [1:0] m_axi_bresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BVALID" *) input wire  m_axi_bvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BREADY" *) output wire  m_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARID" *) output wire [0:0] m_axi_arid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *) output wire [29:0] m_axi_araddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *) output wire [7:0] m_axi_arlen,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *) output wire [2:0] m_axi_arsize,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *) output wire [1:0] m_axi_arburst,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARLOCK" *) output wire  m_axi_arlock,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *) output wire [3:0] m_axi_arcache,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *) output wire [2:0] m_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARQOS" *) output wire [3:0] m_axi_arqos,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *) output wire  m_axi_arvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *) input wire  m_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RID" *) input wire [0:0] m_axi_rid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RDATA" *) input wire [127:0] m_axi_rdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RRESP" *) input wire [1:0] m_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RLAST" *) input wire  m_axi_rlast,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RVALID" *) input wire  m_axi_rvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RREADY" *) output wire  m_axi_rready
 );
 localparam [3:0] IDLE=0,AW=1,WD=2,BR=3,AR=4,RD=5,GAP=6,REPORT=7,FINISH=8,HALT=9,FAULT=10;
 (* keep="true" *) reg [3:0] state;
 reg [3:0] leg;
 reg [31:0] write_index,read_index,watchdog,gap_count;
 reg [4:0] write_beat,read_beat;
 reg [63:0] writes,reads,errors;
 reg [31:0] errors_leg[0:15],errors_dq[0:15];
 reg [7:0] fatal_code;
 reg first_valid;
 reg [29:0] first_addr;
 reg [127:0] first_expected,first_actual;
 reg [3:0] first_leg;
 wire enabled=!rst && !ui_reset;
 wire dense=!leg[0];
 function [127:0] payload(input [31:0] index);
  reg [31:0] z;integer k;
  begin
   for(k=0;k<4;k=k+1)begin
    z=(index<<3)^32'h137a5c29^(32'h9e3779b9*(k+1));
    z=z^(z<<13);z=z^(z>>17);z=z^(z<<5);
    payload[k*32+:32]=z;
   end
  end
 endfunction
 wire [127:0] expected=payload(read_index);
 wire [127:0] diff=m_axi_rdata^expected;
 function [3:0] dq_flips(input [127:0] delta,input integer dq);
  integer beat;
  begin
   dq_flips=0;
   for(beat=0;beat<8;beat=beat+1) dq_flips=dq_flips+{3'b0,delta[(dq/8)*64+beat*8+dq%8]};
  end
 endfunction
 assign axi_aresetn=enabled;
 assign m_axi_awid=0;assign m_axi_awaddr={write_index[25:0],4'b0};
 assign m_axi_awlen=31;assign m_axi_awsize=4;assign m_axi_awburst=1;
 assign m_axi_awlock=0;assign m_axi_awcache=0;assign m_axi_awprot=0;assign m_axi_awqos=0;
 assign m_axi_awvalid=state==AW && enabled;
 assign m_axi_wdata=payload(write_index);assign m_axi_wstrb=16'hffff;
 assign m_axi_wlast=write_beat==31;assign m_axi_wvalid=state==WD && enabled;
 assign m_axi_bready=state==BR && enabled;
 assign m_axi_arid=0;assign m_axi_araddr={read_index[25:0],4'b0};
 assign m_axi_arlen=dense?8'd31:8'd0;assign m_axi_arsize=4;assign m_axi_arburst=1;
 assign m_axi_arlock=0;assign m_axi_arcache=0;assign m_axi_arprot=0;assign m_axi_arqos=0;
 assign m_axi_arvalid=state==AR && enabled;assign m_axi_rready=state==RD && enabled;
 assign done=state==HALT || state==FAULT;
 assign debug_summary={32'h41584944,28'b0,state,28'b0,leg,24'b0,fatal_code,REGION_BEATS,LEGS,writes,reads,errors,read_index,write_index,SPARSE_GAP,32'h137a5c29};
 assign debug_first={29'b0,first_valid,first_leg,first_addr,first_expected,first_actual};
 assign debug_expected=expected;
 genvar g;
 generate for(g=0;g<16;g=g+1) begin:stats
  assign debug_legs[g*32+:32]=errors_leg[g];
  assign debug_dq[g*32+:32]=errors_dq[g];
 end endgenerate
 assign record_valid=state==REPORT || state==FINISH;
 always @* begin
  record_data=debug_summary;
  if(state==REPORT)record_data[511:480]=32'h4c454753;
 end
 integer i;
 wire progress=(m_axi_awvalid && m_axi_awready)||(m_axi_wvalid && m_axi_wready)||
               (m_axi_bvalid && m_axi_bready)||(m_axi_arvalid && m_axi_arready)||
               (m_axi_rvalid && m_axi_rready);
 always @(posedge clk) begin
  if(rst || !start)begin
   state<=IDLE;leg<=0;write_index<=0;read_index<=0;watchdog<=0;gap_count<=0;
   write_beat<=0;read_beat<=0;writes<=0;reads<=0;errors<=0;fatal_code<=0;
   first_valid<=0;first_addr<=0;first_expected<=0;first_actual<=0;first_leg<=0;
   for(i=0;i<16;i=i+1)begin errors_leg[i]<=0;errors_dq[i]<=0;end
  end else begin
   if(progress || state==IDLE || state==HALT || state==FAULT)watchdog<=0;
   else watchdog<=watchdog+1'b1;
   case(state)
    IDLE:if(calib_complete && !ui_reset)state<=AW;
    AW:if(m_axi_awready && m_axi_awvalid)begin write_beat<=0;state<=WD;end
    WD:if(m_axi_wready && m_axi_wvalid)begin
     writes<=writes+1'b1;write_index<=write_index+1'b1;
     if(write_beat==31)state<=BR;else write_beat<=write_beat+1'b1;
    end
    BR:if(m_axi_bvalid && m_axi_bready)begin
     if(m_axi_bresp!=0 || m_axi_bid!=0)begin fatal_code<=1;state<=FAULT;end
     else if(write_index==REGION_BEATS)begin state<=AR;read_index<=0;end
     else state<=AW;
    end
    AR:if(m_axi_arready && m_axi_arvalid)begin read_beat<=0;state<=RD;end
    RD:if(m_axi_rvalid && m_axi_rready)begin
     reads<=reads+1'b1;read_index<=read_index+1'b1;
     if(diff!=0)begin
      errors<=errors+1'b1;errors_leg[leg]<=errors_leg[leg]+1'b1;
      for(i=0;i<16;i=i+1)errors_dq[i]<=errors_dq[i]+{28'b0,dq_flips(diff,i)};
      if(!first_valid)begin first_valid<=1;first_addr<={read_index[25:0],4'b0};first_expected<=expected;first_actual<=m_axi_rdata;first_leg<=leg;end
     end
     if(m_axi_rresp!=0 || m_axi_rid!=0 || m_axi_rlast!=(dense?(read_beat==31):1'b1))begin fatal_code<=2;state<=FAULT;end
     else if(m_axi_rlast)begin
      if(read_index==REGION_BEATS-1)state<=REPORT;
      else if(dense)state<=AR;
      else begin gap_count<=0;state<=GAP;end
     end else read_beat<=read_beat+1'b1;
    end
    GAP:if(gap_count==SPARSE_GAP-1)state<=AR;else gap_count<=gap_count+1'b1;
    REPORT:if(record_ready)begin
     if({28'b0,leg}==LEGS-1)state<=FINISH;
     else begin leg<=leg+1'b1;read_index<=0;state<=AR;end
    end
    FINISH:if(record_ready)state<=HALT;
    default:begin end
   endcase
   if(state!=IDLE && state!=HALT && state!=FAULT)begin
    if(ui_reset || !calib_complete)begin fatal_code<=3;state<=FAULT;end
    else if(watchdog==TIMEOUT-1)begin fatal_code<=4;state<=FAULT;end
   end
  end
 end
endmodule
