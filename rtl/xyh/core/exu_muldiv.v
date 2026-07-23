`include "defines.v"

// 乘除法执行模块
// 乘法：通过组合逻辑乘法器实现，启动后较快给出结果
// 除法/求余：调用divider子模块，多周期迭代执行
// muldiv_stall_o用于在除法期间阻塞流水线
module exu_muldiv(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire mem_stall_i,                  // 外部暂停(来自pipe_ctrl)

    input wire[31:0] muldiv_op1_i,           // 乘除操作数1(rs1)
    input wire[31:0] muldiv_op2_i,           // 乘除操作数2(rs2)
    input wire muldiv_op_mul_i,              // MUL(低32位乘)
    input wire muldiv_op_mulh_i,             // MULH(有符号高32位)
    input wire muldiv_op_mulhsu_i,           // MULHSU(有符号*无符号高32位)
    input wire muldiv_op_mulhu_i,            // MULHU(无符号高32位)
    input wire muldiv_op_div_i,              // DIV(有符号除法)
    input wire muldiv_op_divu_i,             // DIVU(无符号除法)
    input wire muldiv_op_rem_i,              // REM(有符号求余)
    input wire muldiv_op_remu_i,             // REMU(无符号求余)

    output wire[31:0] muldiv_reg_wdata_o,    // 乘除结果
    output wire muldiv_reg_we_o,             // 乘除写使能
    output wire muldiv_stall_o               // 乘除暂停(除法多周期)

    );

    wire div_ready;
    // 除法操作
    wire op_div = muldiv_op_div_i | muldiv_op_divu_i | muldiv_op_rem_i | muldiv_op_remu_i;
    wire div_start = op_div & (!div_ready) & ~mem_stall_i;
    wire[3:0] div_op = {muldiv_op_div_i, muldiv_op_divu_i, muldiv_op_rem_i, muldiv_op_remu_i};
    wire[31:0] div_result;

    divider u_divider(
        .clk(clk),
        .rst_n(rst_n),
        .dividend_i(muldiv_op1_i),
        .divisor_i(muldiv_op2_i),
        .start_i(div_start),
        .op_i(div_op),
        .result_o(div_result),
        .ready_o(div_ready)
    );

    // 乘法操作
    wire op_mul = muldiv_op_mul_i | muldiv_op_mulh_i | muldiv_op_mulhsu_i | muldiv_op_mulhu_i;
    wire[31:0] muldiv_op1_r;
    gen_en_dff #(32) mul_op1_ff(clk, rst_n, op_mul, muldiv_op1_i, muldiv_op1_r);
    wire[31:0] muldiv_op2_r;
    gen_en_dff #(32) mul_op2_ff(clk, rst_n, op_mul, muldiv_op2_i, muldiv_op2_r);

    wire mul_ready_r;
    wire mul_ready = (~mul_ready_r) & op_mul;
    gen_rst_0_dff #(1) mul_ready_ff(clk, rst_n, mul_ready, mul_ready_r);

    wire mul_start = (~mul_ready_r) & op_mul & ~mem_stall_i;

    wire op1_is_signed = muldiv_op1_r[31];
    wire op2_is_signed = muldiv_op2_r[31];
    wire[31:0] op1_complcode = op1_is_signed? (-muldiv_op1_r): muldiv_op1_r;
    wire[31:0] op2_complcode = op2_is_signed? (-muldiv_op2_r): muldiv_op2_r;

    wire[31:0] op1_mul = ({32{(muldiv_op_mul_i | muldiv_op_mulhu_i)}} & muldiv_op1_r) |
                         ({32{(muldiv_op_mulh_i | muldiv_op_mulhsu_i)}} & op1_complcode);
    wire[31:0] op2_mul = ({32{(muldiv_op_mul_i | muldiv_op_mulhu_i | muldiv_op_mulhsu_i)}} & muldiv_op2_r) |
                         ({32{(muldiv_op_mulh_i)}} & op2_complcode);
    wire[63:0] mul_res_tmp = op1_mul * op2_mul;
    wire[63:0] mul_res_tmp_complcode = -mul_res_tmp;
    wire[31:0] mul_res = mul_res_tmp[31:0];
    wire[31:0] mulhu_res = mul_res_tmp[63:32];
    wire[31:0] mulh_res = (op1_is_signed ^ op2_is_signed)? mul_res_tmp_complcode[63:32]: mul_res_tmp[63:32];
    wire[31:0] mulhsu_res = (op1_is_signed)? mul_res_tmp_complcode[63:32]: mul_res_tmp[63:32];

    reg[31:0] mul_op_res;

    always @ (*) begin
        mul_op_res = 32'h0;
        case (1'b1)
            muldiv_op_mul_i:    mul_op_res = mul_res;
            muldiv_op_mulhu_i:  mul_op_res = mulhu_res;
            muldiv_op_mulh_i:   mul_op_res = mulh_res;
            muldiv_op_mulhsu_i: mul_op_res = mulhsu_res;
        endcase
    end

    // 运算结果
    assign muldiv_reg_wdata_o = div_result | mul_op_res;
    assign muldiv_reg_we_o = div_ready | mul_ready_r;
    assign muldiv_stall_o = div_start | mul_start;

endmodule
