`include "../../core00_wzc/marcos.v"

module pwm(

    input wire clk,
    input wire rst_n,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,
    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,
    output wire[3:0] pwm_o

    );

    localparam REG_A0 = 8'h00;
    localparam REG_A1 = 8'h01;
    localparam REG_A2 = 8'h02;
    localparam REG_A3 = 8'h03;
    localparam REG_C  = 8'h04;
    localparam REG_B0 = 8'h10;
    localparam REG_B1 = 8'h11;
    localparam REG_B2 = 8'h12;
    localparam REG_B3 = 8'h13;

    reg[31:0] reg_a0;
    reg[31:0] reg_a1;
    reg[31:0] reg_a2;
    reg[31:0] reg_a3;
    reg[31:0] reg_b0;
    reg[31:0] reg_b1;
    reg[31:0] reg_b2;
    reg[31:0] reg_b3;
    reg[31:0] reg_c;

    reg[31:0] cnt0;
    reg[31:0] cnt1;
    reg[31:0] cnt2;
    reg[31:0] cnt3;
    reg[3:0] pwm_out_r;
    reg[31:0] read_data;

    wire req_hasked = req_valid_i & req_ready_o;

    assign pwm_o = pwm_out_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a0 <= 32'd0;
            reg_a1 <= 32'd0;
            reg_a2 <= 32'd0;
            reg_a3 <= 32'd0;
            reg_b0 <= 32'd0;
            reg_b1 <= 32'd0;
            reg_b2 <= 32'd0;
            reg_b3 <= 32'd0;
            reg_c <= 32'd0;
        end else if (req_hasked && we_i == 1'b1) begin
            case (addr_i[23:16])
                REG_A0: reg_a0 <= data_i;
                REG_A1: reg_a1 <= data_i;
                REG_A2: reg_a2 <= data_i;
                REG_A3: reg_a3 <= data_i;
                REG_C: reg_c <= data_i;
                REG_B0: reg_b0 <= data_i;
                REG_B1: reg_b1 <= data_i;
                REG_B2: reg_b2 <= data_i;
                REG_B3: reg_b3 <= data_i;
                default: begin
                end
            endcase
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt0 <= 32'd0;
            cnt1 <= 32'd0;
            cnt2 <= 32'd0;
            cnt3 <= 32'd0;
            pwm_out_r <= 4'b0000;
        end else begin
            if (reg_c[0] == 1'b1 && reg_a0 != 32'd0) begin
                if (cnt0 >= reg_a0 - 1'b1) begin
                    cnt0 <= 32'd0;
                end else begin
                    cnt0 <= cnt0 + 1'b1;
                end
                if (cnt0 < reg_b0) begin
                    pwm_out_r[0] <= 1'b1;
                end else begin
                    pwm_out_r[0] <= 1'b0;
                end
            end else begin
                cnt0 <= 32'd0;
                pwm_out_r[0] <= 1'b0;
            end

            if (reg_c[1] == 1'b1 && reg_a1 != 32'd0) begin
                if (cnt1 >= reg_a1 - 1'b1) begin
                    cnt1 <= 32'd0;
                end else begin
                    cnt1 <= cnt1 + 1'b1;
                end
                if (cnt1 < reg_b1) begin
                    pwm_out_r[1] <= 1'b1;
                end else begin
                    pwm_out_r[1] <= 1'b0;
                end
            end else begin
                cnt1 <= 32'd0;
                pwm_out_r[1] <= 1'b0;
            end

            if (reg_c[2] == 1'b1 && reg_a2 != 32'd0) begin
                if (cnt2 >= reg_a2 - 1'b1) begin
                    cnt2 <= 32'd0;
                end else begin
                    cnt2 <= cnt2 + 1'b1;
                end
                if (cnt2 < reg_b2) begin
                    pwm_out_r[2] <= 1'b1;
                end else begin
                    pwm_out_r[2] <= 1'b0;
                end
            end else begin
                cnt2 <= 32'd0;
                pwm_out_r[2] <= 1'b0;
            end

            if (reg_c[3] == 1'b1 && reg_a3 != 32'd0) begin
                if (cnt3 >= reg_a3 - 1'b1) begin
                    cnt3 <= 32'd0;
                end else begin
                    cnt3 <= cnt3 + 1'b1;
                end
                if (cnt3 < reg_b3) begin
                    pwm_out_r[3] <= 1'b1;
                end else begin
                    pwm_out_r[3] <= 1'b0;
                end
            end else begin
                cnt3 <= 32'd0;
                pwm_out_r[3] <= 1'b0;
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= 32'd0;
        end else if (req_hasked && !we_i) begin
            data_o <= read_data;
        end
    end

    always @ (*) begin
        case (addr_i[23:16])
            REG_A0: read_data = reg_a0;
            REG_A1: read_data = reg_a1;
            REG_A2: read_data = reg_a2;
            REG_A3: read_data = reg_a3;
            REG_C: read_data = reg_c;
            REG_B0: read_data = reg_b0;
            REG_B1: read_data = reg_b1;
            REG_B2: read_data = reg_b2;
            REG_B3: read_data = reg_b3;
            default: read_data = 32'd0;
        endcase
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
