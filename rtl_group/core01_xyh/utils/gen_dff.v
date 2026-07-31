`timescale 1ns / 1ps

// 带默认值和控制信号的流水线触发器
// hold_en有效时加载默认值，否则正常锁存输入
module gen_pipe_dff_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire hold_en,                      // 保持使能(有效时加载默认值)

    input wire[DW-1:0] def_val,              // 默认值
    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n | hold_en) begin
            qout_r <= def_val;
        end else begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 复位后输出为0的触发器
module gen_rst_0_dff_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据(复位为0)

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qout_r <= {DW{1'b0}};
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 复位后输出为1的触发器
module gen_rst_1_dff_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据(复位为1)

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qout_r <= {DW{1'b1}};
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 复位后输出为默认值的触发器
module gen_rst_def_dff_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire[DW-1:0] def_val,              // 默认值

    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据(复位为def_val)

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qout_r <= def_val;
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 带使能端、复位后输出为0的触发器
module gen_en_dff_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire en,                           // 使能
    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据(使能时更新)

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qout_r <= {DW{1'b0}};
        end else if (en == 1'b1) begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 带使能端、没有复位的触发器(用于寄存器堆)
module gen_en_dffnr_xyh #(
    parameter DW = 32)(

    input wire clk,                          // 时钟

    input wire en,                           // 使能
    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] qout                 // 输出数据(使能时更新，无复位)

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (en == 1'b1) begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule
