`timescale 1ns/1ps
module tb_databit;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ui_reset=0,calib_complete=0;
 wire [28:0] app_addr;wire [2:0] app_cmd;wire app_en,app_wdf_wren,app_wdf_end;
 reg app_rdy=0,app_wdf_rdy=0;
 wire [127:0] app_wdf_data;wire [15:0] app_wdf_mask;
 reg [127:0] app_rd_data=0;reg app_rd_data_valid=0,app_rd_data_end=1;
 wire [511:0] record_data;wire record_valid,done;reg record_ready=0;
 integer mode=0,wc=0,rc=0,wd=0,results=0,hists=0,headers=0,addresses=0,finished=0,fatals=0;
 integer expected_errors=0,index=0,pending=-1,delay_count=0,ticks=0;
 reg [127:0] memory[0:31],write_data;
 reg have_write=0;
 reg [31:0] random_state=32'h7b1ca5e9;
 reg [511:0] held_record;
 reg held=0;
 integer k,slot_idx;
 integer last_write_tick=-100000,last_return_tick=-100000;
 reg [127:0] reference_pattern,return_value;
 reg [63:0] f[0:7];
 reg [31:0] hist_ref[0:127];
 ddr_databit #(.TIMEOUT_CYCLES(300),.CAL_TIMEOUT_CYCLES(5000)) dut(.*);
 function automatic [28:0] ref_address(input integer n);
  case(n/8)
   0:ref_address=29'(n*8);
   1:ref_address=29'h1fffffc0+29'((n-8)*8);
   2:ref_address=29'h10000000+29'((n-16)*8);
   default:ref_address=29'h2000+29'((n-24)*8);
  endcase
 endfunction
 function automatic [127:0] ref_pattern(input integer p);
  reg [127:0] v;
  integer b;
  begin
   v=0;
   for(b=0;b<128;b=b+1) begin
    if(p<128) v[b]=(b==p);
    else if(p<256) v[b]=(b!=p-128);
    else if(p==256) v[b]=0;
    else if(p==257) v[b]=1;
    else if(p==258) v[b]=(b%2==1);
    else v[b]=(b%2==0);
   end
   ref_pattern=v;
  end
 endfunction
 initial begin
  if(!$value$plusargs("MODE=%d",mode)) mode=0;
  for(k=0;k<128;k=k+1) hist_ref[k]=0;
  repeat(8) @(negedge clk);
  rst=0;if(mode!=3)calib_complete=1;
 end
 always @(negedge clk) begin
  if(!rst) begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   app_rdy=random_state[0] | random_state[3];
   app_wdf_rdy=mode!=4 && (random_state[2] | random_state[7]);
   record_ready=random_state[5];
   app_rd_data_valid=0;
   if(pending>=0) begin
    if(mode==5) calib_complete=0;
    if(mode==8) ui_reset=1;
    if(delay_count==0) begin
     return_value=memory[pending];
     if(mode==9) begin return_value[9]=memory[pending][10];return_value[10]=memory[pending][9];end
     last_return_tick=ticks;
     if(mode==1 && rc%17==0) return_value[73]=~return_value[73];
     if(mode==2) return_value[(rc-1)%128]=~return_value[(rc-1)%128];
     reference_pattern=ref_pattern((rc-1)/32);
     if(return_value!=reference_pattern) expected_errors=expected_errors+1;
     for(k=0;k<128;k=k+1) if(return_value[k]!=reference_pattern[k]) hist_ref[k]=hist_ref[k]+1;
     app_rd_data=return_value;app_rd_data_valid=1;app_rd_data_end=(mode!=6);
     pending=-1;
    end else delay_count=delay_count-1;
   end
   if(mode==7 && ticks==120) app_rd_data_valid=1;
  end
 end
 always @(posedge clk) if(!rst) begin
  ticks=ticks+1;
  if(ticks>5000000) $fatal(1,"simulation watchdog");
  if(held && (!record_valid || record_data!==held_record)) $fatal(1,"unstable record under backpressure");
  held=record_valid && !record_ready;held_record=record_data;
  if(app_wdf_wren && app_wdf_rdy) begin
   if(have_write || app_wdf_mask!=0 || !app_wdf_end) $fatal(1,"bad write data protocol");
   if(app_wdf_data!==ref_pattern(wd/32)) $fatal(1,"wrong write pattern %0d",wd);
   if(ticks-last_return_tick<101) $fatal(1,"read-to-next-write gap too short");
   write_data=app_wdf_data;have_write=1;wd=wd+1;
  end
  if(app_en && app_rdy) begin
   slot_idx=-1;
   for(k=0;k<32;k=k+1) if(app_addr==ref_address(k))slot_idx=k;
   if(slot_idx<0 || app_addr[2:0]!=0) $fatal(1,"bad address");
   if(app_cmd==0) begin
    if(!have_write || slot_idx!=wc%32) $fatal(1,"bad write command");
    memory[slot_idx]=write_data;
    if(mode==9) begin memory[slot_idx][9]=write_data[10];memory[slot_idx][10]=write_data[9];end
    last_write_tick=ticks;have_write=0;wc=wc+1;
   end else if(app_cmd==1) begin
    if(pending>=0 || wc!=rc+1 || slot_idx!=rc%32) $fatal(1,"read ordering/outstanding");
    if(ticks-last_write_tick<101) $fatal(1,"write-to-read gap too short");
    pending=slot_idx;delay_count=int'(random_state[11:8]);rc=rc+1;
   end else $fatal(1,"unexpected command");
  end
  if(record_valid && record_ready) begin
   for(k=0;k<8;k=k+1) f[k]=record_data[511-k*64-:64];
   $display("D %016h %016h %016h %016h %016h %016h %016h %016h",f[0],f[1],f[2],f[3],f[4],f[5],f[6],f[7]);
   case(f[0][63:32])
    9:begin if(f[0][31:0]!=32'h4450494e) $fatal;headers=headers+1;end
    7:begin if(f[1]!=64'(addresses) || f[2]!=64'(ref_address(addresses))) $fatal;addresses=addresses+1;end
    2:begin
     if(f[0][31:0]!=32'(results) || f[1]!=32 || f[2]!=32 || f[4]!=64'(expected_errors)) $fatal(1,"bad pattern result");
     results=results+1;
    end
    4:begin if(f[1]!=64'(hists) || f[2]!=64'(hist_ref[hists])) $fatal(1,"bad histogram");hists=hists+1;end
    5:begin if(f[1]!=8320 || f[2]!=8320 || f[3]!=64'(expected_errors)) $fatal(1,"bad done");finished=finished+1;end
    6:begin
     if((mode==3 && f[1]!=1) || ((mode==5 || mode==8) && f[1]!=2) || ((mode==6 || mode==7) && f[1]!=3) || (mode==4 && f[1]!=4)) $fatal(1,"wrong fatal code");
     fatals=fatals+1;
    end
    default:begin end
   endcase
  end
  if(done) begin
   if(mode<=2 || mode==9) begin
    if(finished!=1 || fatals!=0 || headers!=1 || addresses!=32 || results!=260 || hists!=128 || wc!=8320 || rc!=8320 || wd!=8320) $fatal(1,"incomplete normal test");
    if((mode==0 || mode==9) && expected_errors!=0) $fatal;
    if((mode==1 || mode==2) && expected_errors==0) $fatal;
   end else if(fatals!=1 || finished!=0) $fatal(1,"missing fatal");
   $display("DATABIT SIM PASSED mode=%0d writes=%0d reads=%0d errors=%0d",mode,wc,rc,expected_errors);
   $finish;
  end
 end
endmodule
