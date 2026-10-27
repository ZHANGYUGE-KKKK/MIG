`timescale 1ns/1ps
module probe_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ui_reset=0,calib_complete=0;
 wire [28:0] app_addr;wire [2:0] app_cmd;wire app_en;
 reg app_rdy=0,app_wdf_rdy=0;
 wire [127:0] app_wdf_data;wire [15:0] app_wdf_mask;wire app_wdf_wren,app_wdf_end;
 reg [127:0] app_rd_data=0;reg app_rd_data_valid=0,app_rd_data_end=0;
 wire [511:0] record_data;wire record_valid,done;reg record_ready=0;
 ddr_probe #(.REPEATS(32),.ORDER_ROUNDS(10),.REGION_BURSTS(32),.TIMEOUT(1000)) dut(.*);
 reg [127:0] mem[0:65535],wf[0:511],rq[0:511];
 integer due[0:511];integer wt,wh,rt,rh,cycle,run,configs,results,samples,hists;
 integer inj_expected,job_expected,returned,job_errors,hist_sum,expected_changes,max_pending;
 reg inject,model_enabled=1,bad_end=0,unsolicited=0;reg [31:0] rng=32'h9276ac55;
 reg [31:0] current_job; reg [63:0] f[0:7];
 function automatic [127:0] reference(input [28:0] a,input integer pat);
  reg [127:0] value;reg [31:0] z;integer k;
  begin
   value='1;
   if(pat==1)value=0;
   if(pat==2)value[65]=0;
   if(pat==3)value[124]=0;
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
  app_rdy=rng[0] && model_enabled;
  if(dut.state==2 && dut.wlimit==32 && dut.wc==0 && dut.wd<32) app_rdy=0;app_wdf_rdy=rng[2] && model_enabled;
  record_ready=rng[4];app_rd_data_valid=0;app_rd_data_end=0;
  if(!rst && model_enabled && rh<rt && due[rh%512]<=cycle)begin
   app_rd_data=rq[rh%512];app_rd_data_valid=1;app_rd_data_end=!bad_end;rh++;
  end
  if(unsolicited)begin app_rd_data_valid=1;app_rd_data_end=1;end
 end
 always @(posedge clk)begin
  if(!rst && model_enabled)begin
   if(app_wdf_wren && app_wdf_rdy)begin
    if(!app_wdf_end || app_wdf_mask!=0)$fatal(1,"write flags");
    if(app_wdf_data!==reference(dut.da,integer'(dut.pattern)))$fatal(1,"payload differs from independent reference");
    wf[wt%512]=app_wdf_data;wt++;
   end
   if(app_en && app_rdy)begin
    if(app_cmd==0)begin
     if(wh==wt)$fatal(1,"write command without accepted data");
     mem[app_addr[18:3]]=wf[wh%512];wh++;
    end else begin
     if(wt!=wh)$fatal(1,"read while writes unmatched");
     rq[rt%512]=mem[app_addr[18:3]];
     if(inject && ((current_job==0 && returned%2==1) || (current_job>=48 && returned%17==0)))begin
      rq[rt%512][(current_job==0)?65:124]^=1;job_errors++;inj_expected++;
     end
     due[rt%512]=cycle+120;rt++;returned++;
     if(rt-rh>32)$fatal(1,"FIFO overrun");
    end
   end
   if(rt-rh>integer'(dut.rlimit))$fatal(1,"runtime read limit exceeded");
   if(wt-wh>integer'(dut.wlimit))$fatal(1,"runtime write limit exceeded");
   if(rt-rh>max_pending)max_pending=rt-rh;
   if(record_valid && record_ready)begin
    for(integer k=0;k<8;k++) f[k]=record_data[511-k*64-:64];
    case(f[0][63:32])
     1:begin
      if(configs>0 && hist_sum!=job_errors)$fatal(1,"histogram total mismatch");
      if(rt!=rh || wt!=wh)$fatal(1,"stage boundary not drained");
      if(dut.check_v1 || dut.check_v2)$fatal(1,"comparison pipeline not drained");
      current_job=f[0][31:0];configs++;max_pending=0;returned=0;job_errors=0;hist_sum=0;
     end
     2:begin
      if(f[1]!=f[2] || f[3]!=f[4] || f[4]!=64'(returned))$fatal(1,"coverage counters mismatch");
      if(f[5]!=64'(job_errors))$fatal(1,"mismatch counter lost");
      expected_changes=(inject && current_job==0)?16:0;
      if(f[6]!=64'(expected_changes))$fatal(1,"repeat variation counter");
      if(dut.stage==2 && dut.read_gap==0 && max_pending<integer'(dut.rlimit)-1)$fatal(1,"high concurrency not exercised");
      results++;
     end
     3:begin
      if((f[2]^f[4])==0 && (f[3]^f[5])==0)$fatal(1,"bad error sample");samples++;
     end
     4:begin
      if(f[1]!=((current_job==0)?65:124))$fatal(1,"histogram bit mapping");
      hist_sum+=integer'(f[2]);hists++;
     end
     5:begin
      if(f[1]!=64'(inj_expected))$fatal(1,"total errors mismatch");
     end
     6:$fatal(1,"unexpected fatal %h",f[1]);
     default:$fatal(1,"bad record");
    endcase
   end
  end
 end
 task automatic reset_model;
  begin
   rst=1;calib_complete=0;repeat(5)@(negedge clk);
   wt=0;wh=0;rt=0;rh=0;configs=0;results=0;samples=0;hists=0;inj_expected=0;
   returned=0;job_errors=0;hist_sum=0;max_pending=0;rst=0;calib_complete=1;
  end
 endtask
 initial begin
  cycle=0;wt=0;wh=0;rt=0;rh=0;configs=0;results=0;hist_sum=0;job_errors=0;
  for(run=0;run<2;run++)begin
   inject=(run==1);reset_model();
   wait(done);repeat(10)@(negedge clk);
   if(results!=372 || configs!=372)$fatal(1,"missing diagnostic jobs");
   if(run==1 && (samples==0 || hists==0 || inj_expected==0))$fatal(1,"injection not exercised");
   $display("PASS all 372 jobs, runtime limits/gaps/order, run=%0d injected=%0d",run,inj_expected);
  end
  // Calibration timeout must halt without DDR traffic.
  model_enabled=0;rst=1;repeat(3)@(negedge clk);rst=0;calib_complete=0;
  wait(done);if(dut.fatal_code!=1)$fatal(1,"calibration timeout");
  $display("PASS calibration timeout");
  // Loss of calibration and UI reset during a live operation are fatal.
  for(run=0;run<2;run++)begin
   model_enabled=1;inject=0;reset_model();wait(dut.state==2);@(negedge clk);
   if(run==0)calib_complete=0;else ui_reset=1;
   @(negedge clk);if(!done || dut.fatal_code!=32'(run+2))$fatal(1,"reset/calibration fault");
   ui_reset=0;
  end
  $display("PASS calibration loss/UI reset");
  model_enabled=0;rst=1;repeat(3)@(negedge clk);rst=0;calib_complete=1;
  wait(done);if(dut.fatal_code!=4)$fatal(1,"write timeout");
  $display("PASS blocked write timeout");
  // Invalid response framing and unsolicited data are fatal, even with valid calibration.
  model_enabled=1;reset_model();bad_end=1;
  wait(done);if(dut.fatal_code!=5)$fatal(1,"missing response end");bad_end=0;
  reset_model();wait(dut.state==2);@(negedge clk);unsolicited=1;
  wait(done);if(dut.fatal_code!=5)$fatal(1,"unexpected response");unsolicited=0;
  reset_model();wait(dut.state==4);@(negedge clk);model_enabled=0;
  wait(done);if(dut.fatal_code!=4)$fatal(1,"blocked read timeout");
  $display("PASS response end/unexpected response/read timeout");
  model_enabled=1;reset_model();wait(dut.state==5);@(negedge clk);calib_complete=0;
  @(negedge clk);if(!done || dut.fatal_code!=2)$fatal(1,"calibration loss between jobs");
  $display("PASS calibration loss while reporting");
  $display("PROBE SIMULATION PASSED");$finish;
 end
 initial begin #50000000;$fatal(1,"global simulation timeout");end
endmodule
