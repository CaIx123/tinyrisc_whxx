`include "../marcos_wzc.v"

module exu_alu(

    input wire[`DATA_WIDTH-1:0] alu_src_a_i,
    input wire[`DATA_WIDTH-1:0] alu_src_b_i,
    input wire[`ALU_CTRL_WIDTH-1:0] alu_ctrl_i,

    output reg[`DATA_WIDTH-1:0] alu_result_o

    );

    wire[3:0] alu_op = alu_ctrl_i[3:0];
    wire[`DATA_WIDTH-1:0] shamt = {{(`DATA_WIDTH-5){1'b0}}, alu_src_b_i[4:0]};

    always @(*) begin
        alu_result_o = {`DATA_WIDTH{1'b0}};

        case (alu_ctrl_i[5:4])
            `ALU_UNIT_BYPASS: begin
                alu_result_o = alu_src_b_i;
            end

            default: begin
                case (alu_op)
                    `ALU_OP_ADD: begin
                        alu_result_o = alu_src_a_i + alu_src_b_i;
                    end
                    `ALU_OP_SUB: begin
                        alu_result_o = alu_src_a_i - alu_src_b_i;
                    end
                    `ALU_OP_AND: begin
                        alu_result_o = alu_src_a_i & alu_src_b_i;
                    end
                    `ALU_OP_OR: begin
                        alu_result_o = alu_src_a_i | alu_src_b_i;
                    end
                    `ALU_OP_XOR: begin
                        alu_result_o = alu_src_a_i ^ alu_src_b_i;
                    end
                    `ALU_OP_SLL: begin
                        alu_result_o = alu_src_a_i << shamt[4:0];
                    end
                    `ALU_OP_SRL: begin
                        alu_result_o = alu_src_a_i >> shamt[4:0];
                    end
                    `ALU_OP_SRA: begin
                        alu_result_o = $signed(alu_src_a_i) >>> shamt[4:0];
                    end
                    `ALU_OP_SLT: begin
                        alu_result_o = {{(`DATA_WIDTH-1){1'b0}}, ($signed(alu_src_a_i) < $signed(alu_src_b_i))};
                    end
                    `ALU_OP_SLTU: begin
                        alu_result_o = {{(`DATA_WIDTH-1){1'b0}}, (alu_src_a_i < alu_src_b_i)};
                    end
                    default: begin
                        alu_result_o = {`DATA_WIDTH{1'b0}};
                    end
                endcase
            end
        endcase
    end

endmodule
