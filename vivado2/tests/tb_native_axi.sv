`timescale 1ns/1ps
module tb_native_axi;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ui_reset=0;wire axi_aresetn;
 reg [28:0] app_addr=0;reg [2:0] app_cmd=0;reg app_en=0;wire app_rdy;
 reg [127:0] app_wdf_data=0;reg [15:0] app_wdf_mask=0;reg app_wdf_wren=0,app_wdf_end=0;
 wire app_wdf_rdy;wire [127:0] app_rd_data;wire app_rd_data_valid,app_rd_data_end;
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
 reg  m_axi_awready=0;
 wire [127:0] m_axi_wdata;
 wire [15:0] m_axi_wstrb;
 wire  m_axi_wlast;
 wire  m_axi_wvalid;
 reg  m_axi_wready=0;
 reg [0:0] m_axi_bid=0;
 reg [1:0] m_axi_bresp=0;
 reg  m_axi_bvalid=0;
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
 reg  m_axi_arready=0;
 reg [0:0] m_axi_rid=0;
 wire [127:0] m_axi_rdata;
 reg [127:0] model_rdata=0;
 reg [1:0] m_axi_rresp=0;
 reg  m_axi_rlast=0;
 wire m_axi_rvalid;
 reg model_rvalid=0;
 wire  m_axi_rready;
 native_to_axi dut(.*);
 assign m_axi_rdata=(mode==8 && m_axi_arvalid)?memory[slot_for(m_axi_araddr)]:model_rdata;
 assign m_axi_rvalid=(mode==8)?(m_axi_arvalid && m_axi_arready):model_rvalid;
 integer mode=0,ticks=0,n=0,j=0,aw_count=0,w_count=0,b_count=0,ar_count=0,r_count=0;
 integer pending=-1,bdelay=-1,rdelay=-1,idx;
 reg aw_seen=0,w_seen=0,allow_ready=1;
 reg [29:0] write_address;
 reg [127:0] write_data,memory[0:31],read_snapshot;
 reg [31:0] random_state=32'h54672139;
 reg aw_held=0,w_held=0,ar_held=0;
 reg [29:0] aw_saved,ar_saved;reg [127:0] w_saved;
 wire [127:0] normal_data=m_axi_rdata;
 function automatic [28:0] address(input integer slot);
  case(slot/8)
   0:address=29'(slot*8);
   1:address=29'h1fffffc0+29'((slot-8)*8);
   2:address=29'h10000000+29'((slot-16)*8);
   default:address=29'h2000+29'((slot-24)*8);
  endcase
 endfunction
 function automatic integer slot_for(input [29:0] byte_addr);
  integer t;begin
   slot_for=-1;
   for(t=0;t<32;t=t+1)if(byte_addr=={address(t),1'b0})slot_for=t;
  end
 endfunction
 function automatic [127:0] pattern(input integer p);
  reg [127:0] value;integer bitnum;
  begin
   for(bitnum=0;bitnum<128;bitnum=bitnum+1)
    if(p<128)value[bitnum]=bitnum==p;
    else if(p<256)value[bitnum]=bitnum!=p-128;
    else if(p==256)value[bitnum]=0;
    else if(p==257)value[bitnum]=1;
    else if(p==258)value[bitnum]=bitnum%2==1;
    else value[bitnum]=bitnum%2==0;
   pattern=value;
  end
 endfunction
 task automatic send_write(input [28:0] addr,input [127:0] data);
  begin
   @(negedge clk);app_wdf_data=data;app_wdf_wren=1;app_wdf_end=1;
   do @(posedge clk);while(!app_wdf_rdy);
   @(negedge clk);app_wdf_wren=0;app_wdf_end=0;app_addr=addr;app_en=1;app_cmd=0;
   do @(posedge clk);while(!app_rdy);
   if(b_count!=aw_count || b_count!=w_count || aw_count==0)$fatal(1,"write acknowledged before B response");
   @(negedge clk);app_en=0;
  end
 endtask
 task automatic send_read(input [28:0] addr,input [127:0] data,input bit expect_bad);
  reg early;reg [127:0] got;reg last;
  begin
   @(negedge clk);app_addr=addr;app_en=1;app_cmd=1;
   do @(posedge clk);while(!app_rdy);
   early=app_rd_data_valid;got=app_rd_data;last=app_rd_data_end;
   @(negedge clk);app_en=0;
   if(!early)begin
    do @(posedge clk);while(!app_rd_data_valid);
    got=app_rd_data;last=app_rd_data_end;
   end
   if(expect_bad)begin if(last)$fatal(1,"AXI error hidden from native frontend");end
   else if(!last || got!==data)$fatal(1,"read data mismatch addr=%h got=%h exp=%h",addr,got,data);
   @(negedge clk);
  end
 endtask
 always @(negedge clk)begin
  if(rst || ui_reset)begin
   m_axi_awready=0;m_axi_wready=0;m_axi_arready=0;m_axi_bvalid=0;model_rvalid=0;bdelay=-1;rdelay=-1;
  end else begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   m_axi_awready=allow_ready && random_state[0];m_axi_wready=allow_ready && random_state[2];m_axi_arready=random_state[4];
   m_axi_bresp=(mode==1)?2:0;m_axi_bid=(mode==3)?1:0;
   if(aw_seen && w_seen)begin
    if(bdelay<0)bdelay=int'(random_state[11:8]);
    else if(bdelay==0)m_axi_bvalid=1;
    else bdelay=bdelay-1;
   end else begin m_axi_bvalid=0;bdelay=-1;end
   m_axi_rresp=(mode==2)?2:0;m_axi_rid=(mode==4)?1:0;m_axi_rlast=(mode!=5);
   if(pending>=0)begin
    if(rdelay==0)begin
     model_rdata=read_snapshot;
     if(mode==9)model_rdata[(ar_count-1)%128]=~model_rdata[(ar_count-1)%128];
     model_rvalid=1;
    end else rdelay=rdelay-1;
   end else model_rvalid=0;
  end
 end
 always @(posedge clk)begin
  ticks=ticks+1;if(ticks>5000000)$fatal(1,"test watchdog");
  if(rst || ui_reset)begin aw_seen=0;w_seen=0;pending=-1;aw_held=0;w_held=0;ar_held=0;end
  else begin
   if(!axi_aresetn)$fatal;
   if(aw_held && (!m_axi_awvalid || m_axi_awaddr!==aw_saved))$fatal(1,"AW unstable");
   if(w_held && (!m_axi_wvalid || m_axi_wdata!==w_saved))$fatal(1,"W unstable");
   if(ar_held && (!m_axi_arvalid || m_axi_araddr!==ar_saved))$fatal(1,"AR unstable");
   aw_held=m_axi_awvalid && !m_axi_awready;aw_saved=m_axi_awaddr;
   w_held=m_axi_wvalid && !m_axi_wready;w_saved=m_axi_wdata;
   ar_held=m_axi_arvalid && !m_axi_arready;ar_saved=m_axi_araddr;
   if(m_axi_awvalid && m_axi_awready)begin
    if(aw_seen || m_axi_awid!=0 || m_axi_awlen!=0 || m_axi_awsize!=4 || m_axi_awburst!=1 || m_axi_awlock!=0 || m_axi_awcache!=0 || m_axi_awprot!=0 || m_axi_awqos!=0)$fatal(1,"bad AW");
    if(slot_for(m_axi_awaddr)<0)$fatal(1,"address conversion");
    aw_seen=1;write_address=m_axi_awaddr;aw_count=aw_count+1;
   end
   if(m_axi_wvalid && m_axi_wready)begin
    if(w_seen || !m_axi_wlast || m_axi_wstrb!=16'hffff)$fatal(1,"bad W");
    w_seen=1;write_data=m_axi_wdata;w_count=w_count+1;
   end
   if(m_axi_bvalid && m_axi_bready)begin
    if(!aw_seen || !w_seen)$fatal(1,"B before AW/W");
    memory[slot_for(write_address)]=write_data;aw_seen=0;w_seen=0;b_count=b_count+1;
   end
   if(m_axi_arvalid && m_axi_arready)begin
    if(pending>=0 || aw_seen || w_seen || m_axi_arid!=0 || m_axi_arlen!=0 || m_axi_arsize!=4 || m_axi_arburst!=1 || m_axi_arlock!=0 || m_axi_arcache!=0 || m_axi_arprot!=0 || m_axi_arqos!=0)$fatal(1,"bad AR");
    idx=slot_for(m_axi_araddr);if(idx<0)$fatal(1,"bad read address");
    pending=idx;read_snapshot=memory[idx];rdelay=(mode==7)?100:int'(random_state[15:12]);ar_count=ar_count+1;
   end
   if(m_axi_rvalid && m_axi_rready)begin if(pending<0)$fatal;pending=-1;r_count=r_count+1;end
  end
 end
 initial begin
  if(!$value$plusargs("MODE=%d",mode))mode=0;
  repeat(5)@(negedge clk);rst=0;
  if(mode==0 || mode==8 || mode==9)begin
   for(n=0;n<8320;n=n+1)begin
    send_write(address(n%32),pattern(n/32));repeat(100)@(posedge clk);
    if(mode==9)send_read(address(n%32),pattern(n/32)^(128'b1<<(n%128)),0);
    else send_read(address(n%32),pattern(n/32),0);
    repeat(100)@(posedge clk);
   end
   if(aw_count!=8320 || w_count!=8320 || b_count!=8320 || ar_count!=8320 || r_count!=8320)$fatal(1,"incomplete coverage");
  end else if(mode==1 || mode==3)begin
   @(negedge clk);app_wdf_data=128'h123456789ABCDEF;app_wdf_wren=1;app_wdf_end=1;
   do @(posedge clk);while(!app_wdf_rdy);
   @(negedge clk);app_wdf_wren=0;app_wdf_end=0;app_en=1;
   repeat(150)begin @(posedge clk);if(app_rdy)$fatal(1,"write error acknowledged as success");end
   if(b_count!=1)$fatal(1,"write error not exercised");
  end else if(mode==2 || mode==4 || mode==5)begin
   send_write(address(31),128'h137a5c29);send_read(address(31),128'h137a5c29,1);
  end else if(mode==6)begin
   allow_ready=0;
   @(negedge clk);app_wdf_wren=1;app_wdf_end=1;
   do @(posedge clk);while(!app_wdf_rdy);
   @(negedge clk);app_wdf_wren=0;app_en=1;
   repeat(5)@(negedge clk);rst=1;app_en=0;
   repeat(4)@(negedge clk);rst=0;allow_ready=1;
   send_write(address(31),128'h56789);send_read(address(31),128'h56789,0);
  end else if(mode==7)begin
   send_write(address(0),128'h12345);
   @(negedge clk);app_en=1;app_cmd=1;
   do @(posedge clk);while(!app_rdy);
   @(negedge clk);app_en=0;ui_reset=1;
   repeat(4)@(negedge clk);if(app_rd_data_valid || axi_aresetn)$fatal(1,"reset did not suppress output");ui_reset=0;
   send_write(address(31),128'h6789);send_read(address(31),128'h6789,0);
  end
  $display("AXI BRIDGE PASSED mode=%0d AW=%0d W=%0d B=%0d AR=%0d R=%0d",mode,aw_count,w_count,b_count,ar_count,r_count);$finish;
 end
endmodule
