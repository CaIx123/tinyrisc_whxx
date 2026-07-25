`include "../marcos.v"

module idu_gpr_mux(

    input wire[`INST_WIDTH-1:0] inst_i,
    input wire[`PC_WIDTH-1:0] pc_i,
    input wire[`DATA_WIDTH-1:0] rdata1_i,
    input wire[`DATA_WIDTH-1:0] rdata2_i,

    output reg[`DATA_WIDTH-1:0] data_rs1_o,
    output reg[`DATA_WIDTH-1:0] data_rs2_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[`DATA_WIDTH-1:0] pc = {{(`DATA_WIDTH-`PC_WIDTH){1'b0}}, pc_i};

    always @(*) begin
        data_rs1_o = rdata1_i;
        data_rs2_o = rdata2_i;

        case (opcode)
            `OPCODE_TYPE_U_AUIPC: begin
                data_rs1_o = pc;
                data_rs2_o = rdata2_i;
            end

            `OPCODE_TYPE_J,
            `OPCODE_TYPE_I_JALR: begin
                data_rs1_o = pc;
                data_rs2_o = {{(`DATA_WIDTH-3){1'b0}}, 3'd4};
            end

            default: begin
                data_rs1_o = rdata1_i;
                data_rs2_o = rdata2_i;
            end
        endcase
    end

endmodule
