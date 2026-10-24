`timescale 1ns/1ps
// UI-level memory model. This tests the application and real UART waveform;
// it does NOT simulate the DDR3 PHY, training, or external memory timing.
module ddr_hello_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, calib = 0;
    wire [28:0] addr;
    wire [2:0] cmd;
    wire en, wren, wend, tx;
    wire [127:0] wdata;
    wire [15:0] mask;
    reg rdy, wrdy;
    reg [127:0] rdata = 0;
    reg rvalid = 0, rend = 0;
    integer scenario = 0, cycles = 0, delay_count = 0, read_delay = 0;
    integer writes = 0, write_data_beats = 0, reads = 0;
    reg command_seen = 0, data_seen = 0;
    reg [127:0] memory;
    string received = "";
    ddr_hello #(.CLK_HZ(800), .BAUD(100), .TIMEOUT_CYCLES(300)) dut (
        .clk(clk), .rst(rst), .calib_complete(calib),
        .app_addr(addr), .app_cmd(cmd), .app_en(en), .app_rdy(rdy),
        .app_wdf_data(wdata), .app_wdf_mask(mask), .app_wdf_wren(wren),
        .app_wdf_end(wend), .app_wdf_rdy(wrdy),
        .app_rd_data(rdata), .app_rd_data_valid(rvalid), .app_rd_data_end(rend), .tx(tx)
    );
    always @* begin
        rdy = 1; wrdy = 1;
        case (scenario)
            0: wrdy = delay_count > 20;
            1: rdy = data_seen && delay_count > 20;
            2: begin rdy = cycles % 7 == 0; wrdy = cycles % 11 == 0; end
            5: begin rdy = 0; wrdy = 0; end
        endcase
    end
    always @(posedge clk) begin
        if (rst) begin
            cycles <= 0; delay_count <= 0; read_delay <= 0;
            command_seen <= 0; data_seen <= 0;
            rvalid <= 0; rend <= 0;
            writes <= 0; write_data_beats <= 0; reads <= 0;
        end else begin
            cycles <= cycles + 1;
            if (wren || command_seen || data_seen) delay_count <= delay_count + 1;
            rvalid <= 0; rend <= 0;
            if ((en || wren) && !calib) $fatal(1,"Access before calibration");
            if (en && rdy) begin
                if (addr !== 0) $fatal(1,"Wrong test address");
                if (cmd == 0) begin
                    if (command_seen) $fatal(1,"Duplicate write command");
                    if (!data_seen) $fatal(1,"Write command must follow accepted data (PG150 skew)");
                    command_seen <= 1; writes <= writes + 1;
                end else if (cmd == 1) begin
                    if (!command_seen || !data_seen) $fatal(1,"Read before write accepted");
                    reads <= reads + 1;
                    if (scenario != 6) read_delay <= 7;
                end else $fatal(1,"Wrong MIG command");
            end
            if (wren && wrdy) begin
                if (data_seen) $fatal(1,"Duplicate write data");
                if (!wend || mask !== 0) $fatal(1,"Incorrect burst end/mask");
                if (wdata !== 128'h000000000000444c524f574f4c4c4548) $fatal(1,"Wrong payload");
                memory <= wdata;
                data_seen <= 1; write_data_beats <= write_data_beats + 1;
            end
            if (read_delay != 0) begin
                read_delay <= read_delay - 1;
                if (read_delay == 1) begin
                    // Corruption changes the first printed character to I.
                    rdata <= memory ^ ((scenario == 3) ? 128'd1 : 128'd0);
                    rvalid <= 1; rend <= 1;
                end
            end
        end
    end
    // Decode actual serial line, including bit order and stop-bit duration.
    reg [7:0] serial_byte;
    integer bit_no;
    initial forever begin
        @(negedge tx);
        if (!rst) begin
            repeat (4) @(posedge clk);
            if (tx !== 0) $fatal(1,"Invalid UART start");
            for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
                repeat (8) @(posedge clk);
                serial_byte[bit_no] = tx;
            end
            repeat (8) @(posedge clk);
            if (tx !== 1) $fatal(1,"Invalid UART stop");
            received = {received, $sformatf("%c",serial_byte)};
        end
    end
    task run_case(input integer which, input string expected);
        integer limit;
        begin
            @(negedge clk); rst = 1; calib = 0; scenario = which;
            repeat (12) @(negedge clk);
            received = ""; rst = 0;
            // Boot message occupies ~1120 cycles. Delay calibration until after it.
            repeat (1200) @(negedge clk);
            if (which != 4) calib = 1;
            limit = 0;
            while (received.len() < expected.len() && limit < 7000) begin
                @(negedge clk); limit = limit + 1;
            end
            if (received != expected) $fatal(1,"Case %0d serial mismatch: %s",which,received);
            repeat (100) @(negedge clk);
            if (received != expected) $fatal(1,"Unexpected extra serial output");
            if (which < 4 && (writes != 1 || write_data_beats != 1 || reads != 1))
                $fatal(1,"Wrong transaction count");
            $display("PASS case %0d: %s",which,received);
        end
    endtask
    initial begin
        run_case(0, "DDR WAIT CAL\r\nDDR READ: HELLOWORLD\r\nPASS\r\n");
        run_case(1, "DDR WAIT CAL\r\nDDR READ: HELLOWORLD\r\nPASS\r\n");
        run_case(2, "DDR WAIT CAL\r\nDDR READ: HELLOWORLD\r\nPASS\r\n");
        run_case(3, "DDR WAIT CAL\r\nDDR READ: IELLOWORLD\r\nFAIL\r\n");
        run_case(4, "DDR WAIT CAL\r\nDDR TIMEOUT\r\n");
        run_case(5, "DDR WAIT CAL\r\nDDR TIMEOUT\r\n");
        run_case(6, "DDR WAIT CAL\r\nDDR TIMEOUT\r\n");
        run_case(2, "DDR WAIT CAL\r\nDDR READ: HELLOWORLD\r\nPASS\r\n");
        $display("ALL TESTS PASSED"); $finish;
    end
    initial begin #2000000; $fatal(1,"Simulation watchdog"); end
endmodule
