`include "../core/defines.v"

module IIC(

    input wire clk,
    input wire rst_n,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire[3:0] sel_i,
    output reg[31:0] data_o,

    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,

    inout SDA,
    output wire SCL

    );

    // CTRL/STATUS:
    //   write bit[4] = 1: start one-byte write transaction
    //   write bit[5] = 1: start one-byte read transaction
    //   write bit[6] = 1: clear done
    //   write bit[7] = 1: start two-byte read transaction
    //   read  bit[0]: busy
    //   read  bit[1]: done
    //   read  bit[2]: address NACK flag
    //   read  bit[3]: data NACK flag
    localparam IIC_CTRL   = 28'h000_0000;
    localparam SLAVE_ADDR_REG = 28'h001_0000;
    localparam IIC_OUTPUT_REG = 28'h002_0000;
    localparam IIC_INPUT_REG  = 28'h003_0000;

    localparam IIC_FREQ_HZ = 100000;
    localparam SCL_HALF_DIV = `CPU_CLOCK_HZ / (IIC_FREQ_HZ * 2);

    localparam ST_IDLE       = 5'd0;
    localparam ST_START_A    = 5'd1;
    localparam ST_START_B    = 5'd2;
    localparam ST_START_C    = 5'd3;
    localparam ST_SEND_LOW   = 5'd4;
    localparam ST_SEND_HIGH  = 5'd5;
    localparam ST_ACK_LOW    = 5'd6;
    localparam ST_ACK_HIGH   = 5'd7;
    localparam ST_READ_LOW   = 5'd8;
    localparam ST_READ_HIGH  = 5'd9;
    localparam ST_NACK_LOW   = 5'd10;
    localparam ST_NACK_HIGH  = 5'd11;
    localparam ST_STOP_LOW   = 5'd12;
    localparam ST_STOP_HIGH  = 5'd13;
    localparam ST_STOP_DONE  = 5'd14;
    localparam ST_MACK_LOW   = 5'd15;
    localparam ST_MACK_HIGH  = 5'd16;

    localparam OP_WRITE = 1'b0;
    localparam OP_READ  = 1'b1;

    reg[31:0] slave_addr_reg;
    reg[31:0] iic_output_reg;
    reg[31:0] iic_input_reg;
    reg iic_done;

    reg[4:0] state;
    reg[15:0] clk_cnt;
    reg sda_drive_low;
    reg op_r;
    reg[7:0] tx_shift;
    reg[7:0] rx_shift;
    reg[2:0] bit_cnt;
    reg byte_idx;
    reg read_two_bytes;
    reg ack_addr;
    reg ack_data;

    //------------------ SDA 输入同步器（禁止放入 IOB）-----------------
    (* IOB = "FALSE" *) reg sda_sync1;
    (* IOB = "FALSE" *) reg sda_sync2;
    wire sda_synced = sda_sync2;

    //------------------ SCL / SDA 输出寄存器（强制放入 IOB）-----------------
    (* IOB = "TRUE" *) reg scl_out;
    (* IOB = "TRUE" *) reg sda_out;   // 始终为 0，因为我们只驱动低电平
    (* IOB = "TRUE" *) reg sda_oe;    // 输出使能：1 表示驱动（将 SDA 拉低），0 表示高阻

    wire[27:0] reg_addr = addr_i[27:0];
    wire bus_hsk = req_valid_i & req_ready_o;
    wire wen = bus_hsk & we_i;
    wire start_write = wen & sel_i[0] & (reg_addr == IIC_CTRL) & data_i[4] & (state == ST_IDLE);
    wire start_read = wen & sel_i[0] & (reg_addr == IIC_CTRL) & data_i[5] & (state == ST_IDLE);
    wire clear_done = wen & sel_i[0] & (reg_addr == IIC_CTRL) & data_i[6];
    wire start_read2 = wen & sel_i[0] & (reg_addr == IIC_CTRL) & data_i[7] & (state == ST_IDLE);
    wire iic_busy = (state != ST_IDLE);
    wire tick = (clk_cnt == (SCL_HALF_DIV - 1));
    wire[7:0] addr_wr_byte = {slave_addr_reg[6:0], 1'b0};
    wire[7:0] addr_rd_byte = {slave_addr_reg[6:0], 1'b1};

    // SCL 和 SDA 现在由寄存器驱动，而不是组合逻辑
    assign SCL = scl_out;
    assign SDA = sda_oe ? 1'b0 : 1'bz;

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= 32'h0;
        end else if (bus_hsk & (~we_i)) begin
            case (reg_addr)
                IIC_CTRL:       data_o <= {28'h0, ack_data, ack_addr, iic_done, iic_busy};
                SLAVE_ADDR_REG: data_o <= slave_addr_reg;
                IIC_OUTPUT_REG: data_o <= iic_output_reg;
                IIC_INPUT_REG:  data_o <= iic_input_reg;
                default:        data_o <= 32'h0;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_addr_reg <= 32'h0;
            iic_output_reg <= 32'h0;
        end else if (wen) begin
            case (reg_addr)
                SLAVE_ADDR_REG: slave_addr_reg <= apply_wstrb(slave_addr_reg, data_i, sel_i);
                IIC_OUTPUT_REG: iic_output_reg <= apply_wstrb(iic_output_reg, data_i, sel_i);
                default: begin
                end
            endcase
        end
    end

    // 原来的状态机，我们保留 sda_drive_low 作为内部逻辑信号，
    // 但不再用它直接驱动 SDA；取而代之，在另一个 always 块中产生 IOB 寄存器。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            clk_cnt <= 16'h0;
            sda_drive_low <= 1'b0;
            op_r <= OP_WRITE;
            tx_shift <= 8'h0;
            rx_shift <= 8'h0;
            bit_cnt <= 3'h7;
            byte_idx <= 1'b0;
            read_two_bytes <= 1'b0;
            ack_addr <= 1'b1;
            ack_data <= 1'b1;
            iic_input_reg <= 32'h0;
            iic_done <= 1'b0;
        end else begin
            if (clear_done) begin
                iic_done <= 1'b0;
            end
            if (state == ST_IDLE) begin
                clk_cnt <= 16'h0;
                sda_drive_low <= 1'b0;
                if (start_write || start_read || start_read2) begin
                    op_r <= (start_read || start_read2) ? OP_READ : OP_WRITE;
                    tx_shift <= (start_read || start_read2) ? addr_rd_byte : addr_wr_byte;
                    bit_cnt <= 3'h7;
                    byte_idx <= 1'b0;
                    read_two_bytes <= start_read2;
                    ack_addr <= 1'b0;
                    ack_data <= 1'b0;
                    iic_done <= 1'b0;
                    state <= ST_START_A;
                end
            end else if (tick) begin
                clk_cnt <= 16'h0;
                case (state)
                    ST_START_A: begin
                        sda_drive_low <= 1'b1;
                        state <= ST_START_B;
                    end
                    ST_START_B: begin
                        state <= ST_START_C;
                    end
                    ST_START_C: begin
                        sda_drive_low <= ~tx_shift[bit_cnt];
                        state <= ST_SEND_LOW;
                    end
                    ST_SEND_LOW: begin
                        state <= ST_SEND_HIGH;
                    end
                    ST_SEND_HIGH: begin
                        if (bit_cnt == 3'h0) begin
                            sda_drive_low <= 1'b0;
                            state <= ST_ACK_LOW;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            sda_drive_low <= ~tx_shift[bit_cnt - 1'b1];
                            state <= ST_SEND_LOW;
                        end
                    end
                    ST_ACK_LOW: begin
                        state <= ST_ACK_HIGH;
                    end
                    ST_ACK_HIGH: begin
                        // 使用同步后的 SDA 信号
                        if (byte_idx == 1'b0) begin
                            ack_addr <= sda_synced;
                        end else begin
                            ack_data <= sda_synced;
                        end

                        if (op_r == OP_WRITE && byte_idx == 1'b0) begin
                            tx_shift <= iic_output_reg[7:0];
                            bit_cnt <= 3'h7;
                            byte_idx <= 1'b1;
                            sda_drive_low <= ~iic_output_reg[7];
                            state <= ST_SEND_LOW;
                        end else if (op_r == OP_READ) begin
                            bit_cnt <= 3'h7;
                            byte_idx <= 1'b0;
                            sda_drive_low <= 1'b0;
                            state <= ST_READ_LOW;
                        end else begin
                            sda_drive_low <= 1'b1;
                            state <= ST_STOP_LOW;
                        end
                    end
                    ST_READ_LOW: begin
                        state <= ST_READ_HIGH;
                    end
                    ST_READ_HIGH: begin
                        rx_shift[bit_cnt] <= sda_synced;
                        if (bit_cnt == 3'h0) begin
                            if (read_two_bytes && byte_idx == 1'b0) begin
                                sda_drive_low <= 1'b1;
                                state <= ST_MACK_LOW;
                            end else begin
                                sda_drive_low <= 1'b0;
                                state <= ST_NACK_LOW;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            sda_drive_low <= 1'b0;
                            state <= ST_READ_LOW;
                        end
                    end
                    ST_MACK_LOW: begin
                        state <= ST_MACK_HIGH;
                    end
                    ST_MACK_HIGH: begin
                        iic_input_reg[15:8] <= rx_shift;
                        bit_cnt <= 3'h7;
                        byte_idx <= 1'b1;
                        sda_drive_low <= 1'b0;
                        state <= ST_READ_LOW;
                    end
                    ST_NACK_LOW: begin
                        state <= ST_NACK_HIGH;
                    end
                    ST_NACK_HIGH: begin
                        if (read_two_bytes) begin
                            iic_input_reg <= {16'h0, iic_input_reg[15:8], rx_shift};
                        end else begin
                            iic_input_reg <= {24'h0, rx_shift};
                        end
                        sda_drive_low <= 1'b1;
                        state <= ST_STOP_LOW;
                    end
                    ST_STOP_LOW: begin
                        state <= ST_STOP_HIGH;
                    end
                    ST_STOP_HIGH: begin
                        state <= ST_STOP_DONE;
                    end
                    ST_STOP_DONE: begin
                        sda_drive_low <= 1'b0;
                        iic_done <= 1'b1;
                        state <= ST_IDLE;
                    end
                    default: begin
                        state <= ST_IDLE;
                    end
                endcase
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end

    // SDA 输入两级同步器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_sync1 <= 1'b1;
            sda_sync2 <= 1'b1;
        end else begin
            sda_sync1 <= SDA;
            sda_sync2 <= sda_sync1;
        end
    end

    //---------- IOB 输出寄存器的驱动 ----------
    // 使用与状态机相同的 tick 时刻进行更新，保证输出边沿与状态转移完全对齐
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_out <= 1'b1;
            sda_out <= 1'b0;
            sda_oe  <= 1'b0;
        end else if (state == ST_IDLE) begin
            // 空闲时 SCL 为高，SDA 不驱动（高阻）
            scl_out <= 1'b1;
            sda_out <= 1'b0;
            sda_oe  <= 1'b0;
        end else if (tick) begin
            // SCL 逻辑：原组合逻辑的直接寄存器化
            scl_out <= (state == ST_SEND_LOW ||
                        state == ST_ACK_LOW  ||
                        state == ST_READ_LOW  ||
                        state == ST_MACK_LOW  ||
                        state == ST_NACK_LOW  ||
                        state == ST_STOP_LOW  ||
                        state == ST_START_C) ? 1'b0 : 1'b1;
            // SDA 输出使能：当 sda_drive_low 为 1 时驱动低电平
            sda_oe  <= sda_drive_low;
            sda_out <= 1'b0;   // 数据保持为 0
        end
        // 非 tick 期间，scl_out / sda_oe 保持不变，实现与状态切换的同步边沿
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