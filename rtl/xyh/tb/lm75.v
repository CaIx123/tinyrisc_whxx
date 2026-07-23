`include "../tiny_macro.v"

// LM75温度传感器简化仿真模型
// 仅模拟I2C从设备基础行为，仅保留温度寄存器(pointer 0x00)
// 默认温度固定为20.5�?C，返回MSB=0x14, LSB=0x80 => 0x1480
// 通过pullup提供理想上拉，仿真中IIC线网行为比板级更理想
module lm75(

    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)
    inout wire iic_scl,                      // IIC SCL(仿真中使用pullup)
    inout wire iic_sda                       // IIC SDA(仿真中使用pullup)

    );

    localparam ST_IDLE      = 3'd0;
    localparam ST_RECV_ADDR = 3'd1;
    localparam ST_ACK_ADDR  = 3'd2;
    localparam ST_RECV_DATA = 3'd3;
    localparam ST_ACK_DATA  = 3'd4;
    localparam ST_SEND_DATA = 3'd5;
    localparam ST_WAIT_ACK  = 3'd6;

    reg [2:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] tx_shift;
    reg [7:0] pointer_reg;
    reg [7:0] sampled_byte_r;
    reg drive_low_r;
    reg addr_match_r;
    reg rw_read_r;
    reg write_is_pointer_r;
    reg temp_second_byte_r;

    wire scl_in = iic_scl;
    wire sda_in = iic_sda;

    pullup(iic_scl);
    pullup(iic_sda);

    assign iic_sda = drive_low_r ? 1'b0 : 1'bz;

    function [7:0] lm75_read_byte;
        input [7:0] pointer;
        input second_byte;
        begin
            case (pointer)
                `LM75_TEMP_REG_PTR: lm75_read_byte = second_byte ? `LM75_TEMP_LSB : `LM75_TEMP_MSB;
                default:            lm75_read_byte = 8'h00;
            endcase
        end
    endfunction

    task automatic load_tx_byte;
        input second_byte;
        begin
            tx_shift <= lm75_read_byte(pointer_reg, second_byte);
            bit_cnt <= 3'd7;
        end
    endtask

    always @ (posedge rst or negedge iic_sda or posedge iic_sda) begin
        if (rst) begin
            state <= ST_IDLE;
            bit_cnt <= 3'd7;
            shift_reg <= 8'h00;
            tx_shift <= `LM75_TEMP_MSB;
            pointer_reg <= `LM75_TEMP_REG_PTR;
            drive_low_r <= 1'b0;
            addr_match_r <= 1'b0;
            rw_read_r <= 1'b0;
            write_is_pointer_r <= 1'b1;
            temp_second_byte_r <= 1'b0;
        end else if (scl_in == 1'b1) begin
            if (iic_sda == 1'b0) begin
                // START
                state <= ST_RECV_ADDR;
                bit_cnt <= 3'd7;
                shift_reg <= 8'h00;
                drive_low_r <= 1'b0;
                addr_match_r <= 1'b0;
                rw_read_r <= 1'b0;
                write_is_pointer_r <= 1'b1;
                temp_second_byte_r <= 1'b0;
            end else begin
                // STOP
                state <= ST_IDLE;
                drive_low_r <= 1'b0;
            end
        end
    end

    always @ (posedge rst or posedge iic_scl) begin
        if (rst) begin
            state <= ST_IDLE;
            bit_cnt <= 3'd7;
            shift_reg <= 8'h00;
            tx_shift <= `LM75_TEMP_MSB;
            pointer_reg <= `LM75_TEMP_REG_PTR;
            drive_low_r <= 1'b0;
            addr_match_r <= 1'b0;
            rw_read_r <= 1'b0;
            write_is_pointer_r <= 1'b1;
            temp_second_byte_r <= 1'b0;
        end else begin
            sampled_byte_r = shift_reg;
            sampled_byte_r[bit_cnt] = sda_in;

            case (state)
                ST_RECV_ADDR: begin
                    shift_reg <= sampled_byte_r;
                    if (bit_cnt == 3'd0) begin
                        addr_match_r <= (sampled_byte_r[7:1] == `LM75_I2C_ADDR);
                        rw_read_r <= sampled_byte_r[0];
                        state <= ST_ACK_ADDR;
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                ST_ACK_ADDR: begin
                    if (!addr_match_r) begin
                        state <= ST_IDLE;
                    end else if (rw_read_r) begin
                        load_tx_byte(1'b0);
                        temp_second_byte_r <= 1'b0;
                        state <= ST_SEND_DATA;
                    end else begin
                        bit_cnt <= 3'd7;
                        shift_reg <= 8'h00;
                        write_is_pointer_r <= 1'b1;
                        state <= ST_RECV_DATA;
                    end
                end

                ST_RECV_DATA: begin
                    shift_reg <= sampled_byte_r;
                    if (bit_cnt == 3'd0) begin
                        if (write_is_pointer_r) begin
                            pointer_reg <= sampled_byte_r;
                            write_is_pointer_r <= 1'b0;
                        end
                        state <= ST_ACK_DATA;
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                ST_ACK_DATA: begin
                    bit_cnt <= 3'd7;
                    shift_reg <= 8'h00;
                    state <= ST_RECV_DATA;
                end

                ST_SEND_DATA: begin
                    if (bit_cnt == 3'd0) begin
                        state <= ST_WAIT_ACK;
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                end

                ST_WAIT_ACK: begin
                    if (sda_in == 1'b0) begin
                        if (!temp_second_byte_r) begin
                            load_tx_byte(1'b1);
                            temp_second_byte_r <= 1'b1;
                            state <= ST_SEND_DATA;
                        end else begin
                            state <= ST_IDLE;
                        end
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    drive_low_r <= 1'b0;
                end
            endcase
        end
    end

    always @ (posedge rst or negedge iic_scl) begin
        if (rst) begin
            drive_low_r <= 1'b0;
        end else begin
            case (state)
                ST_ACK_ADDR,
                ST_ACK_DATA: begin
                    drive_low_r <= 1'b1;
                end

                ST_SEND_DATA: begin
                    drive_low_r <= ~tx_shift[7];
                end

                default: begin
                    drive_low_r <= 1'b0;
                end
            endcase
        end
    end

endmodule
