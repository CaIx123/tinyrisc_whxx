`timescale 1 ns / 1 ps

module lm75_model #(
    parameter [6:0] I2C_ADDR = 7'h48,
    parameter [15:0] TEMP_RAW = 16'h1eff
)(
    input wire clk,
    input wire rst_n,
    inout wire scl,
    inout wire sda
    );

    localparam S_IDLE      = 3'd0;
    localparam S_ADDR      = 3'd1;
    localparam S_WRITE     = 3'd2;
    localparam S_READ      = 3'd3;
    localparam S_READ_ACK  = 3'd4;
    localparam S_WAIT_STOP = 3'd5;

    reg prev_scl;
    reg prev_sda;
    reg sda_oe;
    reg[2:0] state;
    reg[2:0] next_state;
    reg[7:0] shift_reg;
    reg[7:0] reg_ptr;
    reg[7:0] tx_data;
    reg[2:0] bit_cnt;
    reg[2:0] read_bit;
    reg read_byte_sel;
    reg ack_pending;
    reg ack_seen_high;

    wire sda_in = sda;
    wire start_cond = (prev_sda == 1'b1) & (sda_in == 1'b0) & (scl == 1'b1);
    wire stop_cond = (prev_sda == 1'b0) & (sda_in == 1'b1) & (scl == 1'b1);
    wire scl_rise = (prev_scl == 1'b0) & (scl == 1'b1);
    wire scl_fall = (prev_scl == 1'b1) & (scl == 1'b0);
    wire[7:0] byte_sample = {shift_reg[6:0], sda_in};

    pullup(scl);
    pullup(sda);

    assign sda = sda_oe ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_scl <= 1'b1;
            prev_sda <= 1'b1;
            sda_oe <= 1'b0;
            state <= S_IDLE;
            next_state <= S_IDLE;
            shift_reg <= 8'h00;
            reg_ptr <= 8'h00;
            tx_data <= TEMP_RAW[15:8];
            bit_cnt <= 3'd7;
            read_bit <= 3'd7;
            read_byte_sel <= 1'b0;
            ack_pending <= 1'b0;
            ack_seen_high <= 1'b0;
        end else begin
            if (start_cond) begin
                sda_oe <= 1'b0;
                state <= S_ADDR;
                shift_reg <= 8'h00;
                bit_cnt <= 3'd7;
                read_bit <= 3'd7;
                ack_pending <= 1'b0;
                ack_seen_high <= 1'b0;
            end else if (stop_cond) begin
                sda_oe <= 1'b0;
                state <= S_IDLE;
                ack_pending <= 1'b0;
                ack_seen_high <= 1'b0;
            end else if (ack_pending) begin
                if (scl_fall && !ack_seen_high) begin
                    sda_oe <= 1'b1;
                end
                if (scl_rise) begin
                    ack_seen_high <= 1'b1;
                end
                if (scl_fall && ack_seen_high) begin
                    sda_oe <= 1'b0;
                    ack_pending <= 1'b0;
                    ack_seen_high <= 1'b0;
                    state <= next_state;
                    if (next_state == S_WRITE) begin
                        shift_reg <= 8'h00;
                        bit_cnt <= 3'd7;
                    end else if (next_state == S_READ) begin
                        read_byte_sel <= 1'b0;
                        tx_data <= TEMP_RAW[15:8];
                        read_bit <= 3'd7;
                        sda_oe <= ~TEMP_RAW[15];
                    end
                end
            end else begin
                case (state)
                    S_ADDR: begin
                        if (scl_rise) begin
                            shift_reg <= byte_sample;
                            if (bit_cnt == 3'd0) begin
                                if (byte_sample[7:1] == I2C_ADDR) begin
                                    ack_pending <= 1'b1;
                                    next_state <= byte_sample[0] ? S_READ : S_WRITE;
                                end else begin
                                    state <= S_WAIT_STOP;
                                end
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    S_WRITE: begin
                        if (scl_rise) begin
                            shift_reg <= byte_sample;
                            if (bit_cnt == 3'd0) begin
                                reg_ptr <= byte_sample;
                                ack_pending <= 1'b1;
                                next_state <= S_WRITE;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    S_READ: begin
                        if (scl_fall) begin
                            sda_oe <= ~tx_data[read_bit];
                        end
                        if (scl_rise) begin
                            if (read_bit == 3'd0) begin
                                sda_oe <= 1'b0;
                                state <= S_READ_ACK;
                            end else begin
                                read_bit <= read_bit - 1'b1;
                            end
                        end
                    end

                    S_READ_ACK: begin
                        if (scl_rise) begin
                            if (!read_byte_sel) begin
                                read_byte_sel <= 1'b1;
                                tx_data <= (reg_ptr == 8'h00) ? TEMP_RAW[7:0] : 8'h00;
                                sda_oe <= (reg_ptr == 8'h00) ? ~TEMP_RAW[7] : 1'b1;
                                read_bit <= 3'd7;
                                state <= S_READ;
                            end else begin
                                state <= S_WAIT_STOP;
                            end
                        end
                    end

                    default: begin
                    end
                endcase
            end

            prev_scl <= scl;
            prev_sda <= sda_in;
        end
    end

endmodule
