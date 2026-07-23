`timescale 1 ns / 1 ps

module tb_iic_basic;

    localparam IIC_CTRL       = 32'h0000_0000;
    localparam SLAVE_ADDR_REG = 32'h0001_0000;
    localparam IIC_OUTPUT_REG = 32'h0002_0000;
    localparam IIC_INPUT_REG  = 32'h0003_0000;

    reg clk;
    reg rst_n;

    reg we;
    reg[31:0] addr;
    reg[31:0] wdata;
    reg[3:0] sel;
    wire[31:0] rdata;
    reg req_valid;
    wire req_ready;
    wire rsp_valid;
    reg rsp_ready;

    tri1 SDA;
    wire SCL;
    reg slave_sda_drive_low;

    reg[7:0] slave_wr_data;
    reg[7:0] slave_rd_msb;
    reg[7:0] slave_rd_lsb;
    reg[31:0] ctrl_value;
    reg[31:0] input_value;

    integer i;

    assign SDA = slave_sda_drive_low ? 1'b0 : 1'bz;

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        we = 1'b0;
        addr = 32'h0;
        wdata = 32'h0;
        sel = 4'hf;
        req_valid = 1'b0;
        rsp_ready = 1'b1;
        slave_sda_drive_low = 1'b0;
        slave_wr_data = 8'h0;
        slave_rd_msb = 8'h12;
        slave_rd_lsb = 8'h34;

        #100;
        rst_n = 1'b1;

        bus_write(SLAVE_ADDR_REG, 32'h0000_0048);
        bus_write(IIC_OUTPUT_REG, 32'h0000_005a);

        fork
            begin
                i2c_expect_write(7'h48, slave_wr_data);
            end
            begin
                bus_write(IIC_CTRL, 32'h0000_0010);
            end
        join

        wait_done();

        if (slave_wr_data != 8'h5a) begin
            $display("IIC_BASIC_FAIL write_data=%h expected=5a", slave_wr_data);
            $finish;
        end

        bus_write(IIC_CTRL, 32'h0000_0040);

        fork
            begin
                i2c_respond_read2(7'h48, slave_rd_msb, slave_rd_lsb);
            end
            begin
                bus_write(IIC_CTRL, 32'h0000_0080);
            end
        join

        wait_done();
        bus_read(IIC_INPUT_REG, input_value);
        
        if (input_value[15:0] == 16'h1234) begin
            $display("IIC_BASIC_PASS write=%h read=%h ctrl=%h", slave_wr_data, input_value, ctrl_value);
        end else begin
            $display("IIC_BASIC_FAIL write=%h read=%h expected=00001234 ctrl=%h",
                     slave_wr_data, input_value, ctrl_value);
            $finish;
        end

        # 200;
        $finish;
    end

    initial begin
        #2000000;
        $display("IIC_BASIC_TIMEOUT write=%h read=%h ctrl=%h SCL=%b SDA=%b",
                 slave_wr_data, input_value, ctrl_value, SCL, SDA);
        $finish;
    end

    task bus_write;
        input[31:0] bus_addr;
        input[31:0] bus_data;
        begin
            @(posedge clk);
            addr <= bus_addr;
            wdata <= bus_data;
            we <= 1'b1;
            sel <= 4'hf;
            req_valid <= 1'b1;
            wait (req_ready == 1'b1);
            @(posedge clk);
            req_valid <= 1'b0;
            we <= 1'b0;
            wait (rsp_valid == 1'b1);
            @(posedge clk);
        end
    endtask

    task bus_read;
        input[31:0] bus_addr;
        output[31:0] bus_data;
        begin
            @(posedge clk);
            addr <= bus_addr;
            wdata <= 32'h0;
            we <= 1'b0;
            sel <= 4'hf;
            req_valid <= 1'b1;
            wait (req_ready == 1'b1);
            @(posedge clk);
            req_valid <= 1'b0;
            wait (rsp_valid == 1'b1);
            bus_data = rdata;
            @(posedge clk);
        end
    endtask

    task wait_done;
        begin
            ctrl_value = 32'h0;
            for (i = 0; i < 200; i = i + 1) begin
                bus_read(IIC_CTRL, ctrl_value);
                if (ctrl_value[1]) begin
                    i = 200;
                end
            end
            if (!ctrl_value[1]) begin
                $display("IIC_BASIC_FAIL done_timeout ctrl=%h", ctrl_value);
                $finish;
            end
        end
    endtask

    task wait_start;
        begin
            wait (SCL == 1'b1 && SDA == 1'b1);
            @(negedge SDA);
        end
    endtask

    task i2c_recv_byte;
        output[7:0] value;
        integer bit_idx;
        begin
            value = 8'h0;
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                @(posedge SCL);
                value[bit_idx] = SDA;
            end
        end
    endtask

    task i2c_ack;
        begin
            @(negedge SCL);
            slave_sda_drive_low = 1'b1;
            @(negedge SCL);
            slave_sda_drive_low = 1'b0;
        end
    endtask

    task i2c_send_byte;
        input[7:0] value;
        output master_ack;
        integer bit_idx;
        begin
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                slave_sda_drive_low = ~value[bit_idx];
                @(posedge SCL);
                @(negedge SCL);
            end
            slave_sda_drive_low = 1'b0;
            @(posedge SCL);
            master_ack = ~SDA;
            @(negedge SCL);
        end
    endtask

    task i2c_expect_write;
        input[6:0] exp_addr;
        output[7:0] wr_data;
        reg[7:0] got_addr;
        begin
            wait_start();
            i2c_recv_byte(got_addr);
            if (got_addr != {exp_addr, 1'b0}) begin
                $display("IIC_BASIC_FAIL write_addr=%h expected=%h", got_addr, {exp_addr, 1'b0});
                $finish;
            end
            i2c_ack();
            i2c_recv_byte(wr_data);
            i2c_ack();
            wait (SCL == 1'b1 && SDA == 1'b1);
        end
    endtask

    task i2c_respond_read2;
        input[6:0] exp_addr;
        input[7:0] rd_msb;
        input[7:0] rd_lsb;
        reg[7:0] got_addr;
        reg master_ack;
        begin
            wait_start();
            i2c_recv_byte(got_addr);
            if (got_addr != {exp_addr, 1'b1}) begin
                $display("IIC_BASIC_FAIL read_addr=%h expected=%h", got_addr, {exp_addr, 1'b1});
                $finish;
            end
            i2c_ack();
            i2c_send_byte(rd_msb, master_ack);
            if (!master_ack) begin
                $display("IIC_BASIC_FAIL first_read_byte_not_acked");
                $finish;
            end
            i2c_send_byte(rd_lsb, master_ack);
            if (master_ack) begin
                $display("IIC_BASIC_FAIL second_read_byte_acked");
                $finish;
            end
            wait (SCL == 1'b1 && SDA == 1'b1);
        end
    endtask

    IIC u_iic(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(we),
        .addr_i(addr),
        .data_i(wdata),
        .sel_i(sel),
        .data_o(rdata),
        .req_valid_i(req_valid),
        .req_ready_o(req_ready),
        .rsp_valid_o(rsp_valid),
        .rsp_ready_i(rsp_ready),
        .SDA(SDA),
        .SCL(SCL)
    );

endmodule
