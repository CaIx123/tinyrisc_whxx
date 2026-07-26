`include "../marcos_wzc.v"

module ifu(
    input wire clk,
    input wire rst_n,

    // from idu, to ifu_pc
    input wire branch_taken_i,
    input wire [`PC_WIDTH-1:0] branch_addr_i,

    // from pipeline control
    input wire pc_stall_i,
    input wire if_id_stall_i,

    // from hazard detector
    input wire pc_flush_i,
    input wire if_id_flush_i,
    input wire debug_halt_i,

    output wire [`INST_WIDTH-1:0] inst_o,
    output wire [`PC_WIDTH-1:0] pc_o,
    output wire inst_valid_o,

    output wire [31:0] ibus_addr_o,
    input wire [31:0] ibus_data_i,
    output wire [31:0] ibus_data_o,
    output wire [3:0] ibus_sel_o,
    output wire ibus_we_o,
    output wire req_valid_o,
    input wire req_ready_i,
    input wire rsp_valid_i,
    output wire rsp_ready_o
    );

    wire [`PC_WIDTH-1:0] pc;
    wire inst_fire;
    wire if_id_ready = ~if_id_stall_i & ~if_id_flush_i;

    ifu_pc u_ifu_pc(
        .clk(clk),
        .rst_n(rst_n),
        .branch_taken_i(branch_taken_i),
        .branch_addr_i(branch_addr_i),
        .pc_flush_i(pc_flush_i),
        .pc_stall_i(pc_stall_i),
        .debug_halt_i(debug_halt_i),
        .pc_o(pc)
    );

    ifu_ifetch u_ifu_ifetch(
        .clk(clk),
        .rst_n(rst_n),
        .pc_i(pc),
        .if_id_ready_i(if_id_ready),
        .inst_o(inst_o),
        .inst_pc_o(pc_o),
        .inst_valid_o(inst_valid_o),
        .inst_fire_o(inst_fire),
        .ibus_addr_o(ibus_addr_o),
        .ibus_data_i(ibus_data_i),
        .ibus_data_o(ibus_data_o),
        .ibus_sel_o(ibus_sel_o),
        .ibus_we_o(ibus_we_o),
        .ibus_req_valid_o(req_valid_o),
        .ibus_req_ready_i(req_ready_i),
        .ibus_rsp_valid_i(rsp_valid_i),
        .ibus_rsp_ready_o(rsp_ready_o)
    );

endmodule
