`timescale 1ns/1ps
module address_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,ui_reset=0,calib_complete=0;
    wire [28:0] app_addr; wire [2:0] app_cmd;
    wire app_en,app_wdf_wren,app_wdf_end; reg app_rdy=1,app_wdf_rdy=1;
    wire [127:0] app_wdf_data; wire [15:0] app_wdf_mask;
    reg [127:0] app_rd_data=0; reg app_rd_data_valid=0,app_rd_data_end=1;
    wire [3:0] phase,pattern,error_phase,error_pattern;
    wire [2:0] state,error_state;
    wire [31:0] seed,region_bytes,error_seed;
    wire [63:0] passes,write_bytes,read_bytes,errors,error_pass;
    wire [7:0] max_outstanding,error_code;
    wire event_pulse,failed,drained; wire [28:0] error_addr;
    wire [127:0] error_expected,error_actual;
    // Production 26-bit burst address width. Backdoor only selects a job;
    // counters, masks, cursors and handshakes execute unchanged RTL.
    ddr_stress_engine dut(.*);
    integer n;
    reg [25:0] expected_index;
    task automatic select_job(input integer which);
        begin
            @(negedge clk);rst=1;calib_complete=1;
            repeat(5)@(negedge clk);rst=0;
            wait(state==1);@(negedge clk);
            if(which==2)force dut.phase=4'd5;
            else force dut.phase=4'd4;
            if(which==1)force dut.passes=64'd1;
            else force dut.passes=64'd0;
            @(negedge clk);release dut.phase;release dut.passes;
            if(region_bytes!=32'h40000000)$fatal(1,"Production capacity is not 1 GiB");
        end
    endtask
    initial begin
        select_job(0);
        n=0;
        while(n<64)begin
            @(posedge clk);
            if(app_en && app_rdy)begin
                if(app_addr!=29'(n*8))$fatal(1,"Forward production address");n++;
            end
        end
        select_job(1);
        n=0;
        while(n<64)begin
            @(posedge clk);
            if(app_en && app_rdy)begin
                if(app_addr!=29'h1ffffff8-29'(n*8))$fatal(1,"Reverse production high address");n++;
            end
        end
        select_job(2);
        expected_index=26'h37a5c29;n=0;
        while(n<32)begin
            @(posedge clk);
            if(app_en && app_rdy)begin
                if(app_cmd!=1 || app_addr!={expected_index,3'b000})$fatal(1,"Production permutation wrap");
                expected_index=expected_index+26'h1f12345;n++;
            end
        end
        $display("ALL PRODUCTION ADDRESS BOUNDARY TESTS PASSED");$finish;
    end
    initial begin #100000;$fatal(1,"Address test timeout");end
endmodule
