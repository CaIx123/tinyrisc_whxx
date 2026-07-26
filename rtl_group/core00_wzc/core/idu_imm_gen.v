`include "../marcos_wzc.v"

// Immediate generator for RV32I/RV32M.
// CSR/system instructions are intentionally not decoded here.
module idu_imm_gen(

    input wire[`INST_WIDTH-1:0] inst_i,
    output reg[`DATA_WIDTH-1:0] imm_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];

    wire[`DATA_WIDTH-1:0] imm_i = {{20{inst_i[31]}}, inst_i[31:20]};
    wire[`DATA_WIDTH-1:0] imm_s = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
    wire[`DATA_WIDTH-1:0] imm_b = {{19{inst_i[31]}}, inst_i[31], inst_i[7],
                                   inst_i[30:25], inst_i[11:8], 1'b0};
    wire[`DATA_WIDTH-1:0] imm_u = {inst_i[31:12], 12'b0};
    wire[`DATA_WIDTH-1:0] imm_j = {{11{inst_i[31]}}, inst_i[31], inst_i[19:12],
                                   inst_i[20], inst_i[30:21], 1'b0};
    wire[`DATA_WIDTH-1:0] imm_shamt = {{27{1'b0}}, inst_i[24:20]};

    always @(*) begin
        case (opcode)
            `OPCODE_TYPE_I_JALR,
            `OPCODE_TYPE_I_LOAD,
            `OPCODE_TYPE_I_CUSTOM: begin
                imm_o = imm_i;
            end

            `OPCODE_TYPE_I_COMP: begin
                case (funct3)
                    `FUNC3_SLLI,
                    `FUNC3_SRLI: begin
                        imm_o = imm_shamt;
                    end
                    default: begin
                        imm_o = imm_i;
                    end
                endcase
            end

            `OPCODE_TYPE_S: begin
                imm_o = imm_s;
            end

            `OPCODE_TYPE_B: begin
                imm_o = imm_b;
            end

            `OPCODE_TYPE_U_LUI,
            `OPCODE_TYPE_U_AUIPC: begin
                imm_o = imm_u;
            end

            `OPCODE_TYPE_J: begin
                imm_o = imm_j;
            end

            `OPCODE_TYPE_R: begin
                imm_o = {`DATA_WIDTH{1'b0}};
            end

            default: begin
                imm_o = {`DATA_WIDTH{1'b0}};
            end
        endcase
    end

endmodule
