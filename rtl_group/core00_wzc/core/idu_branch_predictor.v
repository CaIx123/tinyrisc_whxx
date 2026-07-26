`include "../marcos_wzc.v"

module idu_branch_predictor(

    input wire[`INST_WIDTH-1:0] inst_i,
    input wire[`PC_WIDTH-1:0] pc_i,
    input wire[`DATA_WIDTH-1:0] imm_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr_i,
    input wire[`DATA_WIDTH-1:0] rdata1_i,
    input wire[`DATA_WIDTH-1:0] rdata2_i,

    // from EX/MEM, for ID-stage branch/jalr forwarding
    input wire[`DATA_WIDTH-1:0] ex_mem_result_i,
    input wire[`GPR_ADDR_WIDTH-1:0] ex_mem_rd_waddr_i,
    input wire ex_mem_reg_write_i,
    input wire ex_mem_mem_to_reg_i,

    output reg branch_req_o,
    output reg branch_condition_o,
    output reg[`PC_WIDTH-1:0] branch_addr_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];

    wire[`DATA_WIDTH-1:0] branch_rdata1 =
        (ex_mem_reg_write_i & ~ex_mem_mem_to_reg_i & (|ex_mem_rd_waddr_i) & (ex_mem_rd_waddr_i == rs1_raddr_i)) ? ex_mem_result_i :
        rdata1_i;

    wire[`DATA_WIDTH-1:0] branch_rdata2 =
        (ex_mem_reg_write_i & ~ex_mem_mem_to_reg_i & (|ex_mem_rd_waddr_i) & (ex_mem_rd_waddr_i == rs2_raddr_i)) ? ex_mem_result_i :
        rdata2_i;

    reg branch_condition;

    always @(*) begin
        case (funct3)
            `FUNC3_BEQ: begin
                branch_condition = (branch_rdata1 == branch_rdata2);
            end
            `FUNC3_BNE: begin
                branch_condition = (branch_rdata1 != branch_rdata2);
            end
            `FUNC3_BLT: begin
                branch_condition = ($signed(branch_rdata1) < $signed(branch_rdata2));
            end
            `FUNC3_BGE: begin
                branch_condition = ($signed(branch_rdata1) >= $signed(branch_rdata2));
            end
            `FUNC3_BLTU: begin
                branch_condition = (branch_rdata1 < branch_rdata2);
            end
            `FUNC3_BGEU: begin
                branch_condition = (branch_rdata1 >= branch_rdata2);
            end
            default: begin
                branch_condition = 1'b0;
            end
        endcase
    end

    always @(*) begin
        branch_req_o = 1'b0;
        branch_condition_o = 1'b0;
        branch_addr_o = {`PC_WIDTH{1'b0}};

        case (opcode)
            `OPCODE_TYPE_B: begin
                branch_req_o = 1'b1;
                branch_condition_o = branch_condition;
                branch_addr_o = pc_i + imm_i;
            end

            `OPCODE_TYPE_J: begin
                branch_req_o = 1'b1;
                branch_condition_o = 1'b1;
                branch_addr_o = pc_i + imm_i;
            end

            `OPCODE_TYPE_I_JALR: begin
                branch_req_o = 1'b1;
                branch_condition_o = 1'b1;
                branch_addr_o = (branch_rdata1 + imm_i) & ~{{(`PC_WIDTH-1){1'b0}}, 1'b1};
            end

            default: begin
                branch_condition_o = 1'b0;
                branch_addr_o = {`PC_WIDTH{1'b0}};
            end
        endcase
    end

endmodule
