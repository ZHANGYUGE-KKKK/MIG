`timescale 1ns/1ps
// Finite low-transaction-rate DQ/beat test. No claim of physical pin identity.
module ddr_databit #(
 parameter integer CLK_HZ=100000000,
 parameter integer GAP_CYCLES=CLK_HZ/1000000,
 parameter integer TIMEOUT_CYCLES=CLK_HZ,
 parameter integer CAL_TIMEOUT_CYCLES=CLK_HZ*10
)(
 input wire clk,rst,ui_reset,calib_complete,
 output wire [28:0] app_addr,output wire [2:0] app_cmd,output wire app_en,input wire app_rdy,
 output wire [127:0] app_wdf_data,output wire [15:0] app_wdf_mask,
 output wire app_wdf_wren,app_wdf_end,input wire app_wdf_rdy,
 input wire [127:0] app_rd_data,input wire app_rd_data_valid,app_rd_data_end,
 output reg [511:0] record_data,output wire record_valid,input wire record_ready,
 output wire done
);
 localparam [4:0] HEADER=0,ADDRLOG=1,WAITCAL=2,PREP=3,WD=4,WC=5,WGAP=6,
 RC=7,RWAIT=8,CHECK=9,SAMPLE=10,RGAP=11,ADVANCE=12,RESULT=13,HIST=14,FINISH=15,HALT=16,FATAL=17;
 reg [4:0] state;
 reg [8:0] pattern;
 reg [4:0] slot;
 reg [7:0] hist_index;
 reg [28:0] address;
 reg [127:0] expected,actual;
 reg [31:0] gap_count,watchdog,cal_wait;
 reg [63:0] phase_cycles,total_writes,total_reads,total_errors;
 reg [31:0] writes,reads,errors,samples;
 reg [127:0][31:0] bit_errors;
 reg [7:0] fatal_code;
 reg [4:0] fault_state;
 reg active;
 integer i;
 function automatic [28:0] address_for(input [4:0] n);
  case(n[4:3])
   0:address_for={23'b0,n[2:0],3'b0};
   1:address_for=29'h1fffffc0 | {23'b0,n[2:0],3'b0};
   2:address_for=29'h10000000 | {23'b0,n[2:0],3'b0};
   default:address_for=29'h00002000 | {23'b0,n[2:0],3'b0};
  endcase
 endfunction
 function automatic [127:0] pattern_for(input [8:0] p);
  if(p<128) pattern_for=128'b1<<p[6:0];
  else if(p<256) pattern_for=~(128'b1<<p[6:0]);
  else case(p)
   256:pattern_for=128'b0;
   257:pattern_for={128{1'b1}};
   258:pattern_for={16{8'haa}};
   default:pattern_for={16{8'h55}};
  endcase
 endfunction
 assign app_addr=address;
 assign app_cmd=(state==RC)?3'b001:3'b000;
 assign app_en=(state==WC || state==RC) && calib_complete && !ui_reset;
 assign app_wdf_data=expected;
 assign app_wdf_mask=0;
 assign app_wdf_wren=state==WD && calib_complete && !ui_reset;
 assign app_wdf_end=app_wdf_wren;
 assign record_valid=state==HEADER || state==ADDRLOG || state==SAMPLE || state==RESULT || state==HIST || state==FINISH || state==FATAL;
 assign done=state==HALT;
 wire read_accept=state==RC && app_en && app_rdy;
 wire response=app_rd_data_valid && (state==RWAIT || read_accept);
 wire stalled=(state==WD && !app_wdf_rdy) || (state==WC && !app_rdy) ||
              (state==RC && !app_rdy) || (state==RWAIT && !app_rd_data_valid);
 always @* begin
  record_data=0;
  case(state)
   HEADER:record_data={64'h000000094450494e,64'd1,64'(CLK_HZ),64'(GAP_CYCLES),64'd32,64'd260,64'd128,64'd800};
   ADDRLOG:record_data={64'h0000000700000000,59'b0,slot,35'b0,address_for(slot),64'd0,64'd0,64'd0,64'd0,64'd0};
   RESULT:record_data={32'd2,23'b0,pattern,32'b0,writes,32'b0,reads,32'b0,errors,total_errors,phase_cycles,64'(GAP_CYCLES),64'd0};
   SAMPLE:record_data={32'd3,23'b0,pattern,35'b0,address,expected[127:64],expected[63:0],actual[127:64],actual[63:0],59'b0,slot,32'b0,samples};
   HIST:record_data={64'h0000000400000000,56'b0,hist_index,32'b0,bit_errors[hist_index[6:0]],64'd0,64'd0,64'd0,64'd0,64'd0};
   FINISH:record_data={64'h0000000500000000,total_writes,total_reads,total_errors,64'd260,64'd32,64'(GAP_CYCLES),64'd0};
   FATAL:record_data={64'h0000000600000000,56'b0,fatal_code,59'b0,fault_state,total_writes,total_reads,total_errors,26'b0,pattern,address,64'd0};
   default:record_data=0;
  endcase
 end
 always @(posedge clk) begin
  if(rst) begin
   state<=HEADER;pattern<=0;slot<=0;hist_index<=0;address<=0;expected<=0;actual<=0;
   gap_count<=0;watchdog<=0;cal_wait<=0;phase_cycles<=0;total_writes<=0;total_reads<=0;total_errors<=0;
   writes<=0;reads<=0;errors<=0;samples<=0;fatal_code<=0;fault_state<=0;active<=0;
   for(i=0;i<128;i=i+1) bit_errors[i]<=0;
  end else begin
   if(active && state!=HALT && state!=RESULT && state!=HIST && state!=FINISH && state!=FATAL) phase_cycles<=phase_cycles+1'b1;
   if(stalled) watchdog<=watchdog+1'b1;else watchdog<=0;
   case(state)
    HEADER:if(record_ready) state<=ADDRLOG;
    ADDRLOG:if(record_ready) begin
     if(slot==31) begin slot<=0;state<=WAITCAL;end else slot<=slot+1'b1;
    end
    WAITCAL:begin
     if(calib_complete && !ui_reset) begin active<=1;state<=PREP;end
     else if(cal_wait==CAL_TIMEOUT_CYCLES-1) begin fatal_code<=1;fault_state<=state;state<=FATAL;end
     else cal_wait<=cal_wait+1'b1;
    end
    PREP:begin address<=address_for(slot);expected<=pattern_for(pattern);state<=WD;end
    WD:if(app_wdf_wren && app_wdf_rdy) state<=WC;
    WC:if(app_en && app_rdy) begin
     writes<=writes+1'b1;total_writes<=total_writes+1'b1;gap_count<=0;state<=WGAP;
    end
    WGAP:if(gap_count==GAP_CYCLES-1) state<=RC;else gap_count<=gap_count+1'b1;
    RC:if(read_accept) state<=RWAIT;
    RWAIT:begin end
    CHECK:begin
     reads<=reads+1'b1;total_reads<=total_reads+1'b1;gap_count<=0;
     if(actual!=expected) begin
      errors<=errors+1'b1;total_errors<=total_errors+1'b1;
      for(i=0;i<128;i=i+1) if(actual[i]!=expected[i]) bit_errors[i]<=bit_errors[i]+1'b1;
      if(samples<8) state<=SAMPLE;else state<=RGAP;
     end else state<=RGAP;
    end
    SAMPLE:if(record_ready) begin samples<=samples+1'b1;state<=RGAP;end
    RGAP:if(gap_count==GAP_CYCLES-1) state<=ADVANCE;else gap_count<=gap_count+1'b1;
    ADVANCE:if(slot==31) state<=RESULT;else begin slot<=slot+1'b1;state<=PREP;end
    RESULT:if(record_ready) begin
     if(pattern==259) begin hist_index<=0;state<=HIST;end
     else begin pattern<=pattern+1'b1;slot<=0;writes<=0;reads<=0;errors<=0;samples<=0;phase_cycles<=0;state<=PREP;end
    end
    HIST:if(record_ready) begin
     if(hist_index==127) state<=FINISH;else hist_index<=hist_index+1'b1;
    end
    FINISH:if(record_ready) state<=HALT;
    FATAL:if(record_ready) state<=HALT;
    default:begin end
   endcase
   if(response) begin actual<=app_rd_data;state<=CHECK;end
   // Fatal conditions have priority over all normal transitions.
   if(state!=FATAL && state!=HALT) begin
    if(active && (ui_reset || !calib_complete)) begin
     fatal_code<=2;fault_state<=state;state<=FATAL;
    end else if(app_rd_data_valid && (!response || !app_rd_data_end)) begin
     fatal_code<=3;fault_state<=state;state<=FATAL;
    end else if(stalled && watchdog==TIMEOUT_CYCLES-1) begin
     fatal_code<=4;fault_state<=state;state<=FATAL;
    end
   end
  end
 end
endmodule
