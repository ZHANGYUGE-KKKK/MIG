`timescale 1ns/1ps
// One x16 BL8 burst = 16 bytes = one 128-bit UI beat (4:1 PHY ratio).
// Native app_addr is a DRAM word address, not a CPU/AXI byte address.
module ddr_hello #(
    parameter integer CLK_HZ = 200000000,
    parameter integer BAUD = 115200,
    parameter integer TIMEOUT_CYCLES = 2000000000
)(
    input wire clk, input wire rst, input wire calib_complete,
    output wire [28:0] app_addr, output wire [2:0] app_cmd,
    output wire app_en, input wire app_rdy,
    output wire [127:0] app_wdf_data, output wire [15:0] app_wdf_mask,
    output wire app_wdf_wren, output wire app_wdf_end, input wire app_wdf_rdy,
    input wire [127:0] app_rd_data,
    input wire app_rd_data_valid, input wire app_rd_data_end,
    output wire tx
);
    // Low byte is 'H'; the six high padding bytes are written and checked too.
    localparam [127:0] PAYLOAD = 128'h000000000000444c524f574f4c4c4548;
    localparam [2:0] SEND = 0, WAIT_CAL = 1, WRITE = 2,
                     READ_CMD = 3, READ_DATA = 4, DONE = 5;
    localparam [1:0] BOOT = 0, RESULT = 1, TIMEOUT = 2;
    reg [2:0] state;
    reg [1:0] message_kind;
    reg [5:0] char_index;
    reg cmd_sent, data_sent;
    reg [31:0] watchdog;
    reg [127:0] readback;
    reg passed;
    wire uart_ready;
    reg [7:0] uart_data;
    reg [5:0] message_length;
    localparam [8*14-1:0] BOOT_TEXT = "DDR WAIT CAL\r\n";
    localparam [8*13-1:0] TIMEOUT_TEXT = "DDR TIMEOUT\r\n";
    localparam [8*10-1:0] PREFIX = "DDR READ: ";
    localparam [8*8-1:0] PASS_TEXT = "\r\nPASS\r\n";
    localparam [8*8-1:0] FAIL_TEXT = "\r\nFAIL\r\n";

    assign app_addr = 29'd0;
    assign app_cmd = (state == WRITE) ? 3'b000 : 3'b001;
    assign app_en = ((state == WRITE) && data_sent && !cmd_sent) || (state == READ_CMD);
    assign app_wdf_data = PAYLOAD;
    assign app_wdf_mask = 16'h0000;
    assign app_wdf_wren = (state == WRITE) && !data_sent;
    assign app_wdf_end = app_wdf_wren;
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) uart (
        .clk(clk), .rst(rst), .data(uart_data), .valid(state == SEND),
        .ready(uart_ready), .tx(tx)
    );
    always @* begin
        uart_data = 8'h00;
        message_length = 28;
        case (message_kind)
            BOOT: begin
                message_length = 14;
                uart_data = BOOT_TEXT[(13-char_index)*8 +: 8];
            end
            TIMEOUT: begin
                message_length = 13;
                uart_data = TIMEOUT_TEXT[(12-char_index)*8 +: 8];
            end
            default: begin
                if (char_index < 10)
                    uart_data = PREFIX[(9-char_index)*8 +: 8];
                else if (char_index < 20)
                    uart_data = readback[(char_index-10)*8 +: 8];
                else if (passed)
                    uart_data = PASS_TEXT[(27-char_index)*8 +: 8];
                else
                    uart_data = FAIL_TEXT[(27-char_index)*8 +: 8];
            end
        endcase
    end
    always @(posedge clk) begin
        if (rst) begin
            state <= SEND;
            message_kind <= BOOT;
            char_index <= 0;
            cmd_sent <= 0;
            data_sent <= 0;
            watchdog <= 0;
            readback <= 0;
            passed <= 0;
        end else begin
            if (state == WAIT_CAL || state == WRITE || state == READ_CMD || state == READ_DATA)
                watchdog <= watchdog + 1'b1;
            else watchdog <= 0;
            case (state)
                SEND: if (uart_ready) begin
                    if (char_index == message_length-1) begin
                        char_index <= 0;
                        state <= (message_kind == BOOT) ? WAIT_CAL : DONE;
                    end else char_index <= char_index + 1'b1;
                end
                WAIT_CAL: if (calib_complete) begin
                    state <= WRITE;
                    watchdog <= 0;
                end
                WRITE: begin
                    // Command and write-data FIFOs have independent handshakes.
                    // Send the data first so command/data skew cannot violate PG150.
                    // Each valid stays asserted only until its own acceptance.
                    if (app_en && app_rdy) cmd_sent <= 1;
                    if (app_wdf_rdy) data_sent <= 1;
                    if ((cmd_sent || (app_en && app_rdy)) && (data_sent || app_wdf_rdy)) begin
                        state <= READ_CMD;
                        watchdog <= 0;
                    end
                end
                READ_CMD: if (app_rdy) begin
                    state <= READ_DATA;
                    watchdog <= 0;
                end
                READ_DATA: if (app_rd_data_valid) begin
                    readback <= app_rd_data;
                    passed <= (app_rd_data == PAYLOAD) && app_rd_data_end;
                    message_kind <= RESULT;
                    char_index <= 0;
                    state <= SEND;
                end
                default: state <= DONE;
            endcase
            if ((state == WAIT_CAL || state == WRITE || state == READ_CMD || state == READ_DATA)
                && watchdog == TIMEOUT_CYCLES-1) begin
                message_kind <= TIMEOUT;
                char_index <= 0;
                state <= SEND;
            end
        end
    end
endmodule
