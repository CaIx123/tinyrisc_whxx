module PWM(

    input wire clk,
    input wire rst_n,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire[3:0] sel_i,

    output reg[31:0] data_o,
    output wire[3:0] PWM_out_pin,

    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i

    );

    localparam PAGE_A0 = 8'h00;
    localparam PAGE_A1 = 8'h01;
    localparam PAGE_A2 = 8'h02;
    localparam PAGE_A3 = 8'h03;
    localparam PAGE_C  = 8'h04;
    localparam PAGE_B0 = 8'h10;
    localparam PAGE_B1 = 8'h11;
    localparam PAGE_B2 = 8'h12;
    localparam PAGE_B3 = 8'h13;

    reg[31:0] pwm_a0;
    reg[31:0] pwm_a1;
    reg[31:0] pwm_a2;
    reg[31:0] pwm_a3;
    reg[31:0] pwm_b0;
    reg[31:0] pwm_b1;
    reg[31:0] pwm_b2;
    reg[31:0] pwm_b3;
    reg[31:0] pwm_c;

    reg[31:0] cnt0;
    reg[31:0] cnt1;
    reg[31:0] cnt2;
    reg[31:0] cnt3;

    wire ch0_en;
    wire ch1_en;
    wire ch2_en;
    wire ch3_en;

    wire req_fire = req_valid_i & req_ready_o;
    wire[27:0] req_addr = addr_i[27:0];
    wire[7:0] req_page = req_addr[23:16];
    wire req_addr_valid = (req_addr[27:24] == 4'h0) & (req_addr[15:0] == 16'h0000);

    reg req_fire_r;
    reg req_we_r;
    reg req_addr_valid_r;
    reg[7:0] req_page_r;
    reg[31:0] req_data_r;
    reg[3:0] req_sel_r;

    wire wen = req_fire_r & req_we_r & req_addr_valid_r;

    assign ch0_en = pwm_c[0];
    assign ch1_en = pwm_c[1];
    assign ch2_en = pwm_c[2];
    assign ch3_en = pwm_c[3];

    assign PWM_out_pin[0] = (ch0_en && (pwm_a0 != 32'h0) && (cnt0 < pwm_b0)) ? 1'b1 : 1'b0;
    assign PWM_out_pin[1] = (ch1_en && (pwm_a1 != 32'h0) && (cnt1 < pwm_b1)) ? 1'b1 : 1'b0;
    assign PWM_out_pin[2] = (ch2_en && (pwm_a2 != 32'h0) && (cnt2 < pwm_b2)) ? 1'b1 : 1'b0;
    assign PWM_out_pin[3] = (ch3_en && (pwm_a3 != 32'h0) && (cnt3 < pwm_b3)) ? 1'b1 : 1'b0;

    function[31:0] apply_wstrb;
        input[31:0] old_data;
        input[31:0] new_data;
        input[3:0] sel;
        begin
            apply_wstrb[7:0]   = sel[0] ? new_data[7:0]   : old_data[7:0];
            apply_wstrb[15:8]  = sel[1] ? new_data[15:8]  : old_data[15:8];
            apply_wstrb[23:16] = sel[2] ? new_data[23:16] : old_data[23:16];
            apply_wstrb[31:24] = sel[3] ? new_data[31:24] : old_data[31:24];
        end
    endfunction

    reg[31:0] req_read_data;

    always @ (*) begin
        req_read_data = 32'h0;
        if (req_addr_valid) begin
            case (req_page)
                PAGE_A0: req_read_data = pwm_a0;
                PAGE_A1: req_read_data = pwm_a1;
                PAGE_A2: req_read_data = pwm_a2;
                PAGE_A3: req_read_data = pwm_a3;
                PAGE_C:  req_read_data = pwm_c;
                PAGE_B0: req_read_data = pwm_b0;
                PAGE_B1: req_read_data = pwm_b1;
                PAGE_B2: req_read_data = pwm_b2;
                PAGE_B3: req_read_data = pwm_b3;
                default: req_read_data = 32'h0;
            endcase
        end
    end

    always @ (posedge clk) begin
        if (!rst_n) begin
            req_fire_r <= 1'b0;
            req_we_r <= 1'b0;
            req_addr_valid_r <= 1'b0;
            req_page_r <= 8'h0;
            req_data_r <= 32'h0;
            req_sel_r <= 4'h0;
            data_o <= 32'h0;
        end else begin
            req_fire_r <= req_fire;
            if (req_fire) begin
                req_we_r <= we_i;
                req_addr_valid_r <= req_addr_valid;
                req_page_r <= req_page;
                req_data_r <= data_i;
                req_sel_r <= sel_i;
                data_o <= req_read_data;
            end
        end
    end

    always @ (posedge clk) begin
        if (!rst_n) begin
            pwm_a0 <= 32'h0;
            pwm_a1 <= 32'h0;
            pwm_a2 <= 32'h0;
            pwm_a3 <= 32'h0;
            pwm_b0 <= 32'h0;
            pwm_b1 <= 32'h0;
            pwm_b2 <= 32'h0;
            pwm_b3 <= 32'h0;
            pwm_c <= 32'h0;
        end else if (wen) begin
            case (req_page_r)
                PAGE_A0: pwm_a0 <= apply_wstrb(pwm_a0, req_data_r, req_sel_r);
                PAGE_A1: pwm_a1 <= apply_wstrb(pwm_a1, req_data_r, req_sel_r);
                PAGE_A2: pwm_a2 <= apply_wstrb(pwm_a2, req_data_r, req_sel_r);
                PAGE_A3: pwm_a3 <= apply_wstrb(pwm_a3, req_data_r, req_sel_r);
                PAGE_C:  pwm_c  <= apply_wstrb(pwm_c,  req_data_r, req_sel_r);
                PAGE_B0: pwm_b0 <= apply_wstrb(pwm_b0, req_data_r, req_sel_r);
                PAGE_B1: pwm_b1 <= apply_wstrb(pwm_b1, req_data_r, req_sel_r);
                PAGE_B2: pwm_b2 <= apply_wstrb(pwm_b2, req_data_r, req_sel_r);
                PAGE_B3: pwm_b3 <= apply_wstrb(pwm_b3, req_data_r, req_sel_r);
                default: begin
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (!rst_n) begin
            cnt0 <= 32'h0;
            cnt1 <= 32'h0;
            cnt2 <= 32'h0;
            cnt3 <= 32'h0;
        end else begin
            if (!ch0_en || (pwm_a0 == 32'h0)) begin
                cnt0 <= 32'h0;
            end else if ((cnt0 + 1'b1) >= pwm_a0) begin
                cnt0 <= 32'h0;
            end else begin
                cnt0 <= cnt0 + 1'b1;
            end

            if (!ch1_en || (pwm_a1 == 32'h0)) begin
                cnt1 <= 32'h0;
            end else if ((cnt1 + 1'b1) >= pwm_a1) begin
                cnt1 <= 32'h0;
            end else begin
                cnt1 <= cnt1 + 1'b1;
            end

            if (!ch2_en || (pwm_a2 == 32'h0)) begin
                cnt2 <= 32'h0;
            end else if ((cnt2 + 1'b1) >= pwm_a2) begin
                cnt2 <= 32'h0;
            end else begin
                cnt2 <= cnt2 + 1'b1;
            end

            if (!ch3_en || (pwm_a3 == 32'h0)) begin
                cnt3 <= 32'h0;
            end else if ((cnt3 + 1'b1) >= pwm_a3) begin
                cnt3 <= 32'h0;
            end else begin
                cnt3 <= cnt3 + 1'b1;
            end
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
