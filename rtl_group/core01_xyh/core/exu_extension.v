`include "defines.v"

// 扩展指令统一调度入口模块
// 根据dec_info_bus判断当前是哪条扩展指令(sendid/readtemp/intfire)
// 给对应的扩展子模块发start信号
// 汇总各扩展子模块的总线请求、写回结果和stall信号
module exu_extension_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire mem_stall_i,                  // 外部暂停
    input wire[`DECINFO_WIDTH-1:0] dec_info_bus_i,  // 译码信息总线
    input wire[31:0] dec_imm_i,              // 立即数
    input wire[31:0] reg1_rdata_i,           // rs1寄存器数据(给intfire)
    input wire[31:0] reg2_rdata_i,           // rs2寄存器数据(给intfire作为x31值)
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    input wire[31:0] mem_rdata_i,            // 访存读数据

    output wire req_ext_o,                   // 扩展指令请求标志
    output wire ext_bus_req_o,               // 扩展总线请求
    output wire ext_bus_valid_o,             // 扩展总线请求有效
    output wire ext_bus_we_o,                // 扩展总线写使能
    output wire[31:0] ext_bus_addr_o,        // 扩展总线地址
    output wire[31:0] ext_bus_wdata_o,       // 扩展总线写数据
    output wire[3:0] ext_bus_sel_o,          // 扩展总线字节选择
    output wire[31:0] ext_reg_wdata_o,       // 扩展写回数据
    output wire ext_reg_we_o,                // 扩展写回使能
    output wire ext_stall_o                  // 扩展暂停

    );

    wire[`DECINFO_GRP_WIDTH-1:0] disp_info_grp = dec_info_bus_i[`DECINFO_GRP_BUS];
    wire op_ext = (disp_info_grp == `DECINFO_GRP_EXT);
    wire ext_op_readtemp = op_ext & (dec_info_bus_i[`DECINFO_EXT_READTEMP] == 1'b1);
    wire ext_op_sendid = op_ext & (dec_info_bus_i[`DECINFO_EXT_SENDID] == 1'b1);
    wire ext_op_intfire = op_ext & (dec_info_bus_i[`DECINFO_EXT_INTFIRE] == 1'b1);

    wire readtemp_ready;
    wire readtemp_bus_req;
    wire readtemp_bus_valid;
    wire readtemp_bus_we;
    wire[31:0] readtemp_bus_addr;
    wire[31:0] readtemp_bus_wdata;
    wire[3:0] readtemp_bus_sel;
    wire[31:0] readtemp_reg_wdata;
    wire readtemp_reg_we;
    wire readtemp_stall;
    wire readtemp_start = ext_op_readtemp & (~mem_stall_i);
    wire sendid_ready;
    wire sendid_bus_req;
    wire sendid_bus_valid;
    wire sendid_bus_we;
    wire[31:0] sendid_bus_addr;
    wire[31:0] sendid_bus_wdata;
    wire[3:0] sendid_bus_sel;
    wire[31:0] sendid_reg_wdata;
    wire sendid_reg_we;
    wire sendid_stall;
    wire sendid_start = ext_op_sendid & (~mem_stall_i);
    wire intfire_ready;
    wire intfire_bus_req;
    wire intfire_bus_valid;
    wire intfire_bus_we;
    wire[31:0] intfire_bus_addr;
    wire[31:0] intfire_bus_wdata;
    wire[3:0] intfire_bus_sel;
    wire[31:0] intfire_reg_wdata;
    wire intfire_reg_we;
    wire intfire_stall;
    wire intfire_start = ext_op_intfire & (~mem_stall_i);

    ext_readtemp_xyh u_ext_readtemp(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(readtemp_start),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .ready_o(readtemp_ready),
        .bus_req_o(readtemp_bus_req),
        .bus_valid_o(readtemp_bus_valid),
        .bus_we_o(readtemp_bus_we),
        .bus_addr_o(readtemp_bus_addr),
        .bus_wdata_o(readtemp_bus_wdata),
        .bus_sel_o(readtemp_bus_sel),
        .reg_wdata_o(readtemp_reg_wdata),
        .reg_we_o(readtemp_reg_we),
        .stall_o(readtemp_stall)
    );

    ext_sendid_xyh u_ext_sendid(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(sendid_start),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .ready_o(sendid_ready),
        .bus_req_o(sendid_bus_req),
        .bus_valid_o(sendid_bus_valid),
        .bus_we_o(sendid_bus_we),
        .bus_addr_o(sendid_bus_addr),
        .bus_wdata_o(sendid_bus_wdata),
        .bus_sel_o(sendid_bus_sel),
        .reg_wdata_o(sendid_reg_wdata),
        .reg_we_o(sendid_reg_we),
        .stall_o(sendid_stall)
    );

    ext_intfire_xyh u_ext_intfire(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(intfire_start),
        .rs1_data_i(reg1_rdata_i),
        .x31_data_i(reg2_rdata_i),
        .imm_i(dec_imm_i),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .ready_o(intfire_ready),
        .bus_req_o(intfire_bus_req),
        .bus_valid_o(intfire_bus_valid),
        .bus_we_o(intfire_bus_we),
        .bus_addr_o(intfire_bus_addr),
        .bus_wdata_o(intfire_bus_wdata),
        .bus_sel_o(intfire_bus_sel),
        .reg_wdata_o(intfire_reg_wdata),
        .reg_we_o(intfire_reg_we),
        .stall_o(intfire_stall)
    );

    assign req_ext_o = op_ext;
    assign ext_bus_req_o = (ext_op_readtemp & readtemp_bus_req) |
                           (ext_op_sendid & sendid_bus_req) |
                           (ext_op_intfire & intfire_bus_req);
    assign ext_bus_valid_o = (ext_op_readtemp & readtemp_bus_valid) |
                             (ext_op_sendid & sendid_bus_valid) |
                             (ext_op_intfire & intfire_bus_valid);
    assign ext_bus_we_o = ext_op_readtemp ? readtemp_bus_we :
                          ext_op_sendid ? sendid_bus_we :
                          ext_op_intfire ? intfire_bus_we :
                          1'b0;
    assign ext_bus_addr_o = ext_op_readtemp ? readtemp_bus_addr :
                            ext_op_sendid ? sendid_bus_addr :
                            ext_op_intfire ? intfire_bus_addr :
                            32'h0;
    assign ext_bus_wdata_o = ext_op_readtemp ? readtemp_bus_wdata :
                             ext_op_sendid ? sendid_bus_wdata :
                             ext_op_intfire ? intfire_bus_wdata :
                             32'h0;
    assign ext_bus_sel_o = ext_op_readtemp ? readtemp_bus_sel :
                           ext_op_sendid ? sendid_bus_sel :
                           ext_op_intfire ? intfire_bus_sel :
                           4'h0;
    assign ext_reg_wdata_o = (ext_op_readtemp & readtemp_reg_we) ? readtemp_reg_wdata :
                             (ext_op_sendid & sendid_reg_we) ? sendid_reg_wdata :
                             (ext_op_intfire & intfire_reg_we) ? intfire_reg_wdata :
                             32'h0;
    assign ext_reg_we_o = (ext_op_readtemp & readtemp_reg_we) |
                          (ext_op_sendid & sendid_reg_we) |
                          (ext_op_intfire & intfire_reg_we);
    assign ext_stall_o = (ext_op_readtemp & readtemp_stall) |
                         (ext_op_sendid & sendid_stall) |
                         (ext_op_intfire & intfire_stall);

endmodule
