`include "../marcos_wzc.v"

module idu_decoder(

    // from IF/ID
    input wire[`INST_WIDTH-1:0] inst_i,

    // to GPR
    output wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr_o,

    // to hazard detector
    output wire rs1_re_o,
    output wire rs2_re_o,

    // for wb
    output wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output reg reg_write_o,
    output reg mem_to_reg_o,

    // to ex
    output reg alu_src_o,
    output reg[`ALU_CTRL_WIDTH-1:0] alu_ctrl_o,

    // to mem
    output reg mem_read_o,
    output reg mem_write_o,
    output reg[`MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    output reg[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_o,

    // to if 
    output reg branch_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[11:0] imm12 = inst_i[31:20];
    wire imm_is_zero = ~(|imm12);
    wire funct7_5 = inst_i[30];
    wire rv32m_encoding = (inst_i[31:25] == 7'b0000001);
    wire custom_if_zero = (opcode == `OPCODE_TYPE_I_CUSTOM) & (funct3 == `FUNC3_IF) & imm_is_zero;

    reg rs1_re;
    reg rs2_re;

    assign rd_waddr_o = inst_i[11:7];
    assign rs1_raddr_o = rs1_re ? inst_i[19:15] : {`GPR_ADDR_WIDTH{1'b0}};
    assign rs2_raddr_o = custom_if_zero ? 5'd31 :
                         (rs2_re ? inst_i[24:20] : {`GPR_ADDR_WIDTH{1'b0}});
    assign rs1_re_o = rs1_re;
    assign rs2_re_o = rs2_re;

    always @(*) begin
        rs1_re = 1'b0;
        rs2_re = 1'b0;
        reg_write_o = 1'b0;
        alu_src_o = 1'b0;
        alu_ctrl_o = `ALU_CTRL_ADD;
        mem_read_o = 1'b0;
        mem_write_o = 1'b0;
        mem_to_reg_o = 1'b0;
        mem_ctrl_o = `MEM_CTRL_SW;
        custom_ctrl_o = `CUSTOM_NONE;
        branch_o = 1'b0;

        case (opcode)
            `OPCODE_TYPE_R: begin
                rs1_re = 1'b1;
                rs2_re = 1'b1;
                reg_write_o = 1'b1;

                if (rv32m_encoding) begin
                    // RV32M is unsupported: consume the encoding without side effects.
                    rs1_re = 1'b0;
                    rs2_re = 1'b0;
                    reg_write_o = 1'b0;
                end else begin
                    case (funct3)
                        `FUNC3_ADD: alu_ctrl_o = {`ALU_UNIT_ALU, funct7_5 ? `ALU_OP_SUB : `ALU_OP_ADD};
                        `FUNC3_SLL: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLL};
                        `FUNC3_SLT: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLT};
                        `FUNC3_SLTU: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLTU};
                        `FUNC3_XOR: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_XOR};
                        `FUNC3_SRL: alu_ctrl_o = {`ALU_UNIT_ALU, funct7_5 ? `ALU_OP_SRA : `ALU_OP_SRL};
                        `FUNC3_OR: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_OR};
                        `FUNC3_AND: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_AND};
                        default: alu_ctrl_o = `ALU_CTRL_ADD;
                    endcase
                end
            end

            `OPCODE_TYPE_I_COMP: begin
                rs1_re = 1'b1;
                reg_write_o = 1'b1;
                alu_src_o = 1'b1;

                case (funct3)
                    `FUNC3_ADDI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_ADD};
                    `FUNC3_SLLI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLL};
                    `FUNC3_SLTI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLT};
                    `FUNC3_SLTIU: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLTU};
                    `FUNC3_XORI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_XOR};
                    `FUNC3_SRLI: alu_ctrl_o = {`ALU_UNIT_ALU, funct7_5 ? `ALU_OP_SRA : `ALU_OP_SRL};
                    `FUNC3_ORI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_OR};
                    `FUNC3_ANDI: alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_AND};
                    default: alu_ctrl_o = `ALU_CTRL_ADD;
                endcase
            end

            `OPCODE_TYPE_I_LOAD: begin
                rs1_re = 1'b1;
                reg_write_o = 1'b1;
                alu_src_o = 1'b1;
                mem_read_o = 1'b1;
                mem_to_reg_o = 1'b1;
                alu_ctrl_o = `ALU_CTRL_ADD;

                case (funct3)
                    `FUNC3_LB: begin
                        mem_ctrl_o = `MEM_CTRL_LB;
                    end
                    `FUNC3_LH: begin
                        mem_ctrl_o = `MEM_CTRL_LH;
                    end
                    `FUNC3_LW: begin
                        mem_ctrl_o = `MEM_CTRL_LW;
                    end
                    `FUNC3_LBU: begin
                        mem_ctrl_o = `MEM_CTRL_LBU;
                    end
                    `FUNC3_LHU: begin
                        mem_ctrl_o = `MEM_CTRL_LHU;
                    end
                    default: begin
                        mem_ctrl_o = `MEM_CTRL_LW;
                    end
                endcase
            end

            `OPCODE_TYPE_S: begin
                rs1_re = 1'b1;
                rs2_re = 1'b1;
                alu_src_o = 1'b1;
                mem_write_o = 1'b1;
                alu_ctrl_o = `ALU_CTRL_ADD;

                case (funct3)
                    `FUNC3_SB: mem_ctrl_o = `MEM_CTRL_SB;
                    `FUNC3_SH: mem_ctrl_o = `MEM_CTRL_SH;
                    `FUNC3_SW: mem_ctrl_o = `MEM_CTRL_SW;
                    default: mem_ctrl_o = `MEM_CTRL_SW;
                endcase
            end

            `OPCODE_TYPE_B: begin
                rs1_re = 1'b1;
                rs2_re = 1'b1;
                branch_o = 1'b1;
            end

            `OPCODE_TYPE_U_LUI,
            `OPCODE_TYPE_U_AUIPC: begin
                reg_write_o = 1'b1;
                alu_src_o = 1'b1;
                if (opcode == `OPCODE_TYPE_U_LUI) begin
                    alu_ctrl_o = `ALU_CTRL_BYPASS;
                end else begin
                    alu_ctrl_o = `ALU_CTRL_ADD;
                end
            end

            `OPCODE_TYPE_J: begin
                reg_write_o = 1'b1;
                branch_o = 1'b1;
                alu_ctrl_o = `ALU_CTRL_ADD;
            end

            `OPCODE_TYPE_I_JALR: begin
                rs1_re = 1'b1;
                reg_write_o = 1'b1;
                alu_src_o = 1'b0;
                branch_o = 1'b1;
                alu_ctrl_o = `ALU_CTRL_ADD;
            end

            `OPCODE_TYPE_I_CUSTOM: begin
                case (funct3)
                    `FUNC3_SID: begin
                        mem_read_o = 1'b1;
                        custom_ctrl_o = `CUSTOM_SID;
                    end

                    `FUNC3_RT: begin
                        reg_write_o = 1'b1;
                        mem_read_o = 1'b1;
                        mem_to_reg_o = 1'b1;
                        custom_ctrl_o = `CUSTOM_RT;
                    end

                    `FUNC3_IF: begin
                        rs1_re = 1'b1;
                        reg_write_o = 1'b1;
                        if (imm_is_zero) begin
                            rs2_re = 1'b1;
                            mem_read_o = 1'b1;
                            mem_to_reg_o = 1'b1;
                            alu_src_o = 1'b0;
                            alu_ctrl_o = {`ALU_UNIT_ALU, `ALU_OP_SLT};
                            custom_ctrl_o = `CUSTOM_IF;
                        end else begin
                            alu_src_o = 1'b1;
                            alu_ctrl_o = `ALU_CTRL_ADD;
                            custom_ctrl_o = `CUSTOM_NONE;
                        end
                    end

                    default: begin
                        custom_ctrl_o = `CUSTOM_NONE;
                    end
                endcase
            end

            default: begin
                rs1_re = 1'b0;
                rs2_re = 1'b0;
                reg_write_o = 1'b0;
                alu_src_o = 1'b0;
                alu_ctrl_o = `ALU_CTRL_ADD;
                mem_read_o = 1'b0;
                mem_write_o = 1'b0;
                mem_to_reg_o = 1'b0;
                mem_ctrl_o = `MEM_CTRL_SW;
                custom_ctrl_o = `CUSTOM_NONE;
                branch_o = 1'b0;
            end
        endcase
    end

endmodule
