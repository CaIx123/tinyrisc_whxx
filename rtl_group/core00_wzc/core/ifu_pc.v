`include "../marcos_wzc.v"

module ifu_pc(
    input wire clk,
    input wire rst_n,

    // branch signals
    input wire branch_taken_i,
    input wire [`PC_WIDTH-1:0] branch_addr_i,

    // control signals
    input wire pc_flush_i,
    input wire pc_stall_i,
    input wire debug_halt_i,

    output wire [`PC_WIDTH-1:0] pc_o
    );

    reg [`PC_WIDTH-1:0] pc;
    reg [`PC_WIDTH-1:0] pc_next;

    always @(*) begin
        pc_next = pc;

        if (debug_halt_i) begin
            pc_next = pc;
        end else if (branch_taken_i) begin
            pc_next = branch_addr_i;
        end else if (pc_stall_i | pc_flush_i) begin
            pc_next = pc;
        end else begin
            pc_next = pc + {{(`PC_WIDTH-3){1'b0}}, 3'b100};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= `CPU_RESET_ADDR;
        end else begin
            pc <= pc_next;
        end
    end

    assign pc_o = pc;

endmodule
