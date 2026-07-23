`include "../core/defines.v"

// 片上互连总线模块(RIB)
// 多主多从共享总线架构，带固定优先级仲裁
// 4个Master：m0(IFU取指) / m1(EXU数据) / m2(未使用) / m3(uart_debug)
// 5个Slave：s0(外部ROM) / s1(外部RAM) / s2(UART) / s3(PWM) / s4(IIC)
// 仲裁优先级：m3 > m2 > m1 > m0(LSB优先级最高)
// 从设备译码基于地址高4位[31:28]
module rib #(
    parameter MASTER_NUM = 4,
    parameter SLAVE_NUM = 5)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    // priority: m3 > m2 > m1 > m0
    // Master 0 - IFU指令总线
    input wire[31:0] m0_addr_i,              // m0地址
    input wire[31:0] m0_data_i,              // m0写数据
    input wire[3:0] m0_sel_i,                // m0字节选择
    input wire m0_req_vld_i,                 // m0请求有效
    input wire m0_rsp_rdy_i,                 // m0响应就绪
    input wire m0_we_i,                      // m0写使能
    output wire m0_req_rdy_o,                // m0请求就绪
    output wire m0_rsp_vld_o,                // m0响应有效
    output wire[31:0] m0_data_o,             // m0读数据

    // Master 1 - EXU数据总线
    input wire[31:0] m1_addr_i,              // m1地址
    input wire[31:0] m1_data_i,              // m1写数据
    input wire[3:0] m1_sel_i,                // m1字节选择
    input wire m1_req_vld_i,                 // m1请求有效
    input wire m1_rsp_rdy_i,                 // m1响应就绪
    input wire m1_we_i,                      // m1写使能
    output wire m1_req_rdy_o,                // m1请求就绪
    output wire m1_rsp_vld_o,                // m1响应有效
    output wire[31:0] m1_data_o,             // m1读数据

    // Master 2 - 未使用(JTAG保留)
    input wire[31:0] m2_addr_i,              // m2地址(未使用)
    input wire[31:0] m2_data_i,              // m2写数据(未使用)
    input wire[3:0] m2_sel_i,                // m2字节选择(未使用)
    input wire m2_req_vld_i,                 // m2请求有效(恒为0)
    input wire m2_rsp_rdy_i,                 // m2响应就绪(恒为0)
    input wire m2_we_i,                      // m2写使能(恒为0)
    output wire m2_req_rdy_o,                // m2请求就绪
    output wire m2_rsp_vld_o,                // m2响应有效
    output wire[31:0] m2_data_o,             // m2读数据

    // Master 3 - uart_debug调试下载
    input wire[31:0] m3_addr_i,              // m3地址
    input wire[31:0] m3_data_i,              // m3写数据
    input wire[3:0] m3_sel_i,                // m3字节选择
    input wire m3_req_vld_i,                 // m3请求有效
    input wire m3_rsp_rdy_i,                 // m3响应就绪
    input wire m3_we_i,                      // m3写使能
    output wire m3_req_rdy_o,                // m3请求就绪
    output wire m3_rsp_vld_o,                // m3响应有效
    output wire[31:0] m3_data_o,             // m3读数据

    // Slave 0 - 外部ROM(基地址0x00000000)
    input wire[31:0] s0_data_i,              // s0读数据
    input wire s0_req_rdy_i,                 // s0请求就绪
    input wire s0_rsp_vld_i,                 // s0响应有效
    output wire[31:0] s0_addr_o,             // s0地址
    output wire[31:0] s0_data_o,             // s0写数据
    output wire[3:0] s0_sel_o,               // s0字节选择
    output wire s0_req_vld_o,                // s0请求有效
    output wire s0_rsp_rdy_o,                // s0响应就绪
    output wire s0_we_o,                     // s0写使能

    // Slave 1 - 外部RAM(基地址0x10000000)
    input wire[31:0] s1_data_i,              // s1读数据
    input wire s1_req_rdy_i,                 // s1请求就绪
    input wire s1_rsp_vld_i,                 // s1响应有效
    output wire[31:0] s1_addr_o,             // s1地址
    output wire[31:0] s1_data_o,             // s1写数据
    output wire[3:0] s1_sel_o,               // s1字节选择
    output wire s1_req_vld_o,                // s1请求有效
    output wire s1_rsp_rdy_o,                // s1响应就绪
    output wire s1_we_o,                     // s1写使能

    // Slave 2 - UART(基地址0x30000000)
    input wire[31:0] s2_data_i,              // s2读数据
    input wire s2_req_rdy_i,                 // s2请求就绪
    input wire s2_rsp_vld_i,                 // s2响应有效
    output wire[31:0] s2_addr_o,             // s2地址
    output wire[31:0] s2_data_o,             // s2写数据
    output wire[3:0] s2_sel_o,               // s2字节选择
    output wire s2_req_vld_o,                // s2请求有效
    output wire s2_rsp_rdy_o,                // s2响应就绪
    output wire s2_we_o,                     // s2写使能

    // Slave 3 - PWM(基地址0x60000000)
    input wire[31:0] s3_data_i,              // s3读数据
    input wire s3_req_rdy_i,                 // s3请求就绪
    input wire s3_rsp_vld_i,                 // s3响应有效
    output wire[31:0] s3_addr_o,             // s3地址
    output wire[31:0] s3_data_o,             // s3写数据
    output wire[3:0] s3_sel_o,               // s3字节选择
    output wire s3_req_vld_o,                // s3请求有效
    output wire s3_rsp_rdy_o,                // s3响应就绪
    output wire s3_we_o,                     // s3写使能

    // Slave 4 - IIC(基地址0x70000000)
    input wire[31:0] s4_data_i,              // s4读数据
    input wire s4_req_rdy_i,                 // s4请求就绪
    input wire s4_rsp_vld_i,                 // s4响应有效
    output wire[31:0] s4_addr_o,             // s4地址
    output wire[31:0] s4_data_o,             // s4写数据
    output wire[3:0] s4_sel_o,               // s4字节选择
    output wire s4_req_vld_o,                // s4请求有效
    output wire s4_rsp_rdy_o,                // s4响应就绪
    output wire s4_we_o                      // s4写使能

    );

    /////////////////////////////// mux master //////////////////////////////

    wire[MASTER_NUM-1:0] master_req;
    wire[31:0] master_addr[MASTER_NUM-1:0];
    wire[31:0] master_data[MASTER_NUM-1:0];
    wire[3:0] master_sel[MASTER_NUM-1:0];
    wire[MASTER_NUM-1:0] master_rsp_rdy;
    wire[MASTER_NUM-1:0] master_we;

    genvar i;
    generate

    if (MASTER_NUM == 2) begin: if_m_num_2
        assign master_req = {m0_req_vld_i, m1_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_2
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    if (MASTER_NUM == 3) begin: if_m_num_3
        assign master_req = {m0_req_vld_i, m1_req_vld_i, m2_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i, m2_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i, m2_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i, m2_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i, m2_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i, m2_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_3
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    if (MASTER_NUM == 4) begin: if_m_num_4
        assign master_req = {m0_req_vld_i, m1_req_vld_i, m2_req_vld_i, m3_req_vld_i};
        assign master_rsp_rdy = {m0_rsp_rdy_i, m1_rsp_rdy_i, m2_rsp_rdy_i, m3_rsp_rdy_i};
        assign master_we = {m0_we_i, m1_we_i, m2_we_i, m3_we_i};
        wire[32*MASTER_NUM-1:0] m_addr = {m0_addr_i, m1_addr_i, m2_addr_i, m3_addr_i};
        wire[32*MASTER_NUM-1:0] m_data = {m0_data_i, m1_data_i, m2_data_i, m3_data_i};
        wire[4*MASTER_NUM-1:0] m_sel = {m0_sel_i, m1_sel_i, m2_sel_i, m3_sel_i};
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: for_m_num_4
            assign master_addr[i] = m_addr[(i+1)*32-1:32*i];
            assign master_data[i] = m_data[(i+1)*32-1:32*i];
            assign master_sel[i] = m_sel[(i+1)*4-1:4*i];
        end
    end

    wire[MASTER_NUM-1:0] master_req_vec;
    wire[MASTER_NUM-1:0] master_sel_vec;

    // 优先级仲裁机制，LSB优先级最高，MSB优先级最低
    for (i = 0; i < MASTER_NUM; i = i + 1) begin: m_arb
        if (i == 0) begin: m_is_0
            assign master_req_vec[i] = 1'b1;
        end else begin: m_is_not_0
            assign master_req_vec[i] = ~(|master_req[i-1:0]);
        end
        assign master_sel_vec[i] = master_req_vec[i] & master_req[i];
    end

    reg[31:0] mux_m_addr;
    reg[31:0] mux_m_data;
    reg[3:0] mux_m_sel;
    reg mux_m_req_vld;
    reg mux_m_rsp_rdy;
    reg mux_m_we;

    integer j;

    always @ (*) begin: m_out
        mux_m_addr = 32'h0;
        mux_m_data = 32'h0;
        mux_m_sel = 4'h0;
        mux_m_req_vld = 1'b0;
        mux_m_rsp_rdy = 1'b0;
        mux_m_we = 1'b0;
        for (j = 0; j < MASTER_NUM; j = j + 1) begin: m_sig_out
            mux_m_addr    = mux_m_addr    | ({32{master_sel_vec[j]}} & master_addr[j]);
            mux_m_data    = mux_m_data    | ({32{master_sel_vec[j]}} & master_data[j]);
            mux_m_sel     = mux_m_sel     | ({4 {master_sel_vec[j]}} & master_sel[j]);
            mux_m_req_vld = mux_m_req_vld | ({1 {master_sel_vec[j]}} & master_req[j]);
            mux_m_rsp_rdy = mux_m_rsp_rdy | ({1 {master_sel_vec[j]}} & master_rsp_rdy[j]);
            mux_m_we      = mux_m_we      | ({1 {master_sel_vec[j]}} & master_we[j]);
        end
    end

    /////////////////////////////// mux slave /////////////////////////////////

    wire[SLAVE_NUM-1:0] slave_sel;

    // 访问地址的最高4位决定要访问的是哪一个从设备
    assign slave_sel[0] = (mux_m_addr[31:28] == `EXROM_BASE_ADDR >> 28);  // EXROM
    assign slave_sel[1] = (mux_m_addr[31:28] == `EXRAM_BASE_ADDR >> 28);  // EXRAM
    assign slave_sel[2] = (mux_m_addr[31:28] == `UART_BASE_ADDR >> 28);  // UART
    assign slave_sel[3] = (mux_m_addr[31:28] == `PWM_BASE_ADDR >> 28);  // PWM
    assign slave_sel[4] = (mux_m_addr[31:28] == `IIC_BASE_ADDR >> 28);  // IIC

    wire[SLAVE_NUM-1:0] slave_req_rdy;
    wire[SLAVE_NUM-1:0] slave_rsp_vld;
    wire[31:0] slave_data[SLAVE_NUM-1:0];

    if (SLAVE_NUM == 2) begin: if_s_num_2
        assign slave_req_rdy = {s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_2
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 3) begin: if_s_num_3
        assign slave_req_rdy = {s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_3
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 4) begin: if_s_num_4
        assign slave_req_rdy = {s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_4
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    if (SLAVE_NUM == 5) begin: if_s_num_5
        assign slave_req_rdy = {s4_req_rdy_i, s3_req_rdy_i, s2_req_rdy_i, s1_req_rdy_i, s0_req_rdy_i};
        assign slave_rsp_vld = {s4_rsp_vld_i, s3_rsp_vld_i, s2_rsp_vld_i, s1_rsp_vld_i, s0_rsp_vld_i};
        wire[32*SLAVE_NUM-1:0] s_data = {s4_data_i, s3_data_i, s2_data_i, s1_data_i, s0_data_i};
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: for_s_num_5
            assign slave_data[i] = s_data[(i+1)*32-1:32*i];
        end
    end

    reg[31:0] mux_s_data;
    reg mux_s_req_rdy;
    reg mux_s_rsp_vld;

    always @ (*) begin: s_out
        mux_s_data = 32'h0;
        mux_s_req_rdy = 1'b0;
        mux_s_rsp_vld = 1'b0;
        for (j = 0; j < SLAVE_NUM; j = j + 1) begin: s_sig_out
            mux_s_data    = mux_s_data    | ({32{slave_sel[j]}} & slave_data[j]);
            mux_s_req_rdy = mux_s_req_rdy | ({1 {slave_sel[j]}} & slave_req_rdy[j]);
            mux_s_rsp_vld = mux_s_rsp_vld | ({1 {slave_sel[j]}} & slave_rsp_vld[j]);
        end
    end

    /////////////////////////////// demux master //////////////////////////////

    wire[MASTER_NUM-1:0] demux_m_req_rdy;
    wire[MASTER_NUM-1:0] demux_m_rsp_vld;
    wire[32*MASTER_NUM-1:0] demux_m_data;

    for (i = 0; i < MASTER_NUM; i = i + 1) begin: demux_m_sig
        assign demux_m_req_rdy[i]            = {1 {master_sel_vec[i]}} & mux_s_req_rdy;
        assign demux_m_rsp_vld[i]            = {1 {master_sel_vec[i]}} & mux_s_rsp_vld;
        assign demux_m_data[(i+1)*32-1:32*i] = {32{master_sel_vec[i]}} & mux_s_data;
    end

    if (MASTER_NUM == 2) begin: demux_m_sig_2
        assign {m0_req_rdy_o, m1_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o} = demux_m_data;
    end

    if (MASTER_NUM == 3) begin: demux_m_sig_3
        assign {m0_req_rdy_o, m1_req_rdy_o, m2_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o, m2_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o, m2_data_o} = demux_m_data;
    end

    if (MASTER_NUM == 4) begin: demux_m_sig_4
        assign {m0_req_rdy_o, m1_req_rdy_o, m2_req_rdy_o, m3_req_rdy_o} = demux_m_req_rdy;
        assign {m0_rsp_vld_o, m1_rsp_vld_o, m2_rsp_vld_o, m3_rsp_vld_o} = demux_m_rsp_vld;
        assign {m0_data_o, m1_data_o, m2_data_o, m3_data_o} = demux_m_data;
    end

    /////////////////////////////// demux slave //////////////////////////////

    wire[32*SLAVE_NUM-1:0] demux_s_addr;
    wire[32*SLAVE_NUM-1:0] demux_s_data;
    wire[4*SLAVE_NUM-1:0] demux_s_sel;
    wire[SLAVE_NUM-1:0] demux_s_req_vld;
    wire[SLAVE_NUM-1:0] demux_s_rsp_rdy;
    wire[SLAVE_NUM-1:0] demux_s_we;

    for (i = 0; i < SLAVE_NUM; i = i + 1) begin: demux_s_sig
        // 去掉外设基地址，只保留offset
        assign demux_s_addr[(i+1)*32-1:32*i] = {32{slave_sel[i]}} & {4'h0, mux_m_addr[27:0]};
        assign demux_s_data[(i+1)*32-1:32*i] = {32{slave_sel[i]}} & mux_m_data;
        assign demux_s_sel[(i+1)*4-1:4*i]    = {4 {slave_sel[i]}} & mux_m_sel;
        assign demux_s_req_vld[i]            = {1 {slave_sel[i]}} & mux_m_req_vld;
        assign demux_s_rsp_rdy[i]            = {1 {slave_sel[i]}} & mux_m_rsp_rdy;
        assign demux_s_we[i]                 = {1 {slave_sel[i]}} & mux_m_we;
    end

    if (SLAVE_NUM == 2) begin: demux_s_sig_2
        assign {s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s1_data_o, s0_data_o} = demux_s_data;
        assign {s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 3) begin: demux_s_sig_3
        assign {s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 4) begin: demux_s_sig_4
        assign {s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    if (SLAVE_NUM == 5) begin: demux_s_sig_5
        assign {s4_addr_o, s3_addr_o, s2_addr_o, s1_addr_o, s0_addr_o} = demux_s_addr;
        assign {s4_data_o, s3_data_o, s2_data_o, s1_data_o, s0_data_o} = demux_s_data;
        assign {s4_sel_o, s3_sel_o, s2_sel_o, s1_sel_o, s0_sel_o} = demux_s_sel;
        assign {s4_req_vld_o, s3_req_vld_o, s2_req_vld_o, s1_req_vld_o, s0_req_vld_o} = demux_s_req_vld;
        assign {s4_rsp_rdy_o, s3_rsp_rdy_o, s2_rsp_rdy_o, s1_rsp_rdy_o, s0_rsp_rdy_o} = demux_s_rsp_rdy;
        assign {s4_we_o, s3_we_o, s2_we_o, s1_we_o, s0_we_o} = demux_s_we;
    end

    endgenerate


endmodule
