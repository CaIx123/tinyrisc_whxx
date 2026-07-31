`include "core/defines.v"
`include "tiny_macro.v"

// TinyRISC SoC integration for the XYH core.
// Shared peripherals and the shared RIB live in rtl/shared src.
module tinyriscv_soc_top(
    input  wire                 clk,
    input  wire                 rst_ext_i,

    output wire                 uart_tx_pin,
    input  wire                 uart_rx_pin,
    input  wire                 uart_debug_pin,
    output wire                 succ,

    output wire [3:0]           pwm_o,
    inout  wire                 iic_scl,
    inout  wire                 iic_sda,

    output wire [`PWIDTH_O-1:0] tx_data_o,
    input  wire [`PWIDTH_I-1:0] rx_data_i
);

    // RIB masters: instruction, data, and UART debug.
    wire [31:0] m0_addr_i;
    wire [31:0] m0_data_i;
    wire [3:0]  m0_sel_i;
    wire        m0_req_vld_i;
    wire        m0_rsp_rdy_i;
    wire        m0_we_i;
    wire        m0_req_rdy_o;
    wire        m0_rsp_vld_o;
    wire [31:0] m0_data_o;

    wire [31:0] m1_addr_i;
    wire [31:0] m1_data_i;
    wire [3:0]  m1_sel_i;
    wire        m1_req_vld_i;
    wire        m1_rsp_rdy_i;
    wire        m1_we_i;
    wire        m1_req_rdy_o;
    wire        m1_rsp_vld_o;
    wire [31:0] m1_data_o;

    wire [31:0] m2_addr_i;
    wire [31:0] m2_data_i;
    wire [3:0]  m2_sel_i;
    wire        m2_req_vld_i;
    wire        m2_rsp_rdy_i;
    wire        m2_we_i;
    wire        m2_req_rdy_o;
    wire        m2_rsp_vld_o;
    wire [31:0] m2_data_o;

    // Shared RIB slaves use their address-region number in the signal name.
    wire [31:0] s0_data_i;
    wire        s0_req_rdy_i;
    wire        s0_rsp_vld_i;
    wire [31:0] s0_addr_o;
    wire [31:0] s0_data_o;
    wire [3:0]  s0_sel_o;
    wire        s0_req_vld_o;
    wire        s0_rsp_rdy_o;
    wire        s0_we_o;

    wire [31:0] s1_data_i;
    wire        s1_req_rdy_i;
    wire        s1_rsp_vld_i;
    wire [31:0] s1_addr_o;
    wire [31:0] s1_data_o;
    wire [3:0]  s1_sel_o;
    wire        s1_req_vld_o;
    wire        s1_rsp_rdy_o;
    wire        s1_we_o;

    wire [31:0] s3_data_i;
    wire        s3_req_rdy_i;
    wire        s3_rsp_vld_i;
    wire [31:0] s3_addr_o;
    wire [31:0] s3_data_o;
    wire [3:0]  s3_sel_o;
    wire        s3_req_vld_o;
    wire        s3_rsp_rdy_o;
    wire        s3_we_o;

    wire [31:0] s6_data_i;
    wire        s6_req_rdy_i;
    wire        s6_rsp_vld_i;
    wire [31:0] s6_addr_o;
    wire [31:0] s6_data_o;
    wire [3:0]  s6_sel_o;
    wire        s6_req_vld_o;
    wire        s6_rsp_rdy_o;
    wire        s6_we_o;

    wire [31:0] s7_data_i;
    wire        s7_req_rdy_i;
    wire        s7_rsp_vld_i;
    wire [31:0] s7_addr_o;
    wire [31:0] s7_data_o;
    wire [3:0]  s7_sel_o;
    wire        s7_req_vld_o;
    wire        s7_rsp_rdy_o;
    wire        s7_we_o;

    wire        rst_n;
    wire [31:0] core_x26;
    wire [31:0] core_x27;
    reg         succ_r;
    reg         uart_debug_pin_r;
    wire        pc_rst_pulse;

    rst_ctrl u_rst_ctrl(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .rst_jtag_i(1'b0),
        .core_rst_n_o(rst_n),
        .jtag_rst_n_o()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            succ_r <= 1'b0;
        end else begin
            succ_r <= core_x26[0] & core_x27[0];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_debug_pin_r <= 1'b1;
        end else begin
            uart_debug_pin_r <= uart_debug_pin;
        end
    end

    assign succ = ~succ_r;
    assign pc_rst_pulse = uart_debug_pin & ~uart_debug_pin_r;

    tinyriscv_core u_tinyriscv_core(
        .clk(clk),
        .rst_n(rst_n),
        .pc_rst_i(pc_rst_pulse),

        .ibus_addr_o(m0_addr_i),
        .ibus_data_i(m0_data_o),
        .ibus_data_o(m0_data_i),
        .ibus_we_o(m0_we_i),
        .ibus_sel_o(m0_sel_i),
        .ibus_req_valid_o(m0_req_vld_i),
        .ibus_req_ready_i(m0_req_rdy_o),
        .ibus_rsp_valid_i(m0_rsp_vld_o),
        .ibus_rsp_ready_o(m0_rsp_rdy_i),

        .dbus_addr_o(m1_addr_i),
        .dbus_data_i(m1_data_o),
        .dbus_data_o(m1_data_i),
        .dbus_we_o(m1_we_i),
        .dbus_sel_o(m1_sel_i),
        .dbus_req_valid_o(m1_req_vld_i),
        .dbus_req_ready_i(m1_req_rdy_o),
        .dbus_rsp_valid_i(m1_rsp_vld_o),
        .dbus_rsp_ready_o(m1_rsp_rdy_i),

        .jtag_halt_i(~uart_debug_pin),
        .x26_o(core_x26),
        .x27_o(core_x27)
    );

    rib_bridge u_rib_bridge(
        .clk(clk),
        .rst(~rst_n),

        .s0_req_vld_i(s0_req_vld_o),
        .s0_rsp_rdy_i(s0_rsp_rdy_o),
        .s0_we_i(s0_we_o),
        .s0_addr_i(s0_addr_o),
        .s0_data_i(s0_data_o),
        .s0_sel_i(s0_sel_o),
        .s0_data_o(s0_data_i),
        .s0_req_rdy_o(s0_req_rdy_i),
        .s0_rsp_vld_o(s0_rsp_vld_i),

        .s1_req_vld_i(s1_req_vld_o),
        .s1_rsp_rdy_i(s1_rsp_rdy_o),
        .s1_we_i(s1_we_o),
        .s1_addr_i(s1_addr_o),
        .s1_data_i(s1_data_o),
        .s1_sel_i(s1_sel_o),
        .s1_data_o(s1_data_i),
        .s1_req_rdy_o(s1_req_rdy_i),
        .s1_rsp_vld_o(s1_rsp_vld_i),

        .tx_data_o(tx_data_o),
        .rx_data_i(rx_data_i)
    );

    uart uart_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .sel_i(s3_sel_o),
        .we_i(s3_we_o),
        .data_o(s3_data_i),
        .req_valid_i(s3_req_vld_o),
        .req_ready_o(s3_req_rdy_i),
        .rsp_valid_o(s3_rsp_vld_i),
        .rsp_ready_i(s3_rsp_rdy_o),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    wire [3:0] pwm_raw;
    assign pwm_o = ~pwm_raw;

    pwm u_pwm(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(s6_we_o),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .data_o(s6_data_i),
        .req_valid_i(s6_req_vld_o),
        .req_ready_o(s6_req_rdy_i),
        .rsp_valid_o(s6_rsp_vld_i),
        .rsp_ready_i(s6_rsp_rdy_o),
        .pwm_o(pwm_raw)
    );

    i2c u_i2c(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .req_valid_i(s7_req_vld_o),
        .req_ready_o(s7_req_rdy_i),
        .rsp_valid_o(s7_rsp_vld_i),
        .rsp_ready_i(s7_rsp_rdy_o),
        .scl(iic_scl),
        .sda(iic_sda)
    );

    uart_debug u_uart_debug(
        .clk(clk),
        .rst_n(rst_n),
        .debug_en_i(~uart_debug_pin),
        .req_valid_o(m2_req_vld_i),
        .req_ready_i(m2_req_rdy_o),
        .rsp_valid_i(m2_rsp_vld_o),
        .rsp_ready_o(m2_rsp_rdy_i),
        .mem_we_o(m2_we_i),
        .mem_addr_o(m2_addr_i),
        .mem_wdata_o(m2_data_i),
        .mem_sel_o(m2_sel_i),
        .mem_rdata_i(m2_data_o)
    );

    rib u_rib(
        .clk(clk),
        .rst_n(rst_n),

        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_sel_i(m0_sel_i),
        .m0_req_vld_i(m0_req_vld_i),
        .m0_rsp_rdy_i(m0_rsp_rdy_i),
        .m0_we_i(m0_we_i),
        .m0_req_rdy_o(m0_req_rdy_o),
        .m0_rsp_vld_o(m0_rsp_vld_o),
        .m0_data_o(m0_data_o),

        .m1_addr_i(m1_addr_i),
        .m1_data_i(m1_data_i),
        .m1_sel_i(m1_sel_i),
        .m1_req_vld_i(m1_req_vld_i),
        .m1_rsp_rdy_i(m1_rsp_rdy_i),
        .m1_we_i(m1_we_i),
        .m1_req_rdy_o(m1_req_rdy_o),
        .m1_rsp_vld_o(m1_rsp_vld_o),
        .m1_data_o(m1_data_o),

        .m2_addr_i(m2_addr_i),
        .m2_data_i(m2_data_i),
        .m2_sel_i(m2_sel_i),
        .m2_req_vld_i(m2_req_vld_i),
        .m2_rsp_rdy_i(m2_rsp_rdy_i),
        .m2_we_i(m2_we_i),
        .m2_req_rdy_o(m2_req_rdy_o),
        .m2_rsp_vld_o(m2_rsp_vld_o),
        .m2_data_o(m2_data_o),

        .s0_data_i(s0_data_i),
        .s0_req_rdy_i(s0_req_rdy_i),
        .s0_rsp_vld_i(s0_rsp_vld_i),
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_sel_o(s0_sel_o),
        .s0_req_vld_o(s0_req_vld_o),
        .s0_rsp_rdy_o(s0_rsp_rdy_o),
        .s0_we_o(s0_we_o),

        .s1_data_i(s1_data_i),
        .s1_req_rdy_i(s1_req_rdy_i),
        .s1_rsp_vld_i(s1_rsp_vld_i),
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_sel_o(s1_sel_o),
        .s1_req_vld_o(s1_req_vld_o),
        .s1_rsp_rdy_o(s1_rsp_rdy_o),
        .s1_we_o(s1_we_o),

        .s3_data_i(s3_data_i),
        .s3_req_rdy_i(s3_req_rdy_i),
        .s3_rsp_vld_i(s3_rsp_vld_i),
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_sel_o(s3_sel_o),
        .s3_req_vld_o(s3_req_vld_o),
        .s3_rsp_rdy_o(s3_rsp_rdy_o),
        .s3_we_o(s3_we_o),

        .s6_data_i(s6_data_i),
        .s6_req_rdy_i(s6_req_rdy_i),
        .s6_rsp_vld_i(s6_rsp_vld_i),
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_sel_o(s6_sel_o),
        .s6_req_vld_o(s6_req_vld_o),
        .s6_rsp_rdy_o(s6_rsp_rdy_o),
        .s6_we_o(s6_we_o),

        .s7_data_i(s7_data_i),
        .s7_req_rdy_i(s7_req_rdy_i),
        .s7_rsp_vld_i(s7_rsp_vld_i),
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_sel_o(s7_sel_o),
        .s7_req_vld_o(s7_req_vld_o),
        .s7_rsp_rdy_o(s7_rsp_rdy_o),
        .s7_we_o(s7_we_o)
    );

endmodule
