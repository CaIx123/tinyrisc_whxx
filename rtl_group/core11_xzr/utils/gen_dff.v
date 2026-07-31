`timescale 1ns / 1ps

module gen_pipe_dff_xzr #(
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

// 澶嶄綅鍚庤緭鍑轰负0鐨勮Е鍙戝櫒
module gen_rst_0_dff_xzr #(
    parameter DW = 32)(

    input wire clk,
    input wire rst,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst) begin
            qout_r <= {DW{1'b0}};
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 澶嶄綅鍚庤緭鍑轰负1鐨勮Е鍙戝櫒
module gen_rst_1_dff_xzr #(
    parameter DW = 32)(

    input wire clk,
    input wire rst,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst) begin
            qout_r <= {DW{1'b1}};
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 澶嶄綅鍚庤緭鍑轰负榛樿鍊肩殑瑙﹀彂鍣?
module gen_rst_def_dff_xzr #(
    parameter DW = 32)(

    input wire clk,
    input wire rst,
    input wire[DW-1:0] def_val,

    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst) begin
            qout_r <= def_val;
        end else begin                  
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule

// 甯︿娇鑳界銆佸浣嶅悗杈撳嚭涓?0鐨勮Е鍙戝櫒
module gen_en_dff_xzr #(
    parameter DW = 32)(

    input wire clk,
    input wire rst,

    input wire en,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout

    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst) begin
            qout_r <= {DW{1'b0}};
        end else if (en == 1'b1) begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule
