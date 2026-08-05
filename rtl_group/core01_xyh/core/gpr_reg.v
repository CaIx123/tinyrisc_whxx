`include "../../top/macros.v"

// 通用寄存器堆模块(32 x 32bit)
// 双读单写端口，x0恒为0
// 同拍写回与读冲突时通过组合逻辑提供旁路(wdata_i直接绕过寄存器)
// 额外导出x26和x27用于生成测试成功信号
module gpr_reg_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire we_i,                         // 写使能
    input wire[4:0] waddr_i,                 // 写地址
    input wire[31:0] wdata_i,                // 写数据

    input wire[4:0] raddr1_i,                // 读端口1地址
    output wire[31:0] rdata1_o,              // 读端口1数据

    input wire[4:0] raddr2_i,                // 读端口2地址
    output wire[31:0] rdata2_o,              // 读端口2数据

    output wire[31:0] x26_o,                 // 寄存器x26值(用于测试成功)
    output wire[31:0] x27_o                  // 寄存器x27值(用于测试成功)

    );

    wire[32-1:0] regs[32-1:0];
    wire[32-1:0] we;

    genvar i;

    generate
        for (i = 0; i < 32; i = i + 1) begin: gpr_rw
            // x0 cannot be wrote since it is constant-zeros
            if (i == 0) begin: is_x0
                assign we[i] = 1'b0;
                assign regs[i] = 32'h0;
            end else begin: not_x0
                assign we[i] = we_i & (waddr_i == i);
                gen_en_dffnr #(32) rf_dff(clk, we[i], wdata_i, regs[i]);
            end
        end
    endgenerate

    assign rdata1_o = (|raddr1_i)? ((we_i & (waddr_i == raddr1_i))? wdata_i: regs[raddr1_i]): 32'h0;
    assign rdata2_o = (|raddr2_i)? ((we_i & (waddr_i == raddr2_i))? wdata_i: regs[raddr2_i]): 32'h0;
    assign x26_o = regs[26];
    assign x27_o = regs[27];

    // for debug
    wire[31:0] ra = regs[1];
    wire[31:0] sp = regs[2];
    wire[31:0] gp = regs[3];
    wire[31:0] tp = regs[4];
    wire[31:0] t0 = regs[5];
    wire[31:0] t1 = regs[6];
    wire[31:0] t2 = regs[7];
    wire[31:0] s0 = regs[8];
    wire[31:0] fp = regs[8];
    wire[31:0] s1 = regs[9];
    wire[31:0] a0 = regs[10];
    wire[31:0] a1 = regs[11];
    wire[31:0] a2 = regs[12];
    wire[31:0] a3 = regs[13];
    wire[31:0] a4 = regs[14];
    wire[31:0] a5 = regs[15];
    wire[31:0] a6 = regs[16];
    wire[31:0] a7 = regs[17];
    wire[31:0] s2 = regs[18];
    wire[31:0] s3 = regs[19];
    wire[31:0] s4 = regs[20];
    wire[31:0] s5 = regs[21];
    wire[31:0] s6 = regs[22];
    wire[31:0] s7 = regs[23];
    wire[31:0] s8 = regs[24];
    wire[31:0] s9 = regs[25];
    wire[31:0] s10 = regs[26];
    wire[31:0] s11 = regs[27];
    wire[31:0] t3 = regs[28];
    wire[31:0] t4 = regs[29];
    wire[31:0] t5 = regs[30];
    wire[31:0] t6 = regs[31];

endmodule
