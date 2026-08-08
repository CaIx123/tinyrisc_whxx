`timescale 1ns / 1ps

// Focused VCD wrapper for the existing FPGA UART-download testbench.
//
// Example (from test_all/build):
//   vvp tb_g03_fpga_timing.vvp \
//       +FW=../../fpga/test/example/Baisc_Inst_Example/inst_add.data \
//       +WORDS=223 +CHIP=1 +VCD=../../fpga/tmp/fpga_xyh_inst_add_timing.vcd
//
// CHIP=1 selects the XYH core.  The included testbench performs the normal
// UART download, holds debug_en during download, then releases it to run.
`include "tb_G03_fpga_sys_sim.v"

module tb_g03_fpga_timing;

    reg [1023:0] vcd_path;

    // Reuse the validated FPGA-only environment; do not bypass UART debug or
    // replace the physical 256-word ROM / 16-word RAM model.
    tb_G03_fpga_sys_sim u_test ();

    // Signals selected for timing diagnosis.  These are aliases so the VCD
    // remains compact while still showing reset, debug release, fetch and
    // architectural register writeback for the XYH core.
    wire        clk          = u_test.clk;
    wire        rst_n_i      = u_test.rst_n;
    wire        debug_en_i   = u_test.debug_en;
    wire [1:0]  chip_sel_i   = u_test.chip_sel;
    wire        uart_rx_i    = u_test.uart_rx;
    wire        uart_tx_o    = u_test.uart_tx;
    wire        succ         = u_test.succ;
    wire [31:0] x26          = u_test.x26;
    wire [31:0] x27          = u_test.x27;

    wire        xyh_gpr_we   = u_test.dut.u_g03_soc.core_gpr_we[1];
    wire [4:0]  xyh_gpr_addr = u_test.dut.u_g03_soc.core_gpr_waddr[1];
    wire [31:0] xyh_gpr_data = u_test.dut.u_g03_soc.core_gpr_wdata[1];
    wire [31:0] xyh_if_addr  = u_test.dut.u_g03_soc.core_if_addr[1];
    wire        xyh_if_req   = u_test.dut.u_g03_soc.core_if_req_vld[1];
    wire        xyh_if_ready = u_test.dut.u_g03_soc.core_if_req_rdy[1];
    wire        xyh_if_rsp   = u_test.dut.u_g03_soc.core_if_rsp_vld[1];
    wire        xyh_if_rdy   = u_test.dut.u_g03_soc.core_if_rsp_rdy[1];

    wire [7:0]  uart_debug_state =
        u_test.dut.u_g03_soc.u_perips_top.u_uart_debug.state;
    wire [31:0] uart_write_addr =
        u_test.dut.u_g03_soc.u_perips_top.u_uart_debug.write_mem_addr;
    wire [31:0] uart_write_data =
        u_test.dut.u_g03_soc.u_perips_top.u_uart_debug.write_mem_data;

    initial begin
        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "fpga/tmp/fpga_timing.vcd";

        $dumpfile(vcd_path);
        $dumpvars(0, clk);
        $dumpvars(0, rst_n_i);
        $dumpvars(0, debug_en_i);
        $dumpvars(0, chip_sel_i);
        $dumpvars(0, uart_rx_i);
        $dumpvars(0, uart_tx_o);
        $dumpvars(0, succ);
        $dumpvars(0, x26);
        $dumpvars(0, x27);
        $dumpvars(0, xyh_gpr_we);
        $dumpvars(0, xyh_gpr_addr);
        $dumpvars(0, xyh_gpr_data);
        $dumpvars(0, xyh_if_addr);
        $dumpvars(0, xyh_if_req);
        $dumpvars(0, xyh_if_ready);
        $dumpvars(0, xyh_if_rsp);
        $dumpvars(0, xyh_if_rdy);
        $dumpvars(0, uart_debug_state);
        $dumpvars(0, uart_write_addr);
        $dumpvars(0, uart_write_data);
    end

endmodule
