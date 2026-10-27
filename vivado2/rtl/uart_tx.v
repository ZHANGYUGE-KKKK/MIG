`timescale 1ns/1ps
// Ready/valid byte input; 8 data bits, no parity, one stop bit, LSB first.
module uart_tx #(
    parameter integer CLK_HZ = 200000000,
    parameter integer BAUD = 115200
)(
    input wire clk, input wire rst,
    input wire [7:0] data, input wire valid,
    output wire ready, output wire tx
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;
    reg [31:0] ticks;
    reg [3:0] bits_left;
    reg [9:0] frame;
    assign ready = (bits_left == 0);
    assign tx = frame[0];
    always @(posedge clk) begin
        if (rst) begin
            ticks <= 0;
            bits_left <= 0;
            frame <= 10'h3ff;
        end else if (ready) begin
            if (valid) begin
                frame <= {1'b1, data, 1'b0};
                bits_left <= 10;
                ticks <= DIV - 1;
            end
        end else if (ticks == 0) begin
            frame <= {1'b1, frame[9:1]};
            bits_left <= bits_left - 1'b1;
            ticks <= DIV - 1;
        end else ticks <= ticks - 1'b1;
    end
endmodule
