`timescale 1ns/1ps
module telemetry_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,calib_complete=1,event_pulse=0,failed=0,drained=0;
    reg write_fire=1,read_fire=1;
    reg [3:0] phase=4,pattern=6,error_phase=4,error_pattern=6;
    reg [2:0] engine_state=3,error_state=3;
    reg [31:0] seed=32'h12345678,region_bytes=32'h40000000,error_seed=32'hdeadbeef;
    reg [63:0] passes=64'h100000001,write_bytes=64'h200000002,read_bytes=64'h300000003,errors=0,error_pass=64'h100000001;
    reg [7:0] max_outstanding=32,error_code=7;
    reg [28:0] error_addr=29'h1ffffff8;
    reg [127:0] error_expected=128'h0123456789abcdef_fedcba9876543210;
    reg [127:0] error_actual=128'h0123456789abcdee_fedcba9876543211;
    wire tx;
    stress_telemetry #(.CLK_HZ(800),.BAUD(100),.REPORT_SECONDS(50)) dut(.*);
    string line="";
    bit saw_stat=0,saw_error=0;
    reg [7:0] ch;
    function automatic bit contains(input string s,input string part);
        contains=0;
        for(integer j=0;j+part.len()<=s.len();j++)
            if(s.substr(j,j+part.len()-1)==part)contains=1;
    endfunction
    task automatic require_text(input string s);
        if(!contains(line,s))$fatal(1,"UART missing %s in %s",s,line);
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        // Fail while a status line is transmitting: fault must survive UART busy.
        repeat(2000)@(negedge clk);failed=1;errors=1;drained=1;
        wait(saw_error);
        repeat(100)@(negedge clk);
        if(!saw_stat)$fatal(1,"Missing status report");
        if(dut.w_kibs!=12 || dut.r_kibs!=12)$fatal(1,"One-second throughput bucket wrong");
        $display("ALL TELEMETRY TESTS PASSED");$finish;
    end
    initial forever begin
        @(negedge tx);
        repeat(12)@(posedge clk);#1;
        for(integer b=0;b<8;b++)begin ch[b]=tx;repeat(8)@(posedge clk);#1;end
        if(tx!=1)$fatal(1,"UART stop bit");
        if(ch==10)begin
            $display("UART %s",line);
            if(contains(line,"STAT "))begin
                require_text("pass=0000000100000001");require_text("W=0000000200000002");
                require_text("R=0000000300000003");require_text("size=40000000");require_text("maxrd=00000020");
                saw_stat=1;
            end else if(contains(line,"ERROR "))begin
                require_text("code=00000007");require_text("seed=DEADBEEF");require_text("pass=0000000100000001");
                require_text("addr=1FFFFFF8");require_text("byte=3FFFFFF0");
                require_text("expH=0123456789ABCDEF");require_text("expL=FEDCBA9876543210");
                require_text("gotH=0123456789ABCDEE");require_text("gotL=FEDCBA9876543211");
                require_text("xorH=0000000000000001");require_text("xorL=0000000000000001");saw_error=1;
            end else $fatal(1,"Unexpected UART line");
            line="";
        end else if(ch!=13)line={line,string'(ch)};
    end
    initial begin #2000000;$fatal(1,"UART timeout");end
endmodule
