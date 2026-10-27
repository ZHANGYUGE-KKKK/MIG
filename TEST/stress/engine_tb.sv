`timescale 1ns/1ps
module engine_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,ui_reset=0,calib_complete=0;
    wire [28:0] app_addr; wire [2:0] app_cmd;
    wire app_en,app_wdf_wren,app_wdf_end; reg app_rdy=0,app_wdf_rdy=0;
    wire [127:0] app_wdf_data; wire [15:0] app_wdf_mask;
    reg [127:0] app_rd_data=0; reg app_rd_data_valid=0,app_rd_data_end=1;
    wire [3:0] phase,pattern,error_phase,error_pattern;
    wire [2:0] state,error_state;
    wire [31:0] seed,region_bytes,error_seed;
    wire [63:0] passes,write_bytes,read_bytes,errors,error_pass;
    wire [7:0] max_outstanding,error_code;
    wire event_pulse,failed,drained; wire [28:0] error_addr;
    wire [127:0] error_expected,error_actual;
    ddr_stress_engine #(.SMALL_LOG2(7),.MID_LOG2(8),.FULL_LOG2(9),
       .BLOCK_LOG2(4),.TIMEOUT_CYCLES(300),.FAULT_DRAIN_CYCLES(100)) dut(.*);
    reg [127:0] mem[0:511],wq[0:2047],rq[0:65535];
    integer due[0:65535];
    integer wh=0,wt=0,rh=0,rt=0,cycle=0,mode=0,reads=0;
    integer counts[0:511],last_phase=-1,last_pat=-1,last_state=-1;
    integer writes_job=0,reads_job=0,blocks_seen[0:31],mix_jobs=0;
    bit patterns_seen[0:8],phases_seen[0:6],saw_reverse=0,saw_simultaneous=0;
    bit corrupt_sent=0;
    reg [127:0] injected_expected,injected_actual;
    reg [28:0] injected_addr;
    reg [127:0] mix_first[0:31];
    bit mix_seen[0:31];
    reg [31:0] cover_seed,previous_stream_seed;
    bit stream_seen=0;
    integer idx,physical,i;
    bit stalled_command=0,stalled_data=0;
    reg [28:0] held_addr;
    reg [2:0] held_cmd;
    reg [127:0] held_data;
    // Independent reference, using xorshift and explicitly defined 32-bit lanes.
    function automatic [127:0] reference(input integer a,input integer p,input [31:0] s);
        reg [31:0] h;reg [127:0] v;
        begin
            h=32'(a)^s;h=h^(h<<13);h=h^(h>>17);h=h^(h<<5);
            v={32'(a)^32'ha5c39e71,~32'(a),{16'(a),16'(a>>16)}^32'h6d2b79f5,32'(a)};
            case(p)
             0:reference=0;1:reference='1;2:reference={16{8'haa}};3:reference={16{8'h55}};
             4:reference=v;5:reference=~v;
             7:reference=128'd1<<(a%128);8:reference=~(128'd1<<(a%128));
             default:reference={((h<<7)|(h>>25))^32'h9e3779b9,((h<<19)|(h>>13))^32'hc3a5c85c,~h,h};
            endcase
        end
    endfunction
    // Drive the MIG model on the falling edge; all handshakes commit on rising.
    always @(negedge clk) begin
        app_rdy=!rst && cycle%7!=0 && mode!=4 && !(mode==5 && state==3);
        app_wdf_rdy=!rst && cycle%5!=0 && mode!=3;
        app_rd_data_valid=0;app_rd_data_end=1;
        if(!rst && rh<rt && due[rh]<=cycle && cycle%11!=0 && mode!=6) begin
            app_rd_data=rq[rh];app_rd_data_valid=1;
            if(mode==7 && !corrupt_sent)begin
                injected_expected=rq[rh];injected_actual=rq[rh]^128'h10000000000000001;
                app_rd_data=injected_actual;corrupt_sent=1;
            end
            if(mode==10)app_rd_data_end=0;
        end
        if(!rst && mode==9 && state==2)begin app_rd_data_valid=1;app_rd_data=0;end
    end
    always @(posedge clk) begin
        cycle=cycle+1;
        if(rst)begin wh=0;wt=0;rh=0;rt=0;reads=0;corrupt_sent=0;
            last_phase=-1;last_pat=-1;last_state=-1;writes_job=0;reads_job=0;stalled_command=0;stalled_data=0;
            for(i=0;i<512;i=i+1)counts[i]=0;
        end else begin
            if(!failed && calib_complete && !ui_reset)begin
                if(stalled_command && (!app_en || app_addr!=held_addr || app_cmd!=held_cmd))
                    $fatal(1,"Command changed under backpressure");
                if(stalled_data && (!app_wdf_wren || app_wdf_data!=held_data))
                    $fatal(1,"Write data changed under backpressure");
            end
            stalled_command=app_en && !app_rdy;
            stalled_data=app_wdf_wren && !app_wdf_rdy;
            held_addr=app_addr;held_cmd=app_cmd;held_data=app_wdf_data;
            if(failed && (app_en||app_wdf_wren))$fatal(1,"Traffic after fault");
            if(dut.pending>32)$fatal(1,"Outstanding read overflow");
            if(state==1)begin
                if(last_state==4 && !failed && reads_job!=writes_job && last_phase!=5)
                    $fatal(1,"Job write/read count mismatch");
                writes_job=0;reads_job=0;
                for(i=0;i<512;i=i+1)counts[i]=0;
            end
            if(app_wdf_wren && app_wdf_rdy)begin
                if(!app_wdf_end || app_wdf_mask!=0)$fatal(1,"Invalid data handshake");
                if(phase==3 && pattern==6)cover_seed=seed;
                if(phase==4 && dut.wd_count==0)begin
                    if((!stream_seen && seed==cover_seed) || (stream_seen && seed==previous_stream_seed))
                        $fatal(1,"Stream did not change seed");
                    previous_stream_seed=seed;stream_seen=1;
                end
                if(phase==6 && dut.wd_count==0 && passes==0)begin
                    for(integer j=0;j<32;j++)
                        if(mix_seen[j] && mix_first[j]==app_wdf_data)
                            $fatal(1,"Different blocks contain identical pseudorandom data");
                    mix_first[integer'(dut.wd_addr)>>4]=app_wdf_data;
                    mix_seen[integer'(dut.wd_addr)>>4]=1;
                end
                wq[wt%2048]=app_wdf_data;wt=wt+1;
                if(app_wdf_data!==reference(integer'(dut.wd_addr),integer'(pattern),seed))
                    $fatal(1,"Independent pattern reference mismatch");
            end
            if(app_en && app_rdy)begin
                idx=integer'(app_addr[28:3]);physical=(mode==11)?idx&255:idx;
                if(app_addr[2:0]!=0 || idx>511)$fatal(1,"Address alignment/range");
                if(app_cmd==0)begin
                    if(wh==wt)$fatal(1,"Write command without data");
                    mem[physical]=wq[wh%2048];wh=wh+1;writes_job=writes_job+1;
                    patterns_seen[pattern]=1;phases_seen[integer'(phase)]=1;
                    if(phase==4 && passes[0] && writes_job==1)begin
                        if(idx!=511)$fatal(1,"Reverse start");saw_reverse=1;
                    end
                end else if(app_cmd==1)begin
                    if(phase!=5 && writes_job!=integer'(dut.limit))$fatal(1,"Read before all writes");
                    if(counts[idx]!=0)$fatal(1,"Repeated address in read job");counts[idx]=1;
                    rq[rt]=mem[physical];due[rt]=cycle+80;rt=rt+1;reads=reads+1;reads_job=reads_job+1;
                    phases_seen[integer'(phase)]=1;
                    if(mode==7 && reads==1)injected_addr=app_addr;
                    if(phase==6 && reads_job==1)begin
                        blocks_seen[idx>>4]=blocks_seen[idx>>4]+1;mix_jobs=mix_jobs+1;
                    end
                end else $fatal(1,"Unknown command");
            end
            if(app_rd_data_valid && rh<rt)rh=rh+1;
            if(dut.read_fire && dut.response_fire)saw_simultaneous=1;
            last_state=integer'(state);last_phase=integer'(phase);last_pat=integer'(pattern);
        end
    end
    task automatic reset_test(input integer m,input bit cal);
        begin
            @(negedge clk);rst=1;mode=m;calib_complete=cal;ui_reset=0;
            repeat(5)@(negedge clk);rst=0;
        end
    endtask
    task automatic expect_fault(input integer code);
        reg [28:0] a;reg [127:0] e,g;
        begin
            wait(failed);#1;
            if(integer'(error_code)!=code)$fatal(1,"Expected fault %0d got %0d",code,error_code);
            a=error_addr;e=error_expected;g=error_actual;
            repeat(200)@(negedge clk);
            if(!drained || errors!=1 || error_addr!=a || error_expected!=e || error_actual!=g)
                $fatal(1,"First fault / bounded drain not preserved");
            $display("PASS fault code %0d",code);
        end
    endtask
    initial begin
        for(i=0;i<32;i=i+1)blocks_seen[i]=0;
        reset_test(0,1);
        wait(passes==2);@(negedge clk);
        if(failed || max_outstanding!=32 || !saw_reverse || !saw_simultaneous)$fatal(1,"Stress coverage incomplete");
        for(integer j=0;j<9;j++)if(!patterns_seen[j])$fatal(1,"Missing pattern %0d",j);
        for(integer j=1;j<7;j++)if(!phases_seen[j])$fatal(1,"Missing phase %0d",j);
        for(integer j=0;j<32;j++)if(blocks_seen[j]!=2)$fatal(1,"Missing/repeated mix block %0d",j);
        if(write_bytes==0||read_bytes==0)$fatal(1,"Missing counters");
        $display("PASS two complete stress cycles, all patterns, 32 outstanding, reverse/permutation/mix");
        reset_test(7,1);expect_fault(7);
        if(error_addr!=injected_addr || error_expected!=injected_expected || error_actual!=injected_actual)
            $fatal(1,"Corruption metadata wrong");
        reset_test(11,1);expect_fault(7);
        if(error_phase!=3 || error_pattern!=4)$fatal(1,"Address alias not detected by address pattern");
        reset_test(1,0);expect_fault(1);
        reset_test(3,1);expect_fault(3);
        reset_test(4,1);expect_fault(4);
        reset_test(5,1);expect_fault(5);
        reset_test(6,1);expect_fault(6);
        reset_test(0,1);wait(state==3);@(negedge clk);calib_complete=0;expect_fault(2);
        reset_test(0,1);wait(state==3);@(negedge clk);ui_reset=1;expect_fault(8);
        reset_test(9,1);expect_fault(9);
        reset_test(10,1);expect_fault(10);
        $display("ALL ENGINE TESTS PASSED");$finish;
    end
    initial begin #20000000;$fatal(1,"Simulation timed out");end
endmodule
