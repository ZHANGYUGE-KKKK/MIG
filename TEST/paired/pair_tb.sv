`timescale 1ns/1ps
module pair_tb;
 parameter integer CLK_HZ=200000000;
 reg clk=0;always #(500000000.0/CLK_HZ) clk=~clk;
 reg rst=1,ui_reset=0,calib_complete=0;
 wire [28:0] app_addr;wire [2:0] app_cmd;wire app_en;
 reg app_rdy=0,app_wdf_rdy=0;
 wire [127:0] app_wdf_data;wire [15:0] app_wdf_mask;wire app_wdf_wren,app_wdf_end;
 reg [127:0] app_rd_data=0;reg app_rd_data_valid=0,app_rd_data_end=0;
 wire [511:0] record_data;wire record_valid,done;reg record_ready=0;
 ddr_pair #(.REGION_BURSTS(128),.CLK_HZ(CLK_HZ),.TIMEOUT(1000)) dut(.*);
 reg [127:0] mem[0:127],wf[0:511],rq[0:511];
 integer due[0:511];integer wt=0,wh=0,rt=0,rh=0,cycle=0,run,configs,results,samples,hists,groups,chunks;
 integer returned,job_errors,hist_sum,max_pending,expected_errors,expected_changes,group_writes;
 reg inject,model_enabled=1,bad_end=0,unsolicited=0;reg [31:0] rng=32'h9276ac55;
 reg [63:0] f[0:7];reg [7:0] packed_count;integer index,expected_count;
 function automatic [127:0] reference(input [28:0] a,input integer pat);
  reg [127:0] value;reg [31:0] z;integer k;
  begin
   value='1;
   if(pat==4)value[integer'(a)/8%128]=0;
   if(pat==5)begin
    z=0;
    for(k=0;k<4;k++)begin z=32'(a)^32'h137a5c29^(32'h9e3779b9*32'(k+1));z^=z<<13;z^=z>>17;z^=z<<5;value[k*32+:32]=z;end
   end
   return value;
  end
 endfunction
 always @(negedge clk) begin
  cycle=cycle+1;rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
  app_rdy=rng[0] && model_enabled;app_wdf_rdy=rng[2] && model_enabled;
  if(dut.state==2 && dut.wlimit==32 && dut.wc==0 && dut.wd<32)app_rdy=0;
  record_ready=rng[4];app_rd_data_valid=0;app_rd_data_end=0;
  if(!rst && model_enabled && rh<rt && due[rh%512]<=cycle)begin
   app_rd_data=rq[rh%512];app_rd_data_valid=1;app_rd_data_end=!bad_end;rh++;
  end
  if(unsolicited)begin app_rd_data_valid=1;app_rd_data_end=1;end
 end
 always @(posedge clk)begin
  if(!rst && model_enabled)begin
   if(app_wdf_wren && app_wdf_rdy)begin
    if(dut.leg!=0)$fatal(1,"DDR rewritten between read legs");
    if(!app_wdf_end || app_wdf_mask!=0)$fatal(1,"write flags");
    if(app_wdf_data!==reference(dut.da,integer'(dut.pattern)))$fatal(1,"independent write payload mismatch");
    wf[wt%512]=app_wdf_data;wt++;
   end
   if(app_en && app_rdy)begin
    if(app_cmd==0)begin
     if(dut.leg!=0 || wh==wt)$fatal(1,"unexpected write command");
     mem[app_addr[9:3]]=wf[wh%512];wh++;group_writes++;
     if(inject && app_addr==72)mem[9][124]^=1;
     if(inject && app_addr==1016)mem[127][50]^=1; // stable write corruption
    end else begin
     if(wt!=wh)$fatal(1,"read while writes unmatched");
     rq[rt%512]=mem[app_addr[9:3]];
     if(inject && app_addr==40 && !dut.leg[0])rq[rt%512][65]^=1;
     if(inject && app_addr==136)rq[rt%512][dut.leg[0]?124:65]^=1;
     due[rt%512]=cycle+120;rt++;returned++;
    end
   end
   if(rt-rh>integer'(dut.rlimit))$fatal(1,"read queue limit");
   if(wt-wh>integer'(dut.wlimit))$fatal(1,"write queue limit");
   if(rt-rh>max_pending)max_pending=rt-rh;
   if(record_valid && record_ready)begin
    for(integer k=0;k<8;k++)f[k]=record_data[511-k*64-:64];
    case(f[0][63:32])
     9:if(f[2]!=64'(CLK_HZ) || f[7]!=198)$fatal(1,"clock/image header");
     1:begin
      if(configs>0 && hist_sum!=job_errors)$fatal(1,"histogram mismatch");
      if(rt!=rh || wt!=wh || dut.check_v1 || dut.check_v2 || dut.check_v3 || dut.check_v4)$fatal(1,"pipeline not drained");
      if(f[0][31:0]!=32'(configs))$fatal(1,"missing job");
      if(f[1][31:0]!=32'(configs%11) || f[1][63:32]!=32'(configs/11))$fatal(1,"leg/group descriptor");
      if(f[7]!=(((configs%11)%2==0)?0:(64'(CLK_HZ)/3125000)))$fatal(1,"fixed wall-time gap");
      if(dut.leg==0)group_writes=0;
      configs++;returned=0;hist_sum=0;max_pending=0;
     end
     2:begin
      expected_errors=inject?(dut.leg[0]?3:4):0;
      expected_changes=(inject && dut.leg!=0)?2:0;
      job_errors=expected_errors;
      if(f[1]!=f[2] || f[1]!=(dut.leg==0?128:0) || f[3]!=128 || f[4]!=128)$fatal(1,"coverage counter");
      if(f[5]!=64'(expected_errors) || f[6]!=64'(expected_changes))$fatal(1,"error/variation counters %0d %0d",f[5],f[6]);
      if(dut.read_gap==0 && max_pending<integer'(dut.rlimit)-1)$fatal(1,"high concurrency not exercised");
      results++;
     end
     3:begin if((f[2]^f[4])==0 && (f[3]^f[5])==0)$fatal(1,"error sample");samples++;end
     4:begin hist_sum+=integer'(f[2]);hists++;end
     7:begin
      if((f[1][31:0]!=0 && f[1][31:0]!=96) || !inject)$fatal(1,"unexpected nonzero address chunk");
      for(integer k=0;k<48;k++)begin
       packed_count=8'(record_data>>((47-k)*8));
       index=integer'(f[1][31:0])+k;
       expected_count=(index==5)?32'hA6:((index==9 || index==127)?32'h0B:((index==17)?32'hAB:0));
       if(packed_count!=8'(expected_count))$fatal(1,"per-address error/variation mismatch %0d %h",k,packed_count);
      end
      chunks++;
     end
     8:begin
      if(group_writes!=128)$fatal(1,"write-once region not covered");
      if(f[2]!=(inject?39:0) || f[3]!=(inject?20:0) || f[4]!=(inject?2:0))$fatal(1,"group summary");groups++;
     end
     5:if(f[1]!=(inject?702:0))$fatal(1,"grand total");
     6:$fatal(1,"unexpected fatal %h",f[1]);
     default:$fatal(1,"bad record");
    endcase
   end
  end
 end
 task automatic reset_model;
  begin
   rst=1;calib_complete=0;repeat(5)@(negedge clk);
   wt=0;wh=0;rt=0;rh=0;configs=0;results=0;samples=0;hists=0;groups=0;chunks=0;
   returned=0;job_errors=0;hist_sum=0;max_pending=0;group_writes=0;rst=0;calib_complete=1;
  end
 endtask
 initial begin
  for(run=0;run<2;run++)begin
   inject=(run==1);reset_model();wait(done);repeat(10)@(negedge clk);
   if(results!=198 || configs!=198 || groups!=18 || chunks!=(inject?36:0))$fatal(1,"incomplete jobs/groups/chunks");
   $display("PASS paired 198 legs/18 groups write-once, previous-value and per-address checks, inject=%0d CLK=%0d",inject,CLK_HZ);
  end
  model_enabled=0;rst=1;repeat(3)@(negedge clk);rst=0;calib_complete=0;
  wait(done);if(dut.fatal_code!=1)$fatal(1,"calibration timeout");
  for(run=0;run<2;run++)begin
   model_enabled=1;inject=0;reset_model();wait(dut.state==2);@(negedge clk);
   if(run==0)calib_complete=0;else ui_reset=1;
   @(negedge clk);if(!done || dut.fatal_code!=32'(run+2))$fatal(1,"reset/calibration fault");ui_reset=0;
  end
  model_enabled=0;rst=1;repeat(3)@(negedge clk);rst=0;calib_complete=1;
  wait(done);if(dut.fatal_code!=4)$fatal(1,"write timeout");
  model_enabled=1;reset_model();bad_end=1;
  wait(done);if(dut.fatal_code!=5)$fatal(1,"missing end");bad_end=0;
  reset_model();wait(dut.state==2);@(negedge clk);unsolicited=1;
  wait(done);if(dut.fatal_code!=5)$fatal(1,"unexpected response");unsolicited=0;
  reset_model();wait(dut.state==4);@(negedge clk);model_enabled=0;
  wait(done);if(dut.fatal_code!=4)$fatal(1,"read timeout");
  model_enabled=1;reset_model();wait(dut.state==5);@(negedge clk);calib_complete=0;
  @(negedge clk);if(!done || dut.fatal_code!=2)$fatal(1,"calibration loss while reporting");
  $display("PAIRED SIMULATION PASSED");$finish;
 end
 initial begin #100000000;$fatal(1,"global timeout");end
endmodule
