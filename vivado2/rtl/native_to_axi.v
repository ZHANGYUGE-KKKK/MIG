`timescale 1ns/1ps
// Native-format frontend -> AXI4 single 16-byte burst. No CPU or queues.
// A native write is acknowledged only AFTER the AXI write response succeeds.
module native_to_axi (
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 100000000, ASSOCIATED_RESET rst:axi_aresetn, ASSOCIATED_BUSIF M_AXI" *) input wire clk,
 input wire rst,ui_reset,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 axi_aresetn RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) output wire axi_aresetn,
 input wire [28:0] app_addr,input wire [2:0] app_cmd,input wire app_en,output wire app_rdy,
 input wire [127:0] app_wdf_data,input wire [15:0] app_wdf_mask,input wire app_wdf_wren,app_wdf_end,output wire app_wdf_rdy,
 output wire [127:0] app_rd_data,output wire app_rd_data_valid,app_rd_data_end,
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
 localparam [2:0] IDLE=0,WRITE=1,WACK=2,READ=3,FAULT=4;
 reg [2:0] state;
 reg have_data,aw_pending,w_pending;
 reg [127:0] saved_data;
 reg [15:0] saved_mask;
 reg [29:0] saved_addr;
 wire enabled=!rst && !ui_reset;
 wire read_request=state==IDLE && !have_data && app_en && app_cmd==3'b001 && enabled;
 wire read_accept=read_request && m_axi_arready;
 assign axi_aresetn=enabled;
 assign app_wdf_rdy=state==IDLE && !have_data && enabled;
 assign app_rdy=enabled && ((state==WACK) || (read_request && m_axi_arready));
 assign m_axi_awaddr=saved_addr;
 assign m_axi_awid=0;assign m_axi_awlen=0;assign m_axi_awsize=4;assign m_axi_awburst=1;
 assign m_axi_awlock=0;assign m_axi_awcache=0;assign m_axi_awprot=0;assign m_axi_awqos=0;
 assign m_axi_awvalid=state==WRITE && aw_pending && enabled;
 assign m_axi_wdata=saved_data;assign m_axi_wstrb=~saved_mask;assign m_axi_wlast=1;
 assign m_axi_wvalid=state==WRITE && w_pending && enabled;
 assign m_axi_bready=state==WRITE && !aw_pending && !w_pending && enabled;
 assign m_axi_arid=0;assign m_axi_arlen=0;assign m_axi_arsize=4;assign m_axi_arburst=1;
 assign m_axi_arlock=0;assign m_axi_arcache=0;assign m_axi_arprot=0;assign m_axi_arqos=0;
 assign m_axi_araddr={app_addr,1'b0};
 assign m_axi_arvalid=read_request;
 assign m_axi_rready=(state==READ || read_accept) && enabled;
 assign app_rd_data=m_axi_rdata;
 assign app_rd_data_valid=m_axi_rvalid && m_axi_rready;
 assign app_rd_data_end=m_axi_rlast && m_axi_rresp==0 && m_axi_rid==0;
 always @(posedge clk) begin
  if(!enabled) begin state<=IDLE;have_data<=0;aw_pending<=0;w_pending<=0;saved_data<=0;saved_mask<=0;saved_addr<=0;end
  else begin
   if(app_wdf_wren && app_wdf_rdy) begin
    saved_data<=app_wdf_data;saved_mask<=app_wdf_mask;have_data<=1;
    if(!app_wdf_end)state<=FAULT;
   end
   case(state)
    IDLE:if(app_en && app_cmd==0 && have_data) begin
     if(app_addr[2:0]!=0)state<=FAULT;
     else begin saved_addr<={app_addr,1'b0};aw_pending<=1;w_pending<=1;state<=WRITE;end
    end else if(read_accept)begin
     if(app_addr[2:0]!=0)state<=FAULT;else state<=READ;
    end
    WRITE:begin
     if(m_axi_awvalid && m_axi_awready)aw_pending<=0;
     if(m_axi_wvalid && m_axi_wready)w_pending<=0;
     if(m_axi_bvalid && m_axi_bready)begin
      if(m_axi_bresp==0 && m_axi_bid==0)state<=WACK;else state<=FAULT;
     end
    end
    WACK:if(app_en && app_rdy)begin state<=IDLE;have_data<=0;end
    default:begin end
   endcase
   if(app_rd_data_valid) begin
    if(app_rd_data_end)state<=IDLE;else state<=FAULT;
   end
  end
 end
endmodule
