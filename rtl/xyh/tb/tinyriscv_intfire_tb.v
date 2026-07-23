`timescale 1 ns / 1 ps

`include "defines.v"

module tinyriscv_intfire_tb;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;
    wire uart_tx_pin;
    wire succ;
    wire [2:0] pwm_o;
    tri1 iic_scl;
    tri1 iic_sda;

    wire [31:0] x3 = tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire [31:0] x26 = tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire [31:0] x27 = tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];

    integer r;

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_intfire_tb);
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b0;
        $display("test running...");
        #100;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        #200;

        wait (x26 == 32'h1)
        #400;
        if (x27 == 32'h1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1) begin
                $display("x%2d = 0x%x", r, tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[r]);
            end
        end

        $finish;
    end

    initial begin
        #1000000;
        $display("Time Out.");
        $display("DBG x26=%08x x27=%08x x3=%08x", x26, x27, x3);
        $display("DBG pc=%08x inst=%08x",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_ifu.pc_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_ifu_idu.inst_o);
        $display("DBG intfire state=%0d running=%0d ready=%0d req_issued=%0d start_i=%0d stall=%0d",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.state,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.running_r,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.ready_r,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.req_issued_r,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.start_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.stall_o);
        $display("DBG intfire bus req=%0d valid=%0d we=%0d addr=%08x wdata=%08x req_hsked=%0d rsp_hsked=%0d",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_req_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_valid_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_we_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_addr_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_wdata_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_req_hsked,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_exu.u_exu_extension.u_ext_intfire.bus_rsp_hsked);
        $display("DBG dbus req_valid=%0d req_ready=%0d rsp_valid=%0d rsp_ready=%0d addr=%08x we=%0d",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_req_valid_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_req_ready_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_rsp_valid_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_rsp_ready_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_addr_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.dbus_we_o);
        $display("DBG rib m1_req_rdy=%0d m1_rsp_vld=%0d s2_req_vld=%0d s2_req_rdy=%0d s2_rsp_vld=%0d s2_rsp_rdy=%0d",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_rib.m1_req_rdy_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.u_rib.m1_rsp_vld_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.s2_req_vld_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.s2_req_rdy_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.s2_rsp_vld_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.s2_rsp_rdy_o);
        $display("DBG uart req_valid=%0d req_ready=%0d rsp_valid=%0d rsp_ready=%0d delayed_active=%0d status=%08x state=%0d",
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.req_valid_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.req_ready_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.rsp_valid_o,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.rsp_ready_i,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.delayed_active_r,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.uart_status,
            tinyriscv_intfire_tb_0.u_tinyriscv_soc_top.uart_0.state);
        $finish;
    end

    initial begin
        $readmemh("inst.data", tinyriscv_intfire_tb_0.u_exmem_top.u_exrom._ram);
    end

    tinyriscv_sys_top tinyriscv_intfire_tb_0(
        .clk(clk),
        .rst(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(~uart_debug_pin),
        .succ(succ),
        .pwm_o(pwm_o),
        .iic_scl(iic_scl),
        .iic_sda(iic_sda)
    );

endmodule
