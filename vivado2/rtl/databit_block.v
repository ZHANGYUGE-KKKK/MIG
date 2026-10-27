`timescale 1ns/1ps
// Verilog module-reference boundary; tested SystemVerilog engine is unchanged.
module databit_block #(parameter integer CLK_HZ=100000000)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="FREQ_HZ 100000000, ASSOCIATED_RESET rst" *) input wire clk,
 input wire rst,ui_reset,calib_complete,
 output wire [28:0] app_addr,output wire [2:0] app_cmd,output wire app_en,input wire app_rdy,
 output wire [127:0] app_wdf_data,output wire [15:0] app_wdf_mask,
 output wire app_wdf_wren,app_wdf_end,input wire app_wdf_rdy,
 input wire [127:0] app_rd_data,input wire app_rd_data_valid,app_rd_data_end,
 output wire [511:0] record_data,output wire record_valid,input wire record_ready,
 output wire done
);
 ddr_databit #(.CLK_HZ(CLK_HZ)) engine(
  .clk(clk),
  .rst(rst),
  .ui_reset(ui_reset),
  .calib_complete(calib_complete),
  .app_addr(app_addr),
  .app_cmd(app_cmd),
  .app_en(app_en),
  .app_rdy(app_rdy),
  .app_wdf_data(app_wdf_data),
  .app_wdf_mask(app_wdf_mask),
  .app_wdf_wren(app_wdf_wren),
  .app_wdf_end(app_wdf_end),
  .app_wdf_rdy(app_wdf_rdy),
  .app_rd_data(app_rd_data),
  .app_rd_data_valid(app_rd_data_valid),
  .app_rd_data_end(app_rd_data_end),
  .record_data(record_data),
  .record_valid(record_valid),
  .record_ready(record_ready),
  .done(done)
 );
endmodule
