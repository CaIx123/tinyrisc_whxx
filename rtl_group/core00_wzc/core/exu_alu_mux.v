`include "../marcos_wzc.v"

module exu_alu_mux(
  input [1:0] forward_a_i,
  input [1:0] forward_b_i,
  input alu_src_i,

  input wire [`DATA_WIDTH-1:0] result_ex_mem_i,
  input wire [`DATA_WIDTH-1:0] result_mem_wb_i,
  input wire [`DATA_WIDTH-1:0] data_rs1_i,
  input wire [`DATA_WIDTH-1:0] data_rs2_i,
  input wire [`DATA_WIDTH-1:0] imm_i,

  output reg [`DATA_WIDTH-1:0] alu_src_a_o,
  output reg [`DATA_WIDTH-1:0] alu_src_b_o,
  output reg [`DATA_WIDTH-1:0] data_rs2_o
);

  always @(*) begin
    case (forward_a_i)
      2'b00: alu_src_a_o = data_rs1_i;
      2'b01: alu_src_a_o = result_ex_mem_i;
      2'b10: alu_src_a_o = result_mem_wb_i;
      default: alu_src_a_o = data_rs1_i;
    endcase

    case (forward_b_i)
      2'b00: data_rs2_o = data_rs2_i;
      2'b01: data_rs2_o = result_ex_mem_i;
      2'b10: data_rs2_o = result_mem_wb_i;
      default: data_rs2_o = data_rs2_i;
    endcase

    alu_src_b_o = alu_src_i ? imm_i : data_rs2_o;
  end

endmodule
