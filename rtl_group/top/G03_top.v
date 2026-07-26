`include "../core00_wzc/marcos_wzc.v"

module g03_soc (
    input wire clk,
    input wire rst_n_i,
    input wire debug_en_i,
    input wire [1:0] chip_sel_i,
    output wire succ,
    output wire [`BRIDGE_WIDTH-1:0] bridge_tx_data_o,
    input wire [`BRIDGE_WIDTH-1:0] bridge_rx_data_i,
    output wire uart_tx_o,
    input wire uart_rx_i,
    output wire [3:0] pwm_o,
    output wire [1:0] i2c_io_ctrl_o,
    input wire i2c_scl_i,
    input wire i2c_sda_i
);

    wire rst_n;
    wire clk_wzc, clk_xyh, clk_hjx, clk_xzr;
    wire [`DATA_WIDTH-1:0] core_gpr_wdata [0:3];
    wire [`DATA_WIDTH-1:0] core_gpr_rdata1 [0:3];
    wire [`DATA_WIDTH-1:0] core_gpr_rdata2 [0:3];
    wire [`GPR_ADDR_WIDTH-1:0] core_gpr_waddr [0:3];
    wire [`GPR_ADDR_WIDTH-1:0] core_gpr_raddr1 [0:3];
    wire [`GPR_ADDR_WIDTH-1:0] core_gpr_raddr2 [0:3];
    wire [3:0] core_gpr_we;

    wire [`DATA_WIDTH-1:0] core_if_addr [0:3];
    wire [`DATA_WIDTH-1:0] core_if_wdata [0:3];
    wire [`DATA_WIDTH-1:0] core_if_rdata [0:3];
    wire [3:0] core_if_sel [0:3];
    wire [3:0] core_if_req_vld, core_if_req_rdy;
    wire [3:0] core_if_rsp_vld, core_if_rsp_rdy, core_if_we;

    wire [`DATA_WIDTH-1:0] core_mem_addr [0:3];
    wire [`DATA_WIDTH-1:0] core_mem_wdata [0:3];
    wire [`DATA_WIDTH-1:0] core_mem_rdata [0:3];
    wire [3:0] core_mem_sel [0:3];
    wire [3:0] core_mem_req_vld, core_mem_req_rdy;
    wire [3:0] core_mem_rsp_vld, core_mem_rsp_rdy, core_mem_we;

    wire bus_if_req_rdy, bus_if_rsp_vld;
    wire [`DATA_WIDTH-1:0] bus_if_rdata;
    wire bus_mem_req_rdy, bus_mem_rsp_vld;
    wire [`DATA_WIDTH-1:0] bus_mem_rdata;
    wire [`BRIDGE_WIDTH-1:0] bridge_wzc_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_xyh_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_hjx_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_xzr_tx;

    global_rst_ctrl u_rst_ctrl (
        .clk(clk), .rst_ext_i(rst_n_i), .rst_n_o(rst_n)
    );

    global_clk_sel u_global_clk_sel (
        .clk(clk), .chip_sel_i(chip_sel_i),
        .clk_wzc(clk_wzc), .clk_xyh(clk_xyh),
        .clk_hjx(clk_hjx), .clk_xzr(clk_xzr)
    );

    core_wzc u_core_wzc (
        .clk(clk_wzc), .rst_n(rst_n), .debug_halt_i(debug_en_i),
        .gpr_we_o(core_gpr_we[0]), .gpr_waddr_o(core_gpr_waddr[0]), .gpr_wdata_o(core_gpr_wdata[0]),
        .gpr_raddr1_o(core_gpr_raddr1[0]), .gpr_rdata1_i(core_gpr_rdata1[0]),
        .gpr_raddr2_o(core_gpr_raddr2[0]), .gpr_rdata2_i(core_gpr_rdata2[0]),
        .if_addr_o(core_if_addr[0]), .if_data_o(core_if_wdata[0]), .if_sel_o(core_if_sel[0]),
        .if_req_vld_o(core_if_req_vld[0]), .if_req_rdy_i(core_if_req_rdy[0]),
        .if_rsp_rdy_o(core_if_rsp_rdy[0]), .if_rsp_vld_i(core_if_rsp_vld[0]),
        .if_data_i(core_if_rdata[0]), .if_we_o(core_if_we[0]),
        .mem_addr_o(core_mem_addr[0]), .mem_data_o(core_mem_wdata[0]), .mem_sel_o(core_mem_sel[0]),
        .mem_req_vld_o(core_mem_req_vld[0]), .mem_req_rdy_i(core_mem_req_rdy[0]),
        .mem_rsp_rdy_o(core_mem_rsp_rdy[0]), .mem_rsp_vld_i(core_mem_rsp_vld[0]),
        .mem_data_i(core_mem_rdata[0]), .mem_we_o(core_mem_we[0])
    );

    core_xyh u_core_xyh (
        .clk(clk_xyh), .rst_n(rst_n), .pc_rst_i(debug_en_i), .jtag_halt_i(debug_en_i),
        .gpr_we_o(core_gpr_we[1]), .gpr_waddr_o(core_gpr_waddr[1]), .gpr_wdata_o(core_gpr_wdata[1]),
        .gpr_raddr1_o(core_gpr_raddr1[1]), .gpr_rdata1_i(core_gpr_rdata1[1]),
        .gpr_raddr2_o(core_gpr_raddr2[1]), .gpr_rdata2_i(core_gpr_rdata2[1]),
        .ibus_addr_o(core_if_addr[1]), .ibus_data_o(core_if_wdata[1]), .ibus_sel_o(core_if_sel[1]),
        .ibus_req_valid_o(core_if_req_vld[1]), .ibus_req_ready_i(core_if_req_rdy[1]),
        .ibus_rsp_ready_o(core_if_rsp_rdy[1]), .ibus_rsp_valid_i(core_if_rsp_vld[1]),
        .ibus_data_i(core_if_rdata[1]), .ibus_we_o(core_if_we[1]),
        .dbus_addr_o(core_mem_addr[1]), .dbus_data_o(core_mem_wdata[1]), .dbus_sel_o(core_mem_sel[1]),
        .dbus_req_valid_o(core_mem_req_vld[1]), .dbus_req_ready_i(core_mem_req_rdy[1]),
        .dbus_rsp_ready_o(core_mem_rsp_rdy[1]), .dbus_rsp_valid_i(core_mem_rsp_vld[1]),
        .dbus_data_i(core_mem_rdata[1]), .dbus_we_o(core_mem_we[1])
    );

    core_hjx u_core_hjx (
        .clk(clk_hjx), .rst_n(rst_n), .debug_halt_i(debug_en_i),
        .gpr_we_o(core_gpr_we[2]), .gpr_waddr_o(core_gpr_waddr[2]), .gpr_wdata_o(core_gpr_wdata[2]),
        .gpr_raddr1_o(core_gpr_raddr1[2]), .gpr_rdata1_i(core_gpr_rdata1[2]),
        .gpr_raddr2_o(core_gpr_raddr2[2]), .gpr_rdata2_i(core_gpr_rdata2[2]),
        .ibus_addr_o(core_if_addr[2]), .ibus_data_o(core_if_wdata[2]), .ibus_sel_o(core_if_sel[2]),
        .ibus_req_valid_o(core_if_req_vld[2]), .ibus_req_ready_i(core_if_req_rdy[2]),
        .ibus_rsp_ready_o(core_if_rsp_rdy[2]), .ibus_rsp_valid_i(core_if_rsp_vld[2]),
        .ibus_data_i(core_if_rdata[2]), .ibus_we_o(core_if_we[2]),
        .dbus_addr_o(core_mem_addr[2]), .dbus_data_o(core_mem_wdata[2]), .dbus_sel_o(core_mem_sel[2]),
        .dbus_req_valid_o(core_mem_req_vld[2]), .dbus_req_ready_i(core_mem_req_rdy[2]),
        .dbus_rsp_ready_o(core_mem_rsp_rdy[2]), .dbus_rsp_valid_i(core_mem_rsp_vld[2]),
        .dbus_data_i(core_mem_rdata[2]), .dbus_we_o(core_mem_we[2])
    );

    core_xzr u_core_xzr (
        .clk(clk_xzr), .rst_n(rst_n), .debug_halt_i(debug_en_i),
        .gpr_we_o(core_gpr_we[3]), .gpr_waddr_o(core_gpr_waddr[3]), .gpr_wdata_o(core_gpr_wdata[3]),
        .gpr_raddr1_o(core_gpr_raddr1[3]), .gpr_rdata1_i(core_gpr_rdata1[3]),
        .gpr_raddr2_o(core_gpr_raddr2[3]), .gpr_rdata2_i(core_gpr_rdata2[3]),
        .if_addr_o(core_if_addr[3]), .if_data_o(core_if_wdata[3]), .if_sel_o(core_if_sel[3]),
        .if_req_vld_o(core_if_req_vld[3]), .if_req_rdy_i(core_if_req_rdy[3]),
        .if_rsp_rdy_o(core_if_rsp_rdy[3]), .if_rsp_vld_i(core_if_rsp_vld[3]),
        .if_data_i(core_if_rdata[3]), .if_we_o(core_if_we[3]),
        .mem_addr_o(core_mem_addr[3]), .mem_data_o(core_mem_wdata[3]), .mem_sel_o(core_mem_sel[3]),
        .mem_req_vld_o(core_mem_req_vld[3]), .mem_req_rdy_i(core_mem_req_rdy[3]),
        .mem_rsp_rdy_o(core_mem_rsp_rdy[3]), .mem_rsp_vld_i(core_mem_rsp_vld[3]),
        .mem_data_i(core_mem_rdata[3]), .mem_we_o(core_mem_we[3])
    );

    gpr_top u_gpr_top (
        .clk(clk), .rst_n(rst_n), .chip_sel_i(chip_sel_i),
        .wzc_we_i(core_gpr_we[0]), .wzc_waddr_i(core_gpr_waddr[0]), .wzc_wdata_i(core_gpr_wdata[0]),
        .wzc_raddr1_i(core_gpr_raddr1[0]), .wzc_raddr2_i(core_gpr_raddr2[0]),
        .wzc_rdata1_o(core_gpr_rdata1[0]), .wzc_rdata2_o(core_gpr_rdata2[0]),
        .xyh_we_i(core_gpr_we[1]), .xyh_waddr_i(core_gpr_waddr[1]), .xyh_wdata_i(core_gpr_wdata[1]),
        .xyh_raddr1_i(core_gpr_raddr1[1]), .xyh_raddr2_i(core_gpr_raddr2[1]),
        .xyh_rdata1_o(core_gpr_rdata1[1]), .xyh_rdata2_o(core_gpr_rdata2[1]),
        .hjx_we_i(core_gpr_we[2]), .hjx_waddr_i(core_gpr_waddr[2]), .hjx_wdata_i(core_gpr_wdata[2]),
        .hjx_raddr1_i(core_gpr_raddr1[2]), .hjx_raddr2_i(core_gpr_raddr2[2]),
        .hjx_rdata1_o(core_gpr_rdata1[2]), .hjx_rdata2_o(core_gpr_rdata2[2]),
        .xzr_we_i(core_gpr_we[3]), .xzr_waddr_i(core_gpr_waddr[3]), .xzr_wdata_i(core_gpr_wdata[3]),
        .xzr_raddr1_i(core_gpr_raddr1[3]), .xzr_raddr2_i(core_gpr_raddr2[3]),
        .xzr_rdata1_o(core_gpr_rdata1[3]), .xzr_rdata2_o(core_gpr_rdata2[3])
    );

    assign core_if_req_rdy[0] = chip_sel_i == 2'b00 ? bus_if_req_rdy : 1'b0;
    assign core_if_req_rdy[1] = chip_sel_i == 2'b01 ? bus_if_req_rdy : 1'b0;
    assign core_if_req_rdy[2] = chip_sel_i == 2'b10 ? bus_if_req_rdy : 1'b0;
    assign core_if_req_rdy[3] = chip_sel_i == 2'b11 ? bus_if_req_rdy : 1'b0;
    assign core_if_rsp_vld[0] = chip_sel_i == 2'b00 ? bus_if_rsp_vld : 1'b0;
    assign core_if_rsp_vld[1] = chip_sel_i == 2'b01 ? bus_if_rsp_vld : 1'b0;
    assign core_if_rsp_vld[2] = chip_sel_i == 2'b10 ? bus_if_rsp_vld : 1'b0;
    assign core_if_rsp_vld[3] = chip_sel_i == 2'b11 ? bus_if_rsp_vld : 1'b0;
    assign core_if_rdata[0] = chip_sel_i == 2'b00 ? bus_if_rdata : {`DATA_WIDTH{1'b0}};
    assign core_if_rdata[1] = chip_sel_i == 2'b01 ? bus_if_rdata : {`DATA_WIDTH{1'b0}};
    assign core_if_rdata[2] = chip_sel_i == 2'b10 ? bus_if_rdata : {`DATA_WIDTH{1'b0}};
    assign core_if_rdata[3] = chip_sel_i == 2'b11 ? bus_if_rdata : {`DATA_WIDTH{1'b0}};

    assign core_mem_req_rdy[0] = chip_sel_i == 2'b00 ? bus_mem_req_rdy : 1'b0;
    assign core_mem_req_rdy[1] = chip_sel_i == 2'b01 ? bus_mem_req_rdy : 1'b0;
    assign core_mem_req_rdy[2] = chip_sel_i == 2'b10 ? bus_mem_req_rdy : 1'b0;
    assign core_mem_req_rdy[3] = chip_sel_i == 2'b11 ? bus_mem_req_rdy : 1'b0;
    assign core_mem_rsp_vld[0] = chip_sel_i == 2'b00 ? bus_mem_rsp_vld : 1'b0;
    assign core_mem_rsp_vld[1] = chip_sel_i == 2'b01 ? bus_mem_rsp_vld : 1'b0;
    assign core_mem_rsp_vld[2] = chip_sel_i == 2'b10 ? bus_mem_rsp_vld : 1'b0;
    assign core_mem_rsp_vld[3] = chip_sel_i == 2'b11 ? bus_mem_rsp_vld : 1'b0;
    assign core_mem_rdata[0] = chip_sel_i == 2'b00 ? bus_mem_rdata : {`DATA_WIDTH{1'b0}};
    assign core_mem_rdata[1] = chip_sel_i == 2'b01 ? bus_mem_rdata : {`DATA_WIDTH{1'b0}};
    assign core_mem_rdata[2] = chip_sel_i == 2'b10 ? bus_mem_rdata : {`DATA_WIDTH{1'b0}};
    assign core_mem_rdata[3] = chip_sel_i == 2'b11 ? bus_mem_rdata : {`DATA_WIDTH{1'b0}};

    perips_top u_perips_top (
        .clk(clk), .rst_n(rst_n), .debug_en_i(debug_en_i), .chip_sel_i(chip_sel_i),
        .m0_addr_i(core_if_addr[chip_sel_i]), .m0_data_i(core_if_wdata[chip_sel_i]),
        .m0_sel_i(core_if_sel[chip_sel_i]), .m0_req_vld_i(core_if_req_vld[chip_sel_i]),
        .m0_rsp_rdy_i(core_if_rsp_rdy[chip_sel_i]), .m0_we_i(core_if_we[chip_sel_i]),
        .m0_req_rdy_o(bus_if_req_rdy), .m0_rsp_vld_o(bus_if_rsp_vld), .m0_data_o(bus_if_rdata),
        .m1_addr_i(core_mem_addr[chip_sel_i]), .m1_data_i(core_mem_wdata[chip_sel_i]),
        .m1_sel_i(core_mem_sel[chip_sel_i]), .m1_req_vld_i(core_mem_req_vld[chip_sel_i]),
        .m1_rsp_rdy_i(core_mem_rsp_rdy[chip_sel_i]), .m1_we_i(core_mem_we[chip_sel_i]),
        .m1_req_rdy_o(bus_mem_req_rdy), .m1_rsp_vld_o(bus_mem_rsp_vld), .m1_data_o(bus_mem_rdata),
        .bridge_wzc_tx_data_o(bridge_wzc_tx), .bridge_wzc_rx_data_i(bridge_rx_data_i),
        .bridge_xyh_tx_data_o(bridge_xyh_tx), .bridge_xyh_rx_data_i(bridge_rx_data_i),
        .bridge_hjx_tx_data_o(bridge_hjx_tx), .bridge_hjx_rx_data_i(bridge_rx_data_i),
        .bridge_xzr_tx_data_o(bridge_xzr_tx), .bridge_xzr_rx_data_i(bridge_rx_data_i),
        .uart_tx_o(uart_tx_o), .uart_rx_i(uart_rx_i), .pwm_o(pwm_o),
        .i2c_io_ctrl_o(i2c_io_ctrl_o), .i2c_scl_i(i2c_scl_i), .i2c_sda_i(i2c_sda_i)
    );

    assign bridge_tx_data_o = bridge_wzc_tx | bridge_xyh_tx | bridge_hjx_tx | bridge_xzr_tx;
    assign succ = 1'b0;

endmodule
