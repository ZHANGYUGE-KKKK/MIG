`timescale 1ns/1ps
module ddr3_loopback_top (
    input wire BADJ_CLK_clk_p, input wire BADJ_CLK_clk_n,
    input wire sys_rst, output wire tx, output wire GPIO_LED7,
    output wire [15:0] C0_DDR3_0_addr,
    output wire [2:0] C0_DDR3_0_ba,
    output wire C0_DDR3_0_cas_n,
    output wire [0:0] C0_DDR3_0_cke,
    output wire [0:0] C0_DDR3_0_ck_n,
    output wire [0:0] C0_DDR3_0_ck_p,
    output wire [0:0] C0_DDR3_0_cs_n,
    output wire [1:0] C0_DDR3_0_dm,
    inout wire [15:0] C0_DDR3_0_dq,
    inout wire [1:0] C0_DDR3_0_dqs_n,
    inout wire [1:0] C0_DDR3_0_dqs_p,
    output wire [0:0] C0_DDR3_0_odt,
    output wire C0_DDR3_0_ras_n,
    output wire C0_DDR3_0_reset_n,
    output wire C0_DDR3_0_we_n
);
    wire ref_clk_ibuf, ref_clk, ui_clk, ui_rst, calib_complete;
    // Board U18 Si570 -> AW23/AW22, 250 MHz. No clock wizard required.
    IBUFDS ref_clk_ibufds (.I(BADJ_CLK_clk_p), .IB(BADJ_CLK_clk_n), .O(ref_clk_ibuf));
    BUFG ref_clk_bufg (.I(ref_clk_ibuf), .O(ref_clk));
    // Deterministic power-on reset; external active-high SW5 may assert asynchronously.
    // Deassertion is synchronized to the reference clock and stretched for 65536 cycles.
    reg [15:0] por_count = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b11;
    always @(posedge ref_clk or posedge sys_rst) begin
        if (sys_rst) reset_sync <= 2'b11;
        else reset_sync <= {reset_sync[0], 1'b0};
    end
    always @(posedge ref_clk) begin
        if (reset_sync[1]) por_count <= 0;
        else if (!(&por_count)) por_count <= por_count + 1'b1;
    end
    assign GPIO_LED7 = calib_complete;
    wire mig_rst = reset_sync[1] || !(&por_count);
    wire [28:0] app_addr;
    wire [2:0] app_cmd;
    wire app_en, app_rdy, app_wdf_wren, app_wdf_end, app_wdf_rdy;
    wire [127:0] app_wdf_data, app_rd_data;
    wire [15:0] app_wdf_mask;
    wire app_rd_data_valid, app_rd_data_end;
    ddr3_mig mig (
        .c0_sys_clk_i(ref_clk), .sys_rst(mig_rst),
        .c0_init_calib_complete(calib_complete),
        .c0_ddr3_ui_clk(ui_clk), .c0_ddr3_ui_clk_sync_rst(ui_rst),
        .dbg_clk(), .dbg_bus(),
        .c0_ddr3_addr(C0_DDR3_0_addr),
        .c0_ddr3_ba(C0_DDR3_0_ba),
        .c0_ddr3_cas_n(C0_DDR3_0_cas_n),
        .c0_ddr3_cke(C0_DDR3_0_cke),
        .c0_ddr3_ck_n(C0_DDR3_0_ck_n),
        .c0_ddr3_ck_p(C0_DDR3_0_ck_p),
        .c0_ddr3_cs_n(C0_DDR3_0_cs_n),
        .c0_ddr3_dm(C0_DDR3_0_dm),
        .c0_ddr3_dq(C0_DDR3_0_dq),
        .c0_ddr3_dqs_n(C0_DDR3_0_dqs_n),
        .c0_ddr3_dqs_p(C0_DDR3_0_dqs_p),
        .c0_ddr3_odt(C0_DDR3_0_odt),
        .c0_ddr3_ras_n(C0_DDR3_0_ras_n),
        .c0_ddr3_reset_n(C0_DDR3_0_reset_n),
        .c0_ddr3_we_n(C0_DDR3_0_we_n),
        .c0_ddr3_app_addr(app_addr),
        .c0_ddr3_app_cmd(app_cmd),
        .c0_ddr3_app_en(app_en),
        .c0_ddr3_app_rdy(app_rdy),
        .c0_ddr3_app_wdf_data(app_wdf_data),
        .c0_ddr3_app_wdf_mask(app_wdf_mask),
        .c0_ddr3_app_wdf_wren(app_wdf_wren),
        .c0_ddr3_app_wdf_end(app_wdf_end),
        .c0_ddr3_app_wdf_rdy(app_wdf_rdy),
        .c0_ddr3_app_rd_data(app_rd_data),
        .c0_ddr3_app_rd_data_valid(app_rd_data_valid),
        .c0_ddr3_app_rd_data_end(app_rd_data_end),
        .c0_ddr3_app_hi_pri(1'b0)
    );
    ddr_hello hello (
        .clk(ui_clk), .rst(ui_rst), .calib_complete(calib_complete),
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
        .tx(tx)
    );
endmodule
