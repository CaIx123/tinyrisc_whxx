`include "defines.v"

// 写回选择模块
// 根据优先级从多个执行结果中选择最终写回寄存器的数据
// 优先级：MULDIV > MEM > EXT > CSR > BJP > ALU(普通运算)
module exu_commit(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire req_muldiv_i,                 // 乘除请求
    input wire muldiv_reg_we_i,              // 乘除写使能
    input wire[4:0] muldiv_reg_waddr_i,      // 乘除写地址
    input wire[31:0] muldiv_reg_wdata_i,     // 乘除写数据

    input wire req_mem_i,                    // 访存请求
    input wire mem_reg_we_i,                 // 访存写使能
    input wire[4:0] mem_reg_waddr_i,         // 访存写地址
    input wire[31:0] mem_reg_wdata_i,        // 访存写数据

    input wire req_ext_i,                    // 扩展指令请求
    input wire ext_reg_we_i,                 // 扩展写使能
    input wire[4:0] ext_reg_waddr_i,         // 扩展写地址
    input wire[31:0] ext_reg_wdata_i,        // 扩展写数据

    input wire req_csr_i,                    // CSR请求(未使用)
    input wire csr_reg_we_i,                 // CSR写使能
    input wire[4:0] csr_reg_waddr_i,         // CSR写地址
    input wire[31:0] csr_reg_wdata_i,        // CSR写数据

    input wire req_bjp_i,                    // 分支/跳转请求
    input wire bjp_reg_we_i,                 // BJP写使能(link地址)
    input wire[31:0] bjp_reg_wdata_i,        // BJP写数据
    input wire[4:0] bjp_reg_waddr_i,         // BJP写地址

    input wire rd_we_i,                      // ALU写使能
    input wire[4:0] rd_waddr_i,              // ALU写地址
    input wire[31:0] alu_reg_wdata_i,        // ALU写数据

    output wire reg_we_o,                    // 最终写使能
    output wire[4:0] reg_waddr_o,            // 最终写地址
    output wire[31:0] reg_wdata_o            // 最终写数据

    );

    wire use_alu_res = (~req_muldiv_i) &
                       (~req_mem_i) &
                       (~req_ext_i) &
                       (~req_csr_i) &
                       (~req_bjp_i);

    assign reg_we_o = muldiv_reg_we_i | mem_reg_we_i | ext_reg_we_i | csr_reg_we_i | use_alu_res | bjp_reg_we_i;

    reg[4:0] reg_waddr;

    always @ (*) begin
        reg_waddr = 5'h0;
        case (1'b1)
            muldiv_reg_we_i: reg_waddr = muldiv_reg_waddr_i;
            mem_reg_we_i:    reg_waddr = mem_reg_waddr_i;
            ext_reg_we_i:    reg_waddr = ext_reg_waddr_i;
            csr_reg_we_i:    reg_waddr = csr_reg_waddr_i;
            bjp_reg_we_i:    reg_waddr = bjp_reg_waddr_i;
            rd_we_i:         reg_waddr = rd_waddr_i;
        endcase
    end

    assign reg_waddr_o = reg_waddr;

    reg[31:0] reg_wdata;

    always @ (*) begin
        reg_wdata = 32'h0;
        case (1'b1)
            muldiv_reg_we_i: reg_wdata = muldiv_reg_wdata_i;
            mem_reg_we_i:    reg_wdata = mem_reg_wdata_i;
            ext_reg_we_i:    reg_wdata = ext_reg_wdata_i;
            csr_reg_we_i:    reg_wdata = csr_reg_wdata_i;
            bjp_reg_we_i:    reg_wdata = bjp_reg_wdata_i;
            use_alu_res:     reg_wdata = alu_reg_wdata_i;
        endcase
    end

    assign reg_wdata_o = reg_wdata;

endmodule
