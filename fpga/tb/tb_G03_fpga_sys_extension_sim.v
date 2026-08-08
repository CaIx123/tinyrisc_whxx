`timescale 1ns / 1ps

// FPGA extension-regression selector.  Each selected test drives the same
// g03_soc + fpga_top composition used inside G03_fpga_sys_sim, while the
// Icarus source list replaces the ASIC clock gate with global_clk_sel_fpga.
// No G03_top_IO, pad cell, or standard-cell library is compiled.
`ifdef FPGA_EXT_SID
`include "../../rtl_group/tb/tb_g03_sid.v"
`elsif FPGA_EXT_TEMP
`include "../../rtl_group/tb/tb_g03_rt.v"
`elsif FPGA_EXT_IF
`include "../../rtl_group/tb/tb_g03_if.v"
`else
module tb_G03_fpga_sys_extension_sim;
    initial begin
        $display("Define one of FPGA_EXT_SID, FPGA_EXT_TEMP, FPGA_EXT_IF.");
        $finish;
    end
endmodule
`endif
