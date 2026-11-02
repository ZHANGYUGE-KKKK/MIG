`timescale 1ns/1ps
module tb;
reg  clk;
reg  rst;
reg  ui_reset;
wire  axi_aresetn;
reg  start;
reg calib_complete;reg cfg_large=0;
wire [511:0] debug_summary;
wire [511:0] debug_legs;
wire [511:0] debug_dq;
wire [319:0] debug_first;
wire [127:0] debug_expected;
wire  done;
wire [511:0] record_data;
wire record_valid;
reg  record_ready;
wire [0:0] m_axi_awid;
wire [29:0] m_axi_awaddr;
wire [7:0] m_axi_awlen;
wire [2:0] m_axi_awsize;
wire [1:0] m_axi_awburst;
wire  m_axi_awlock;
wire [3:0] m_axi_awcache;
wire [2:0] m_axi_awprot;
wire [3:0] m_axi_awqos;
wire  m_axi_awvalid;
reg  m_axi_awready;
wire [127:0] m_axi_wdata;
wire [15:0] m_axi_wstrb;
wire  m_axi_wlast;
wire  m_axi_wvalid;
reg  m_axi_wready;
reg [0:0] m_axi_bid;
reg [1:0] m_axi_bresp;
reg  m_axi_bvalid;
wire  m_axi_bready;
wire [0:0] m_axi_arid;
wire [29:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire  m_axi_arlock;
wire [3:0] m_axi_arcache;
wire [2:0] m_axi_arprot;
wire [3:0] m_axi_arqos;
wire  m_axi_arvalid;
reg  m_axi_arready;
reg [0:0] m_axi_rid;
reg [127:0] m_axi_rdata;
reg [1:0] m_axi_rresp;
reg  m_axi_rlast;
reg  m_axi_rvalid;
wire  m_axi_rready;
 initial clk=0;always #5 clk=~clk;
 online_axi_diag #(.REGION_BEATS(2048),.LARGE_BEATS(4096),.LEGS(4),.SPARSE_GAP(7),.TIMEOUT(10000)) dut(.*);
 reg [127:0] memory[0:4095],reference_data[0:4095];
 initial $readmemh("vivado2/online_800_burst/tests/expected_payload.mem",reference_data);
 integer cycle=0,wa=0,wl=0,ra=0,rl=0,write_count=0,read_count=0,mode=0;
 reg awactive=0;
 integer requests[0:8191];integer head=0,tail=0,rb=0;
 reg [31:0] rng=32'h8832a0f1;
 initial begin
  rst=1;ui_reset=0;cfg_large=0;start=0;calib_complete=0;record_ready=1;
  m_axi_awready=0;m_axi_wready=0;m_axi_bvalid=0;m_axi_bresp=0;m_axi_bid=0;
  m_axi_arready=0;m_axi_rvalid=0;m_axi_rdata=0;m_axi_rid=0;m_axi_rresp=0;m_axi_rlast=0;
  if($value$plusargs("MODE=%d",mode))begin end
  cfg_large=(mode==6);
  repeat(5)@(negedge clk);rst=0;start=1;calib_complete=1;
  wait(done);#1;
  if(mode<2 || mode==6)begin
   if(dut.fatal_code!=0 || write_count!=(cfg_large?4096:2048) || read_count!=(cfg_large?16384:8192) || dut.writes!=(cfg_large?4096:2048) || dut.reads!=(cfg_large?16384:8192))$fatal(1,"counter/fatal mismatch");
   if(dut.peak_outstanding!=32)$fatal(1,"multiple outstanding not exercised");
   if(dut.errors!=(mode==1?4:0))$fatal(1,"error mismatch %d",dut.errors);
   if(mode==1 && (dut.errors_dq[9]!=4 || dut.errors_leg[0]!=1 || dut.errors_leg[2]!=1 || !dut.first_valid || dut.first_addr!=144))$fatal(1,"DQ9/leg/address mapping");
  end else if(mode==2 && dut.fatal_code!=2)$fatal(1,"RLAST injection not caught");
  else if(mode==3 && dut.fatal_code!=1)$fatal(1,"BRESP injection not caught");
  else if(mode==4 && dut.fatal_code!=4)$fatal(1,"timeout not caught");
  else if(mode==5 && dut.fatal_code!=3)$fatal(1,"calibration loss not caught");
  $display("ONLINE_AXI_SIM_PASS mode=%0d W=%0d R=%0d err=%0d fatal=%0d",mode,dut.writes,dut.reads,dut.errors,dut.fatal_code);$finish;
 end
 always @(negedge clk)begin
  rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
  m_axi_awready=!awactive && !m_axi_bvalid && rng[0] && mode!=4;
  m_axi_wready=awactive && rng[1];
  m_axi_arready=(tail-head<32) && rng[2];
  if(!m_axi_rvalid || m_axi_rready)begin
   m_axi_rvalid=(tail>head) && rng[3] && (tail>=32);
   ra=requests[head]+rb;
   m_axi_rdata=memory[ra];
   if(mode==1 && ra==9 )m_axi_rdata[65]=~m_axi_rdata[65];
   m_axi_rlast=(rb==31);
   if(mode==2 && ra==5)m_axi_rlast=1;
  end
  if(mode==5 && write_count>20)calib_complete=0;
 end
 always @(posedge clk)if(!rst)begin
  cycle=cycle+1;
  if(cycle>200000)$fatal(1,"TB timeout");
  if(m_axi_awvalid && m_axi_awready)begin
   if(m_axi_awlen!=31 || m_axi_awaddr[8:0]!=0 || m_axi_awsize!=4 || m_axi_awburst!=1)$fatal(1,"write framing");
   awactive<=1;wa<=int'(m_axi_awaddr)>>4;wl<=32;
  end
  if(m_axi_wvalid && m_axi_wready)begin
   if(!awactive || m_axi_wlast!=(wl==1) || m_axi_wstrb!=16'hffff)$fatal(1,"write protocol");
   if(m_axi_wdata!==reference_data[wa])$fatal(1,"independent PRNG payload mismatch");
   memory[wa]<=m_axi_wdata;wa<=wa+1;wl<=wl-1;write_count<=write_count+1;
   if(wl==1)begin awactive<=0;m_axi_bvalid<=1;m_axi_bresp<=(mode==3)?2:0;end
  end
  if(m_axi_bvalid && m_axi_bready)m_axi_bvalid<=0;
  if(m_axi_arvalid && m_axi_arready)begin
   if(m_axi_araddr[3:0]!=0 || (m_axi_arlen!=0 && m_axi_arlen!=31) || m_axi_arsize!=4)$fatal(1,"read framing");
   if(m_axi_arlen!=31 || m_axi_araddr[8:0]!=0)$fatal(1,"expected aligned 32-beat requests");
   requests[tail]<=int'(m_axi_araddr)>>4;tail<=tail+1;
  end
  if(m_axi_rvalid && m_axi_rready)begin
   if(rb==31)begin head<=head+1;rb<=0;end else rb<=rb+1;read_count<=read_count+1;
  end
 end
endmodule
