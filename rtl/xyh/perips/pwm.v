`include "../core/defines.v"

// 4路PWM外设模块
// A[n](0x600n_0000)：周期寄存器(时钟周期数)
// B[n](0x601n_0000)：高电平宽度寄存器
// C   (0x604_0000)：通道使能寄存器
// 每个通道：使能且A!=0时，cnt<B输出高，否则输出低
module pwm(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire[31:0] addr_i,                 // 寄存器地址
    input wire[31:0] data_i,                 // 写数据
    input wire[3:0] sel_i,                   // 字节选择
    input wire we_i,                         // 写使能
    output wire[31:0] data_o,                // 读数据

    input wire req_valid_i,                  // 请求有效
    output wire req_ready_o,                 // 请求就绪
    output wire rsp_valid_o,                 // 响应有效
    input wire rsp_ready_i,                  // 响应就绪

    output wire[3:0] pwm_o                   // 4路PWM输出

    );

    localparam REG_A0 = 28'h0000000;
    localparam REG_A1 = 28'h0010000;
    localparam REG_A2 = 28'h0020000;
    localparam REG_A3 = 28'h0030000;
    localparam REG_C  = 28'h0040000;
    localparam REG_B0 = 28'h0100000;
    localparam REG_B1 = 28'h0110000;
    localparam REG_B2 = 28'h0120000;
    localparam REG_B3 = 28'h0130000;

    reg[31:0] reg_a[0:3];
    reg[31:0] reg_b[0:3];
    reg[31:0] reg_c;
    reg[31:0] cnt[0:3];
    reg[31:0] data_r;

    wire[27:0] reg_addr = addr_i[27:0];
    wire req_fire = req_valid_i & req_ready_o;
    wire wen = req_fire & we_i;
    wire ren = req_fire & (~we_i);

    assign pwm_o[0] = reg_c[0] & (reg_a[0] != 32'h0) & (cnt[0] < reg_b[0]);
    assign pwm_o[1] = reg_c[1] & (reg_a[1] != 32'h0) & (cnt[1] < reg_b[1]);
    assign pwm_o[2] = reg_c[2] & (reg_a[2] != 32'h0) & (cnt[2] < reg_b[2]);
    assign pwm_o[3] = reg_c[3] & (reg_a[3] != 32'h0) & (cnt[3] < reg_b[3]);
    assign data_o = data_r;

    integer i;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) begin
                reg_a[i] <= 32'h0;
                reg_b[i] <= 32'h0;
                cnt[i] <= 32'h0;
            end
            reg_c <= 32'h0;
        end else begin
            if (wen) begin
                case (reg_addr)
                    REG_A0: reg_a[0] <= data_i;
                    REG_A1: reg_a[1] <= data_i;
                    REG_A2: reg_a[2] <= data_i;
                    REG_A3: reg_a[3] <= data_i;
                    REG_B0: reg_b[0] <= data_i;
                    REG_B1: reg_b[1] <= data_i;
                    REG_B2: reg_b[2] <= data_i;
                    REG_B3: reg_b[3] <= data_i;
                    REG_C:  reg_c <= data_i;
                    default: begin

                    end
                endcase
            end

            for (i = 0; i < 4; i = i + 1) begin
                if ((reg_c[i] == 1'b0) || (reg_a[i] == 32'h0)) begin
                    cnt[i] <= 32'h0;
                end else if (cnt[i] >= (reg_a[i] - 1'b1)) begin
                    cnt[i] <= 32'h0;
                end else begin
                    cnt[i] <= cnt[i] + 1'b1;
                end
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_r <= 32'h0;
        end else if (ren) begin
            case (reg_addr)
                REG_A0: data_r <= reg_a[0];
                REG_A1: data_r <= reg_a[1];
                REG_A2: data_r <= reg_a[2];
                REG_A3: data_r <= reg_a[3];
                REG_B0: data_r <= reg_b[0];
                REG_B1: data_r <= reg_b[1];
                REG_B2: data_r <= reg_b[2];
                REG_B3: data_r <= reg_b[3];
                REG_C:  data_r <= reg_c;
                default: data_r <= 32'h0;
            endcase
        end else begin
            data_r <= 32'h0;
        end
    end

    vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst_n),
        .vld_i(req_valid_i),
        .rdy_o(req_ready_o),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

endmodule
