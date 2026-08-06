export DESIGN_NICKNAME = tinyriscv
export DESIGN_NAME = g03_top_IO
export PLATFORM    = tsmc180

export VERILOG_FILES = \
    ./designs/src/$(DESIGN_NICKNAME)/top/macros.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/G03_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/G03_top_IO.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/clk_rst/global_clk_sel.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/clk_rst/global_rst_ctrl.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/ip/icg.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/gpr/gpr.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/gpr/gpr_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/perips_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/rib.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/i2c.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/pwm.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/uart.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/uart_debug.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/bridge/bridge_wzc.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/bridge/bridge_xyh.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/bridge/bridge_hjx.v \
    ./designs/src/$(DESIGN_NICKNAME)/top/perips/bridge/bridge_xzr.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core_wzc.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/exu_alu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/exu_alu_mux.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/exu_forwarding_unit.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/exu_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/global_pipeline_ctrl.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_branch_predictor.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_decoder.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_gpr_mux.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_hazard_detector.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_imm_gen.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/idu_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/ifu_ifetch.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/ifu_pc.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/ifu_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/kalsit_core.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/mem_ifu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/mem_lsu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/mem_rtu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/mem_sidu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/mem_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/preg_ex_mem.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/preg_id_ex.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/preg_if_id.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/preg_mem_wb.v \
    ./designs/src/$(DESIGN_NICKNAME)/core00_wzc/core/wbu_top.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core_xyh.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/ext_intfire.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/ext_readtemp.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/ext_sendid.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu_alu_datapath.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu_commit.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu_dispatch.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu_extension.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/exu_mem.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/gpr_reg.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/idu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/idu_exu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/ifu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/ifu_idu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core01_xyh/core/pipe_ctrl.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core_hjx.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_alu_datapath.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_commit.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_dispatch.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_ext_if.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_ext_rt.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_ext_sid.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/exu_mem.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/gpr_reg.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/idu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/idu_exu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/ifu_hjx.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/ifu_idu.v \
    ./designs/src/$(DESIGN_NICKNAME)/core10_hjx/core/pipe_ctrl.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core_xzr.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/ctrl.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/ex.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/forwarding_unit.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/id.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/id_ex.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/if_id.v \
    ./designs/src/$(DESIGN_NICKNAME)/core11_xzr/core/pc_reg.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/gen_dff.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/gen_buf.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/gen_ram.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/vld_rdy.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/full_handshake_tx.v \
    ./designs/src/$(DESIGN_NICKNAME)/utils/full_handshake_rx.v

export PR_SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint_for_pr.sdc
export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc
export IO_FILE = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/io.file
