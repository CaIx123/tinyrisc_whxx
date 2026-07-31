`timescale 1ns / 1ps

`include "../../top/macros.v"

module pipeline_ctrl(
    // from mem
    input wire stall_req_mem_i,

    // from debug controller
    input wire debug_halt_i,

    // from ifetch
    input wire stall_req_ifetch_i,

    // from id
    input wire branch_i,

    // to pc_reg
    output reg pc_stall_o,
    // to if_id
    output reg if_id_stall_o,
    // to id_ex
    output reg id_ex_stall_o,
    output reg id_ex_flush_o,
    // to ex_mem
    output reg ex_mem_stall_o,
    // to mem_wb
    output reg mem_wb_stall_o
    
    );

    always @(*) begin
        pc_stall_o = 1'b0;
        if_id_stall_o = 1'b0;
        id_ex_stall_o = 1'b0;
        id_ex_flush_o = 1'b0;
        ex_mem_stall_o = 1'b0;
        mem_wb_stall_o = 1'b0;

        if (debug_halt_i) begin
            pc_stall_o = 1'b1;
            if_id_stall_o = 1'b1;
            id_ex_stall_o = 1'b1;
            ex_mem_stall_o = 1'b1;
            mem_wb_stall_o = 1'b1;
        end else if (stall_req_mem_i) begin
            pc_stall_o = 1'b1;
            if_id_stall_o = 1'b1;
            id_ex_stall_o = 1'b1;
            ex_mem_stall_o = 1'b1;
            mem_wb_stall_o = 1'b1;
        end else if (stall_req_ifetch_i) begin
            pc_stall_o = 1'b1;
        end
    end

endmodule
