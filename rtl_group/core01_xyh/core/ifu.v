`include "../../top/macros.v"

// 取指模块(Instruction Fetch Unit)
// 负责PC管理和指令读取：当未复位、未停机、未flush时产生ibus请求
// PC在请求握手成功时前进(加4)，而非在响应返回时
// req_not_rsp_reg用于跟踪请求已发出但响应未返回的状态，产生stall_o
// 支持复位跳转(pc_rst_i)、分支跳转(flush_i/flush_addr_i)和暂停(stall_i)
module ifu_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire pc_rst_i,                     // PC复位到CPU_RESET_ADDR
    input wire flush_i,                      // 流水线冲刷(分支跳转时清空)
    input wire[31:0] flush_addr_i,           // 跳转目标地址
    input wire[`XYH_STALL_WIDTH-1:0] stall_i,    // 流水线暂停标志
    input wire jtag_halt_i,                  // JTAG停机(暂停取指)

    output wire[31:0] inst_o,                // 取回的指令
    output wire[31:0] pc_o,                  // 当前指令PC(锁存的请求地址)
    output wire inst_valid_o,                // 指令有效
    output wire stall_o,                     // 取指暂停(请求已发出但响应未返回)

    output wire[31:0] ibus_addr_o,           // 指令总线地址
    input wire[31:0] ibus_data_i,            // 指令总线读数据
    output wire[31:0] ibus_data_o,           // 指令总线写数据(恒为0)
    output wire[3:0] ibus_sel_o,             // 指令总线字节选择(恒为1111)
    output wire ibus_we_o,                   // 指令总线写使能(恒为0)
    output wire req_valid_o,                 // 取指请求有效
    input wire req_ready_i,                  // 取指请求就绪
    input wire rsp_valid_i,                  // 取指响应有效
    output wire rsp_ready_o                  // 取指响应就绪

    );

    assign req_valid_o = (~rst_n)? 1'b0:
                         (pc_rst_i)? 1'b0:
                         (flush_i)? 1'b0:
                         stall_i[`XYH_STALL_PC]? 1'b0:
                         jtag_halt_i? 1'b0:
                         1'b1;
    assign rsp_ready_o = (~rst_n)? 1'b0: 1'b1;

    wire ifu_req_hsked = (req_valid_o & req_ready_i);
    wire ifu_rsp_hsked = (rsp_valid_i & rsp_ready_o);

    reg[31:0] pc;
    // reg[31:0] pc_prev;

    always @ (posedge clk or negedge rst_n) begin
        // 复位
        if (!rst_n) begin
            pc <= `CPU_RESET_ADDR;
            // pc_prev <= 32'h0;
        // 冲刷
        end else if (pc_rst_i | jtag_halt_i) begin
            pc <= `CPU_RESET_ADDR;
        end else if (flush_i) begin
            pc <= flush_addr_i;
        // 暂停，取上一条指令
        end 
        else if(ifu_req_hsked) begin
            pc <= pc + 32'h4;
            // pc_prev <= pc;
        end
    end

    // 将PC打一拍

    reg[31:0] req_pc_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_pc_r <= `CPU_RESET_ADDR;
        end else if (pc_rst_i) begin
            req_pc_r <= `CPU_RESET_ADDR;
        end else if (ifu_req_hsked) begin
            req_pc_r <= pc;
        end
    end

    wire[31:0] rsp_pc = req_pc_r;
    
    wire inst_valid ;
/////////////////////////////
    reg [31:0] inst_reg;
    wire req_not_rsp; reg req_not_rsp_reg;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_not_rsp_reg <= 1'b0;
            inst_reg <= `INST_NOP;
        end else if (pc_rst_i) begin
            req_not_rsp_reg <= 1'b0;
            inst_reg <= `INST_NOP;
        end else begin
            if(ifu_req_hsked & (~ifu_rsp_hsked)) begin
                req_not_rsp_reg <= 1'b1;
            end else if((~ifu_req_hsked) & ifu_rsp_hsked) begin
                req_not_rsp_reg <= 1'b0;
            end 
            if(inst_valid) begin
                inst_reg <= ibus_data_i;
            end
        end
    end
    assign req_not_rsp = req_not_rsp_reg;
    assign stall_o = req_not_rsp;
//////////////////////////////

    // 取指地址
    assign ibus_addr_o = pc;
    assign pc_o = rsp_pc;
    assign inst_valid = ifu_rsp_hsked & (~flush_i);
    assign inst_valid_o = inst_valid;
    assign inst_o = inst_valid? ibus_data_i: `INST_NOP;

    assign ibus_sel_o = 4'b1111;
    assign ibus_we_o = 1'b0;
    assign ibus_data_o = 32'h0;

endmodule
