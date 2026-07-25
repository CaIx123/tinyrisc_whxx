// RIB bus: 3 masters and five mapped slaves (address regions 0, 1, 3, 6, 7).
module rib(
    input wire clk,
    input wire rst_n,

    // master 0 interface
    input wire [31:0] m0_addr_i,
    input wire [31:0] m0_data_i,
    input wire [3:0] m0_sel_i,
    input wire m0_req_vld_i,
    input wire m0_rsp_rdy_i,
    input wire m0_we_i,
    output wire m0_req_rdy_o,
    output wire m0_rsp_vld_o,
    output wire [31:0] m0_data_o,

    // master 1 interface
    input wire [31:0] m1_addr_i,
    input wire [31:0] m1_data_i,
    input wire [3:0] m1_sel_i,
    input wire m1_req_vld_i,
    input wire m1_rsp_rdy_i,
    input wire m1_we_i,
    output wire m1_req_rdy_o,
    output wire m1_rsp_vld_o,
    output wire [31:0] m1_data_o,

    // master 2 interface
    input wire [31:0] m2_addr_i,
    input wire [31:0] m2_data_i,
    input wire [3:0] m2_sel_i,
    input wire m2_req_vld_i,
    input wire m2_rsp_rdy_i,
    input wire m2_we_i,
    output wire m2_req_rdy_o,
    output wire m2_rsp_vld_o,
    output wire [31:0] m2_data_o,

    // slave 0 interface
    input wire [31:0] s0_data_i,
    input wire s0_req_rdy_i,
    input wire s0_rsp_vld_i,
    output wire [31:0] s0_addr_o,
    output wire [31:0] s0_data_o,
    output wire [3:0] s0_sel_o,
    output wire s0_req_vld_o,
    output wire s0_rsp_rdy_o,
    output wire s0_we_o,

    // slave 1 interface
    input wire [31:0] s1_data_i,
    input wire s1_req_rdy_i,
    input wire s1_rsp_vld_i,
    output wire [31:0] s1_addr_o,
    output wire [31:0] s1_data_o,
    output wire [3:0] s1_sel_o,
    output wire s1_req_vld_o,
    output wire s1_rsp_rdy_o,
    output wire s1_we_o,

    // slave 3 interface
    input wire [31:0] s3_data_i,
    input wire s3_req_rdy_i,
    input wire s3_rsp_vld_i,
    output wire [31:0] s3_addr_o,
    output wire [31:0] s3_data_o,
    output wire [3:0] s3_sel_o,
    output wire s3_req_vld_o,
    output wire s3_rsp_rdy_o,
    output wire s3_we_o,

    // slave 6 interface
    input wire [31:0] s6_data_i,
    input wire s6_req_rdy_i,
    input wire s6_rsp_vld_i,
    output wire [31:0] s6_addr_o,
    output wire [31:0] s6_data_o,
    output wire [3:0] s6_sel_o,
    output wire s6_req_vld_o,
    output wire s6_rsp_rdy_o,
    output wire s6_we_o,

    // slave 7 interface
    input wire [31:0] s7_data_i,
    input wire s7_req_rdy_i,
    input wire s7_rsp_vld_i,
    output wire [31:0] s7_addr_o,
    output wire [31:0] s7_data_o,
    output wire [3:0] s7_sel_o,
    output wire s7_req_vld_o,
    output wire s7_rsp_rdy_o,
    output wire s7_we_o
    );

    localparam MASTER_NUM = 3;
    localparam SLAVE_NUM = 8;

    wire [MASTER_NUM-1:0] master_req;
    wire [MASTER_NUM-1:0] master_rsp_rdy;
    wire [MASTER_NUM-1:0] master_we;
    wire [31:0] master_addr [0:MASTER_NUM-1];
    wire [31:0] master_data [0:MASTER_NUM-1];
    wire [3:0] master_sel [0:MASTER_NUM-1];

    assign master_req = {m2_req_vld_i, m1_req_vld_i, m0_req_vld_i};
    assign master_rsp_rdy = {m2_rsp_rdy_i, m1_rsp_rdy_i, m0_rsp_rdy_i};
    assign master_we = {m2_we_i, m1_we_i, m0_we_i};

    assign master_addr[0] = m0_addr_i;
    assign master_addr[1] = m1_addr_i;
    assign master_addr[2] = m2_addr_i;
    assign master_data[0] = m0_data_i;
    assign master_data[1] = m1_data_i;
    assign master_data[2] = m2_data_i;
    assign master_sel[0] = m0_sel_i;
    assign master_sel[1] = m1_sel_i;
    assign master_sel[2] = m2_sel_i;

    reg [MASTER_NUM-1:0] rsp_master_sel_r;
    reg [SLAVE_NUM-1:0] rsp_slave_sel_r;

    reg [MASTER_NUM-1:0] master_sel_vec;

    always @(*) begin
        master_sel_vec = 3'b000;

        if (master_req[2]) begin
            master_sel_vec = 3'b100;   // m2
        end else if (master_req[1]) begin
            master_sel_vec = 3'b010;   // m1
        end else if (master_req[0]) begin
            master_sel_vec = 3'b001;   // m0
        end
    end

    reg [31:0] mux_m_addr;
    reg [31:0] mux_m_data;
    reg [3:0] mux_m_sel;
    reg mux_m_req_vld;
    reg mux_m_rsp_rdy;
    reg mux_m_we;

    integer j;

    always @(*) begin
        mux_m_addr = 32'b0;
        mux_m_data = 32'b0;
        mux_m_sel = 4'b0;
        mux_m_req_vld = 1'b0;
        mux_m_rsp_rdy = 1'b0;
        mux_m_we = 1'b0;
        for (j = 0; j < MASTER_NUM; j = j + 1) begin
            mux_m_addr = mux_m_addr | ({32{master_sel_vec[j]}} & master_addr[j]);
            mux_m_data = mux_m_data | ({32{master_sel_vec[j]}} & master_data[j]);
            mux_m_sel = mux_m_sel | ({4{master_sel_vec[j]}} & master_sel[j]);
            mux_m_req_vld = mux_m_req_vld | (master_sel_vec[j] & master_req[j]);
            mux_m_rsp_rdy = mux_m_rsp_rdy | (master_sel_vec[j] & master_rsp_rdy[j]);
            mux_m_we = mux_m_we | (master_sel_vec[j] & master_we[j]);
        end
    end

    wire [SLAVE_NUM-1:0] slave_sel;
    wire [SLAVE_NUM-1:0] slave_req_rdy;
    wire [SLAVE_NUM-1:0] slave_rsp_vld;
    wire [31:0] slave_data [0:SLAVE_NUM-1];

    assign slave_sel[0] = mux_m_addr[31:28] == 4'h0;
    assign slave_sel[1] = mux_m_addr[31:28] == 4'h1;
    assign slave_sel[2] = mux_m_addr[31:28] == 4'h2;
    assign slave_sel[3] = mux_m_addr[31:28] == 4'h3;
    assign slave_sel[4] = mux_m_addr[31:28] == 4'h4;
    assign slave_sel[5] = mux_m_addr[31:28] == 4'h5;
    assign slave_sel[6] = mux_m_addr[31:28] == 4'h6;
    assign slave_sel[7] = mux_m_addr[31:28] == 4'h7;

    assign slave_req_rdy = {s7_req_rdy_i, s6_req_rdy_i, 1'b0, 1'b0,
                            s3_req_rdy_i, 1'b0, s1_req_rdy_i,
                            s0_req_rdy_i};
    assign slave_rsp_vld = {s7_rsp_vld_i, s6_rsp_vld_i, 1'b0, 1'b0,
                            s3_rsp_vld_i, 1'b0, s1_rsp_vld_i,
                            s0_rsp_vld_i};
    assign slave_data[0] = s0_data_i;
    assign slave_data[1] = s1_data_i;
    assign slave_data[2] = 32'b0;
    assign slave_data[3] = s3_data_i;
    assign slave_data[4] = 32'b0;
    assign slave_data[5] = 32'b0;
    assign slave_data[6] = s6_data_i;
    assign slave_data[7] = s7_data_i;

    reg [31:0] mux_s_data;
    reg mux_s_req_rdy;
    reg mux_s_rsp_vld;
    reg mux_rsp_master_rdy;

    wire req_hasked = mux_m_req_vld & mux_s_req_rdy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_master_sel_r <= {MASTER_NUM{1'b0}};
            rsp_slave_sel_r <= {SLAVE_NUM{1'b0}};
        end else if (req_hasked) begin
            rsp_master_sel_r <= master_sel_vec;
            rsp_slave_sel_r <= slave_sel;
        end
    end

    always @(*) begin
        mux_s_data = 32'b0;
        mux_s_req_rdy = 1'b0;
        mux_s_rsp_vld = 1'b0;
        mux_rsp_master_rdy = 1'b0;
        for (j = 0; j < SLAVE_NUM; j = j + 1) begin
            mux_s_data = mux_s_data | ({32{rsp_slave_sel_r[j]}} & slave_data[j]);
            mux_s_req_rdy = mux_s_req_rdy | (slave_sel[j] & slave_req_rdy[j]);
            mux_s_rsp_vld = mux_s_rsp_vld | (rsp_slave_sel_r[j] & slave_rsp_vld[j]);
        end
        for (j = 0; j < MASTER_NUM; j = j + 1) begin
            mux_rsp_master_rdy = mux_rsp_master_rdy | (rsp_master_sel_r[j] & master_rsp_rdy[j]);
        end
    end

    wire [MASTER_NUM-1:0] demux_m_req_rdy;
    wire [MASTER_NUM-1:0] demux_m_rsp_vld;
    wire [31:0] demux_m_data [0:MASTER_NUM-1];

    genvar i;
    generate
        for (i = 0; i < MASTER_NUM; i = i + 1) begin: demux_m_sig
            assign demux_m_req_rdy[i] = master_sel_vec[i] & mux_s_req_rdy;
            assign demux_m_rsp_vld[i] = rsp_master_sel_r[i] & mux_s_rsp_vld;
            assign demux_m_data[i] = {32{rsp_master_sel_r[i]}} & mux_s_data;
        end
    endgenerate

    assign m0_req_rdy_o = demux_m_req_rdy[0];
    assign m1_req_rdy_o = demux_m_req_rdy[1];
    assign m2_req_rdy_o = demux_m_req_rdy[2];
    assign m0_rsp_vld_o = demux_m_rsp_vld[0];
    assign m1_rsp_vld_o = demux_m_rsp_vld[1];
    assign m2_rsp_vld_o = demux_m_rsp_vld[2];
    assign m0_data_o = demux_m_data[0];
    assign m1_data_o = demux_m_data[1];
    assign m2_data_o = demux_m_data[2];

    wire [31:0] demux_s_addr [0:SLAVE_NUM-1];
    wire [31:0] demux_s_data [0:SLAVE_NUM-1];
    wire [3:0] demux_s_sel [0:SLAVE_NUM-1];
    wire [SLAVE_NUM-1:0] demux_s_req_vld;
    wire [SLAVE_NUM-1:0] demux_s_rsp_rdy;
    wire [SLAVE_NUM-1:0] demux_s_we;

    generate
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin: demux_s_sig
            assign demux_s_addr[i] = {32{slave_sel[i]}} & {4'h0, mux_m_addr[27:0]};
            assign demux_s_data[i] = {32{slave_sel[i]}} & mux_m_data;
            assign demux_s_sel[i] = {4{slave_sel[i]}} & mux_m_sel;
            assign demux_s_req_vld[i] = slave_sel[i] & mux_m_req_vld;
            assign demux_s_rsp_rdy[i] = rsp_slave_sel_r[i] & mux_rsp_master_rdy;
            assign demux_s_we[i] = slave_sel[i] & mux_m_we;
        end
    endgenerate

    assign s0_addr_o = demux_s_addr[0];
    assign s1_addr_o = demux_s_addr[1];
    assign s3_addr_o = demux_s_addr[3];
    assign s6_addr_o = demux_s_addr[6];
    assign s7_addr_o = demux_s_addr[7];
    assign s0_data_o = demux_s_data[0];
    assign s1_data_o = demux_s_data[1];
    assign s3_data_o = demux_s_data[3];
    assign s6_data_o = demux_s_data[6];
    assign s7_data_o = demux_s_data[7];
    assign s0_sel_o = demux_s_sel[0];
    assign s1_sel_o = demux_s_sel[1];
    assign s3_sel_o = demux_s_sel[3];
    assign s6_sel_o = demux_s_sel[6];
    assign s7_sel_o = demux_s_sel[7];
    assign s0_req_vld_o = demux_s_req_vld[0];
    assign s1_req_vld_o = demux_s_req_vld[1];
    assign s3_req_vld_o = demux_s_req_vld[3];
    assign s6_req_vld_o = demux_s_req_vld[6];
    assign s7_req_vld_o = demux_s_req_vld[7];
    assign s0_rsp_rdy_o = demux_s_rsp_rdy[0];
    assign s1_rsp_rdy_o = demux_s_rsp_rdy[1];
    assign s3_rsp_rdy_o = demux_s_rsp_rdy[3];
    assign s6_rsp_rdy_o = demux_s_rsp_rdy[6];
    assign s7_rsp_rdy_o = demux_s_rsp_rdy[7];
    assign s0_we_o = demux_s_we[0];
    assign s1_we_o = demux_s_we[1];
    assign s3_we_o = demux_s_we[3];
    assign s6_we_o = demux_s_we[6];
    assign s7_we_o = demux_s_we[7];

endmodule
