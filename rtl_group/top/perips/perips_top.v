`include "../../core00_wzc/marcos.v"

module perips_top (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         debug_en_i,
    input  wire [1:0]                   chip_sel_i,

    // Selected core instruction-bus master.
    input  wire [31:0]                  m0_addr_i,
    input  wire [31:0]                  m0_data_i,
    input  wire [3:0]                   m0_sel_i,
    input  wire                         m0_req_vld_i,
    input  wire                         m0_rsp_rdy_i,
    input  wire                         m0_we_i,
    output wire                         m0_req_rdy_o,
    output wire                         m0_rsp_vld_o,
    output wire [31:0]                  m0_data_o,

    // Selected core data-bus master.
    input  wire [31:0]                  m1_addr_i,
    input  wire [31:0]                  m1_data_i,
    input  wire [3:0]                   m1_sel_i,
    input  wire                         m1_req_vld_i,
    input  wire                         m1_rsp_rdy_i,
    input  wire                         m1_we_i,
    output wire                         m1_req_rdy_o,
    output wire                         m1_rsp_vld_o,
    output wire [31:0]                  m1_data_o,

    // Four core-local ROM/RAM bridges.
    output wire [`BRIDGE_WIDTH-1:0]     bridge_wzc_tx_data_o,
    input  wire [`BRIDGE_WIDTH-1:0]     bridge_wzc_rx_data_i,
    output wire [`BRIDGE_WIDTH-1:0]     bridge_xyh_tx_data_o,
    input  wire [`BRIDGE_WIDTH-1:0]     bridge_xyh_rx_data_i,
    output wire [`BRIDGE_WIDTH-1:0]     bridge_hjx_tx_data_o,
    input  wire [`BRIDGE_WIDTH-1:0]     bridge_hjx_rx_data_i,
    output wire [`BRIDGE_WIDTH-1:0]     bridge_xzr_tx_data_o,
    input  wire [`BRIDGE_WIDTH-1:0]     bridge_xzr_rx_data_i,

    output wire                         uart_tx_o,
    input  wire                         uart_rx_i,
    output wire [3:0]                   pwm_o,
    output wire [1:0]                   i2c_io_ctrl_o,
    input  wire                         i2c_scl_i,
    input  wire                         i2c_sda_i
);

    // UART downloader/debugger is RIB master 2.
    wire        dbg_req_vld;
    wire        dbg_req_rdy;
    wire        dbg_rsp_vld;
    wire        dbg_rsp_rdy;
    wire        dbg_we;
    wire [31:0] dbg_addr;
    wire [31:0] dbg_wdata;
    wire [31:0] dbg_rdata;
    wire [3:0]  dbg_sel;

    // RIB slave 0/1: core-local ROM/RAM bridge.
    wire [31:0] s0_addr;
    wire [31:0] s0_wdata;
    wire [31:0] s0_rdata;
    wire [3:0]  s0_sel;
    wire        s0_req_vld;
    wire        s0_req_rdy;
    wire        s0_rsp_vld;
    wire        s0_rsp_rdy;
    wire        s0_we;
    wire [31:0] s1_addr;
    wire [31:0] s1_wdata;
    wire [31:0] s1_rdata;
    wire [3:0]  s1_sel;
    wire        s1_req_vld;
    wire        s1_req_rdy;
    wire        s1_rsp_vld;
    wire        s1_rsp_rdy;
    wire        s1_we;

    // RIB slave 3: UART.
    wire [31:0] s3_addr;
    wire [31:0] s3_wdata;
    wire [31:0] s3_rdata;
    wire [3:0]  s3_sel;
    wire        s3_req_vld;
    wire        s3_req_rdy;
    wire        s3_rsp_vld;
    wire        s3_rsp_rdy;
    wire        s3_we;

    // RIB slave 6: PWM.
    wire [31:0] s6_addr;
    wire [31:0] s6_wdata;
    wire [31:0] s6_rdata;
    wire [3:0]  s6_sel;
    wire        s6_req_vld;
    wire        s6_req_rdy;
    wire        s6_rsp_vld;
    wire        s6_rsp_rdy;
    wire        s6_we;

    // RIB slave 7: I2C.
    wire [31:0] s7_addr;
    wire [31:0] s7_wdata;
    wire [31:0] s7_rdata;
    wire [3:0]  s7_sel;
    wire        s7_req_vld;
    wire        s7_req_rdy;
    wire        s7_rsp_vld;
    wire        s7_rsp_rdy;
    wire        s7_we;

    uart_debug u_uart_debug (
        .clk(clk), .rst_n(rst_n), .debug_en_i(debug_en_i),
        .req_valid_o(dbg_req_vld), .req_ready_i(dbg_req_rdy),
        .rsp_valid_i(dbg_rsp_vld), .rsp_ready_o(dbg_rsp_rdy),
        .mem_we_o(dbg_we), .mem_addr_o(dbg_addr),
        .mem_wdata_o(dbg_wdata), .mem_sel_o(dbg_sel),
        .mem_rdata_i(dbg_rdata)
    );

    rib u_rib (
        .clk(clk), .rst_n(rst_n),
        .m0_addr_i(m0_addr_i), .m0_data_i(m0_data_i), .m0_sel_i(m0_sel_i),
        .m0_req_vld_i(m0_req_vld_i), .m0_rsp_rdy_i(m0_rsp_rdy_i), .m0_we_i(m0_we_i),
        .m0_req_rdy_o(m0_req_rdy_o), .m0_rsp_vld_o(m0_rsp_vld_o), .m0_data_o(m0_data_o),
        .m1_addr_i(m1_addr_i), .m1_data_i(m1_data_i), .m1_sel_i(m1_sel_i),
        .m1_req_vld_i(m1_req_vld_i), .m1_rsp_rdy_i(m1_rsp_rdy_i), .m1_we_i(m1_we_i),
        .m1_req_rdy_o(m1_req_rdy_o), .m1_rsp_vld_o(m1_rsp_vld_o), .m1_data_o(m1_data_o),
        .m2_addr_i(dbg_addr), .m2_data_i(dbg_wdata), .m2_sel_i(dbg_sel),
        .m2_req_vld_i(dbg_req_vld), .m2_rsp_rdy_i(dbg_rsp_rdy), .m2_we_i(dbg_we),
        .m2_req_rdy_o(dbg_req_rdy), .m2_rsp_vld_o(dbg_rsp_vld), .m2_data_o(dbg_rdata),
        .s0_data_i(s0_rdata), .s0_req_rdy_i(s0_req_rdy), .s0_rsp_vld_i(s0_rsp_vld),
        .s0_addr_o(s0_addr), .s0_data_o(s0_wdata), .s0_sel_o(s0_sel),
        .s0_req_vld_o(s0_req_vld), .s0_rsp_rdy_o(s0_rsp_rdy), .s0_we_o(s0_we),
        .s1_data_i(s1_rdata), .s1_req_rdy_i(s1_req_rdy), .s1_rsp_vld_i(s1_rsp_vld),
        .s1_addr_o(s1_addr), .s1_data_o(s1_wdata), .s1_sel_o(s1_sel),
        .s1_req_vld_o(s1_req_vld), .s1_rsp_rdy_o(s1_rsp_rdy), .s1_we_o(s1_we),
        .s3_data_i(s3_rdata), .s3_req_rdy_i(s3_req_rdy), .s3_rsp_vld_i(s3_rsp_vld),
        .s3_addr_o(s3_addr), .s3_data_o(s3_wdata), .s3_sel_o(s3_sel),
        .s3_req_vld_o(s3_req_vld), .s3_rsp_rdy_o(s3_rsp_rdy), .s3_we_o(s3_we),
        .s6_data_i(s6_rdata), .s6_req_rdy_i(s6_req_rdy), .s6_rsp_vld_i(s6_rsp_vld),
        .s6_addr_o(s6_addr), .s6_data_o(s6_wdata), .s6_sel_o(s6_sel),
        .s6_req_vld_o(s6_req_vld), .s6_rsp_rdy_o(s6_rsp_rdy), .s6_we_o(s6_we),
        .s7_data_i(s7_rdata), .s7_req_rdy_i(s7_req_rdy), .s7_rsp_vld_i(s7_rsp_vld),
        .s7_addr_o(s7_addr), .s7_data_o(s7_wdata), .s7_sel_o(s7_sel),
        .s7_req_vld_o(s7_req_vld), .s7_rsp_rdy_o(s7_rsp_rdy), .s7_we_o(s7_we)
    );

    /*
     * Bridge routing
     *
     * Requests are demultiplexed with the current chip_sel_i.  The selected
     * value is captured when a bridge accepts a request, then used to
     * multiplex the complete response.  Therefore chip_sel_i may change
     * after the request handshake without moving the in-flight response to
     * another core.
     */
    wire chip_wzc = chip_sel_i == 2'b00;
    wire chip_xyh = chip_sel_i == 2'b01;
    wire chip_hjx = chip_sel_i == 2'b10;
    wire chip_xzr = chip_sel_i == 2'b11;
    reg [1:0] bridge_rsp_sel_r;
    wire bridge_req_fire = (s0_req_vld & s0_req_rdy) | (s1_req_vld & s1_req_rdy);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bridge_rsp_sel_r <= 2'b00;
        else if (bridge_req_fire)
            bridge_rsp_sel_r <= chip_sel_i;
    end

    wire [31:0] b0_s0_rdata, b1_s0_rdata, b2_s0_rdata, b3_s0_rdata;
    wire [31:0] b0_s1_rdata, b1_s1_rdata, b2_s1_rdata, b3_s1_rdata;
    wire b0_s0_req_rdy, b1_s0_req_rdy, b2_s0_req_rdy, b3_s0_req_rdy;
    wire b0_s1_req_rdy, b1_s1_req_rdy, b2_s1_req_rdy, b3_s1_req_rdy;
    wire b0_s0_rsp_vld, b1_s0_rsp_vld, b2_s0_rsp_vld, b3_s0_rsp_vld;
    wire b0_s1_rsp_vld, b1_s1_rsp_vld, b2_s1_rsp_vld, b3_s1_rsp_vld;
    wire [`BRIDGE_WIDTH-1:0] b0_tx, b1_tx, b2_tx, b3_tx;

    assign s0_req_rdy = chip_wzc ? b0_s0_req_rdy : chip_xyh ? b1_s0_req_rdy :
                        chip_hjx ? b2_s0_req_rdy : b3_s0_req_rdy;
    assign s1_req_rdy = chip_wzc ? b0_s1_req_rdy : chip_xyh ? b1_s1_req_rdy :
                        chip_hjx ? b2_s1_req_rdy : b3_s1_req_rdy;
    assign s0_rdata = bridge_rsp_sel_r == 2'b00 ? b0_s0_rdata :
                      bridge_rsp_sel_r == 2'b01 ? b1_s0_rdata :
                      bridge_rsp_sel_r == 2'b10 ? b2_s0_rdata : b3_s0_rdata;
    assign s1_rdata = bridge_rsp_sel_r == 2'b00 ? b0_s1_rdata :
                      bridge_rsp_sel_r == 2'b01 ? b1_s1_rdata :
                      bridge_rsp_sel_r == 2'b10 ? b2_s1_rdata : b3_s1_rdata;
    assign s0_rsp_vld = bridge_rsp_sel_r == 2'b00 ? b0_s0_rsp_vld :
                        bridge_rsp_sel_r == 2'b01 ? b1_s0_rsp_vld :
                        bridge_rsp_sel_r == 2'b10 ? b2_s0_rsp_vld : b3_s0_rsp_vld;
    assign s1_rsp_vld = bridge_rsp_sel_r == 2'b00 ? b0_s1_rsp_vld :
                        bridge_rsp_sel_r == 2'b01 ? b1_s1_rsp_vld :
                        bridge_rsp_sel_r == 2'b10 ? b2_s1_rsp_vld : b3_s1_rsp_vld;

    // The explicit masks guarantee that every unselected external TX bus is 0.
    assign bridge_wzc_tx_data_o = ((bridge_rsp_sel_r == 2'b00) | chip_wzc) ? b0_tx : {`BRIDGE_WIDTH{1'b0}};
    assign bridge_xyh_tx_data_o = ((bridge_rsp_sel_r == 2'b01) | chip_xyh) ? b1_tx : {`BRIDGE_WIDTH{1'b0}};
    assign bridge_hjx_tx_data_o = ((bridge_rsp_sel_r == 2'b10) | chip_hjx) ? b2_tx : {`BRIDGE_WIDTH{1'b0}};
    assign bridge_xzr_tx_data_o = ((bridge_rsp_sel_r == 2'b11) | chip_xzr) ? b3_tx : {`BRIDGE_WIDTH{1'b0}};

    bridge_wzc u_bridge_wzc (
        .clk(clk), .rst_n(rst_n),
        .s0_req_vld_i(s0_req_vld & chip_wzc), .s0_rsp_rdy_i(s0_rsp_rdy & (bridge_rsp_sel_r == 2'b00)),
        .s0_we_i(s0_we & chip_wzc), .s0_addr_i(chip_wzc ? s0_addr : 32'b0),
        .s0_data_i(chip_wzc ? s0_wdata : 32'b0), .s0_sel_i(chip_wzc ? s0_sel : 4'b0),
        .s0_data_o(b0_s0_rdata), .s0_req_rdy_o(b0_s0_req_rdy), .s0_rsp_vld_o(b0_s0_rsp_vld),
        .s1_req_vld_i(s1_req_vld & chip_wzc), .s1_rsp_rdy_i(s1_rsp_rdy & (bridge_rsp_sel_r == 2'b00)),
        .s1_we_i(s1_we & chip_wzc), .s1_addr_i(chip_wzc ? s1_addr : 32'b0),
        .s1_data_i(chip_wzc ? s1_wdata : 32'b0), .s1_sel_i(chip_wzc ? s1_sel : 4'b0),
        .s1_data_o(b0_s1_rdata), .s1_req_rdy_o(b0_s1_req_rdy), .s1_rsp_vld_o(b0_s1_rsp_vld),
        .tx_data_o(b0_tx),
        .rx_data_i(((bridge_rsp_sel_r == 2'b00) | chip_wzc) ? bridge_wzc_rx_data_i : {`BRIDGE_WIDTH{1'b0}})
    );

    bridge_wzc u_bridge_xyh (
        .clk(clk), .rst_n(rst_n),
        .s0_req_vld_i(s0_req_vld & chip_xyh), .s0_rsp_rdy_i(s0_rsp_rdy & (bridge_rsp_sel_r == 2'b01)),
        .s0_we_i(s0_we & chip_xyh), .s0_addr_i(chip_xyh ? s0_addr : 32'b0),
        .s0_data_i(chip_xyh ? s0_wdata : 32'b0), .s0_sel_i(chip_xyh ? s0_sel : 4'b0),
        .s0_data_o(b1_s0_rdata), .s0_req_rdy_o(b1_s0_req_rdy), .s0_rsp_vld_o(b1_s0_rsp_vld),
        .s1_req_vld_i(s1_req_vld & chip_xyh), .s1_rsp_rdy_i(s1_rsp_rdy & (bridge_rsp_sel_r == 2'b01)),
        .s1_we_i(s1_we & chip_xyh), .s1_addr_i(chip_xyh ? s1_addr : 32'b0),
        .s1_data_i(chip_xyh ? s1_wdata : 32'b0), .s1_sel_i(chip_xyh ? s1_sel : 4'b0),
        .s1_data_o(b1_s1_rdata), .s1_req_rdy_o(b1_s1_req_rdy), .s1_rsp_vld_o(b1_s1_rsp_vld),
        .tx_data_o(b1_tx),
        .rx_data_i(((bridge_rsp_sel_r == 2'b01) | chip_xyh) ? bridge_xyh_rx_data_i : {`BRIDGE_WIDTH{1'b0}})
    );

    bridge_wzc u_bridge_hjx (
        .clk(clk), .rst_n(rst_n),
        .s0_req_vld_i(s0_req_vld & chip_hjx), .s0_rsp_rdy_i(s0_rsp_rdy & (bridge_rsp_sel_r == 2'b10)),
        .s0_we_i(s0_we & chip_hjx), .s0_addr_i(chip_hjx ? s0_addr : 32'b0),
        .s0_data_i(chip_hjx ? s0_wdata : 32'b0), .s0_sel_i(chip_hjx ? s0_sel : 4'b0),
        .s0_data_o(b2_s0_rdata), .s0_req_rdy_o(b2_s0_req_rdy), .s0_rsp_vld_o(b2_s0_rsp_vld),
        .s1_req_vld_i(s1_req_vld & chip_hjx), .s1_rsp_rdy_i(s1_rsp_rdy & (bridge_rsp_sel_r == 2'b10)),
        .s1_we_i(s1_we & chip_hjx), .s1_addr_i(chip_hjx ? s1_addr : 32'b0),
        .s1_data_i(chip_hjx ? s1_wdata : 32'b0), .s1_sel_i(chip_hjx ? s1_sel : 4'b0),
        .s1_data_o(b2_s1_rdata), .s1_req_rdy_o(b2_s1_req_rdy), .s1_rsp_vld_o(b2_s1_rsp_vld),
        .tx_data_o(b2_tx),
        .rx_data_i(((bridge_rsp_sel_r == 2'b10) | chip_hjx) ? bridge_hjx_rx_data_i : {`BRIDGE_WIDTH{1'b0}})
    );

    bridge_wzc u_bridge_xzr (
        .clk(clk), .rst_n(rst_n),
        .s0_req_vld_i(s0_req_vld & chip_xzr), .s0_rsp_rdy_i(s0_rsp_rdy & (bridge_rsp_sel_r == 2'b11)),
        .s0_we_i(s0_we & chip_xzr), .s0_addr_i(chip_xzr ? s0_addr : 32'b0),
        .s0_data_i(chip_xzr ? s0_wdata : 32'b0), .s0_sel_i(chip_xzr ? s0_sel : 4'b0),
        .s0_data_o(b3_s0_rdata), .s0_req_rdy_o(b3_s0_req_rdy), .s0_rsp_vld_o(b3_s0_rsp_vld),
        .s1_req_vld_i(s1_req_vld & chip_xzr), .s1_rsp_rdy_i(s1_rsp_rdy & (bridge_rsp_sel_r == 2'b11)),
        .s1_we_i(s1_we & chip_xzr), .s1_addr_i(chip_xzr ? s1_addr : 32'b0),
        .s1_data_i(chip_xzr ? s1_wdata : 32'b0), .s1_sel_i(chip_xzr ? s1_sel : 4'b0),
        .s1_data_o(b3_s1_rdata), .s1_req_rdy_o(b3_s1_req_rdy), .s1_rsp_vld_o(b3_s1_rsp_vld),
        .tx_data_o(b3_tx),
        .rx_data_i(((bridge_rsp_sel_r == 2'b11) | chip_xzr) ? bridge_xzr_rx_data_i : {`BRIDGE_WIDTH{1'b0}})
    );

    uart u_uart (
        .clk(clk), .rst_n(rst_n), .addr_i(s3_addr), .data_i(s3_wdata),
        .sel_i(s3_sel), .we_i(s3_we), .data_o(s3_rdata),
        .req_valid_i(s3_req_vld), .req_ready_o(s3_req_rdy),
        .rsp_valid_o(s3_rsp_vld), .rsp_ready_i(s3_rsp_rdy),
        .tx_pin(uart_tx_o), .rx_pin(uart_rx_i)
    );

    pwm u_pwm (
        .clk(clk), .rst_n(rst_n), .we_i(s6_we), .addr_i(s6_addr),
        .data_i(s6_wdata), .data_o(s6_rdata),
        .req_valid_i(s6_req_vld), .req_ready_o(s6_req_rdy),
        .rsp_valid_o(s6_rsp_vld), .rsp_ready_i(s6_rsp_rdy), .pwm_o(pwm_o)
    );

    i2c u_i2c (
        .clk(clk), .rst_n(rst_n), .we_i(s7_we), .addr_i(s7_addr),
        .data_i(s7_wdata), .data_o(s7_rdata),
        .req_valid_i(s7_req_vld), .req_ready_o(s7_req_rdy),
        .rsp_valid_o(s7_rsp_vld), .rsp_ready_i(s7_rsp_rdy),
        .i2c_io_ctrl_o(i2c_io_ctrl_o), .scl_i(i2c_scl_i), .sda_i(i2c_sda_i)
    );

    // PWM currently has no byte-select port.
    wire _unused_s6_sel = &{1'b0, s6_sel};
    wire _unused_s7_sel = &{1'b0, s7_sel};

endmodule
