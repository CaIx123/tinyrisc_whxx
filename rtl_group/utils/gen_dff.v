`timescale 1ns / 1ps

module gen_pipe_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst_n,
    input wire hold_en,

    input wire[DW-1:0] def_val,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

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

module gen_rst_0_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst_n,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

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

module gen_rst_1_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst_n,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

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

module gen_rst_def_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst_n,
    input wire[DW-1:0] def_val,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

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

module gen_en_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst_n,

    input wire en,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

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

module gen_en_dffnr #(
    parameter DW = 32)(

    input wire clk,

    input wire en,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (en == 1'b1) begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule


module gen_pipe_flush_dff #(
    parameter DW = 32)(

    input wire clk,
    input wire rst,
    input wire hold_en,
    input wire flush_en,          // [新增] 冲刷使能

    input wire[DW-1:0] def_val,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout
    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst | flush_en) begin
            qout_r <= def_val;    // 冲刷或复位时，输出 NOP
        end else if (hold_en) begin
            qout_r <= qout_r;     // [关键修复] 暂停时，真正地锁住当前值！
        end else begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule
