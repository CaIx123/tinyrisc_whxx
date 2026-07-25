`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../macros.v"

module tb_bridge_soc_inst_add;

    reg clk;
    reg rst_n;
    integer i;

    wire uart_tx_pin;

    wire[31:0] x1  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[1];
    wire[31:0] x2  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[2];
    wire[31:0] x3  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire[31:0] x26 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire[31:0] x27 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];
    wire[31:0] x29 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[29];
    wire[31:0] x30 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[30];

    wire[31:0] ie_pc   = u_fpga_soc.u_soc_top.u_tinyriscv_core.ie_dec_pc_o;
    wire[31:0] ie_inst = u_fpga_soc.u_soc_top.u_tinyriscv_core.ie_inst_o;

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        for (i = 0; i < `ROM_DEPTH; i = i + 1) begin
            u_fpga_soc.u_fpga_top.u_exrom._ram[i] = `INST_NOP;
        end

        // Validation/Baisc_Inst_Example/inst_add.data
        u_fpga_soc.u_fpga_top.u_exrom._ram[0] = 32'h00000d13;
        u_fpga_soc.u_fpga_top.u_exrom._ram[1] = 32'h00000d93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[2] = 32'h00000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[3] = 32'h00000113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[4] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[5] = 32'h00000e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[6] = 32'h00200193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[7] = 32'h35df1263;
        u_fpga_soc.u_fpga_top.u_exrom._ram[8] = 32'h00100093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[9] = 32'h00100113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[10] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[11] = 32'h00200e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[12] = 32'h00300193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[13] = 32'h33df1663;
        u_fpga_soc.u_fpga_top.u_exrom._ram[14] = 32'h00000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[15] = 32'hffff8137;
        u_fpga_soc.u_fpga_top.u_exrom._ram[16] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[17] = 32'hffff8eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[18] = 32'h00500193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[19] = 32'h31df1a63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[20] = 32'h800000b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[21] = 32'h00000113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[22] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[23] = 32'h80000eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[24] = 32'h00600193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[25] = 32'h2fdf1e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[26] = 32'h00000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[27] = 32'h00008137;
        u_fpga_soc.u_fpga_top.u_exrom._ram[28] = 32'hfff10113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[29] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[30] = 32'h00008eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[31] = 32'hfffe8e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[32] = 32'h00800193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[33] = 32'h2ddf1e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[34] = 32'h800000b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[35] = 32'hfff08093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[36] = 32'h00000113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[37] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[38] = 32'h80000eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[39] = 32'hfffe8e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[40] = 32'h00900193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[41] = 32'h2bdf1e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[42] = 32'h800000b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[43] = 32'h00008137;
        u_fpga_soc.u_fpga_top.u_exrom._ram[44] = 32'hfff10113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[45] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[46] = 32'h80008eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[47] = 32'hfffe8e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[48] = 32'h00b00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[49] = 32'h29df1e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[50] = 32'h800000b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[51] = 32'hfff08093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[52] = 32'hffff8137;
        u_fpga_soc.u_fpga_top.u_exrom._ram[53] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[54] = 32'h7fff8eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[55] = 32'hfffe8e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[56] = 32'h00c00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[57] = 32'h27df1e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[58] = 32'h00000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[59] = 32'hfff00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[60] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[61] = 32'hfff00e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[62] = 32'h00d00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[63] = 32'h27df1263;
        u_fpga_soc.u_fpga_top.u_exrom._ram[64] = 32'hfff00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[65] = 32'h00100113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[66] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[67] = 32'h00000e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[68] = 32'h00e00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[69] = 32'h25df1663;
        u_fpga_soc.u_fpga_top.u_exrom._ram[70] = 32'h00100093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[71] = 32'h80000137;
        u_fpga_soc.u_fpga_top.u_exrom._ram[72] = 32'hfff10113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[73] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[74] = 32'h80000eb7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[75] = 32'h01000193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[76] = 32'h23df1863;
        u_fpga_soc.u_fpga_top.u_exrom._ram[77] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[78] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[79] = 32'h002080b3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[80] = 32'h01800e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[81] = 32'h01100193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[82] = 32'h21d09c63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[83] = 32'h00e00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[84] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[85] = 32'h00208133;
        u_fpga_soc.u_fpga_top.u_exrom._ram[86] = 32'h01900e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[87] = 32'h01200193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[88] = 32'h21d11063;
        u_fpga_soc.u_fpga_top.u_exrom._ram[89] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[90] = 32'h001080b3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[91] = 32'h01a00e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[92] = 32'h01300193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[93] = 32'h1fd09663;
        u_fpga_soc.u_fpga_top.u_exrom._ram[94] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[95] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[96] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[97] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[98] = 32'h000f0313;
        u_fpga_soc.u_fpga_top.u_exrom._ram[99] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[100] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[101] = 32'hfe5214e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[102] = 32'h01800e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[103] = 32'h01400193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[104] = 32'h1dd31063;
        u_fpga_soc.u_fpga_top.u_exrom._ram[105] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[106] = 32'h00e00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[107] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[108] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[109] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[110] = 32'h000f0313;
        u_fpga_soc.u_fpga_top.u_exrom._ram[111] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[112] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[113] = 32'hfe5212e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[114] = 32'h01900e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[115] = 32'h01500193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[116] = 32'h19d31863;
        u_fpga_soc.u_fpga_top.u_exrom._ram[117] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[118] = 32'h00f00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[119] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[120] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[121] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[122] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[123] = 32'h000f0313;
        u_fpga_soc.u_fpga_top.u_exrom._ram[124] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[125] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[126] = 32'hfe5210e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[127] = 32'h01a00e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[128] = 32'h01600193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[129] = 32'h15d31e63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[130] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[131] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[132] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[133] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[134] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[135] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[136] = 32'hfe5216e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[137] = 32'h01800e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[138] = 32'h01700193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[139] = 32'h13df1a63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[140] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[141] = 32'h00e00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[142] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[143] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[144] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[145] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[146] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[147] = 32'hfe5214e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[148] = 32'h01900e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[149] = 32'h01800193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[150] = 32'h11df1463;
        u_fpga_soc.u_fpga_top.u_exrom._ram[151] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[152] = 32'h00f00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[153] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[154] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[155] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[156] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[157] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[158] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[159] = 32'hfe5212e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[160] = 32'h01a00e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[161] = 32'h01900193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[162] = 32'h0ddf1c63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[163] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[164] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[165] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[166] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[167] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[168] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[169] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[170] = 32'hfe5214e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[171] = 32'h01800e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[172] = 32'h01a00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[173] = 32'h0bdf1663;
        u_fpga_soc.u_fpga_top.u_exrom._ram[174] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[175] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[176] = 32'h00d00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[177] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[178] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[179] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[180] = 32'hfe5216e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[181] = 32'h01800e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[182] = 32'h01d00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[183] = 32'h09df1263;
        u_fpga_soc.u_fpga_top.u_exrom._ram[184] = 32'h00000213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[185] = 32'h00b00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[186] = 32'h00e00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[187] = 32'h00000013;
        u_fpga_soc.u_fpga_top.u_exrom._ram[188] = 32'h00208f33;
        u_fpga_soc.u_fpga_top.u_exrom._ram[189] = 32'h00120213;
        u_fpga_soc.u_fpga_top.u_exrom._ram[190] = 32'h00200293;
        u_fpga_soc.u_fpga_top.u_exrom._ram[191] = 32'hfe5214e3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[192] = 32'h01900e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[193] = 32'h01e00193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[194] = 32'h05df1c63;
        u_fpga_soc.u_fpga_top.u_exrom._ram[195] = 32'h00f00093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[196] = 32'h00100133;
        u_fpga_soc.u_fpga_top.u_exrom._ram[197] = 32'h00f00e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[198] = 32'h02300193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[199] = 32'h05d11263;
        u_fpga_soc.u_fpga_top.u_exrom._ram[200] = 32'h02000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[201] = 32'h00008133;
        u_fpga_soc.u_fpga_top.u_exrom._ram[202] = 32'h02000e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[203] = 32'h02400193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[204] = 32'h03d11863;
        u_fpga_soc.u_fpga_top.u_exrom._ram[205] = 32'h000000b3;
        u_fpga_soc.u_fpga_top.u_exrom._ram[206] = 32'h00000e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[207] = 32'h02500193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[208] = 32'h03d09063;
        u_fpga_soc.u_fpga_top.u_exrom._ram[209] = 32'h01000093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[210] = 32'h01e00113;
        u_fpga_soc.u_fpga_top.u_exrom._ram[211] = 32'h00208033;
        u_fpga_soc.u_fpga_top.u_exrom._ram[212] = 32'h00000e93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[213] = 32'h02600193;
        u_fpga_soc.u_fpga_top.u_exrom._ram[214] = 32'h01d01463;
        u_fpga_soc.u_fpga_top.u_exrom._ram[215] = 32'h00301863;
        u_fpga_soc.u_fpga_top.u_exrom._ram[216] = 32'h00100d13;
        u_fpga_soc.u_fpga_top.u_exrom._ram[217] = 32'h00000d93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[218] = 32'h0000006f;
        u_fpga_soc.u_fpga_top.u_exrom._ram[219] = 32'h00100d13;
        u_fpga_soc.u_fpga_top.u_exrom._ram[220] = 32'h00100d93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[221] = 32'h0000006f;
        u_fpga_soc.u_fpga_top.u_exrom._ram[222] = 32'h00000000;

        #100;
        rst_n = 1'b1;

        wait (x26 == 32'h1);
        #300;

        if (x27 == 32'h1) begin
            $display("BRIDGE_SOC_INST_ADD_PASS x26=%h x27=%h last_case=%0d x1=%h x2=%h x29=%h x30=%h ie_pc=%h ie_inst=%h",
                     x26, x27, x3, x1, x2, x29, x30, ie_pc, ie_inst);
        end else begin
            $display("BRIDGE_SOC_INST_ADD_FAIL x26=%h x27=%h fail_case=%0d x1=%h x2=%h x29=%h x30=%h ie_pc=%h ie_inst=%h",
                     x26, x27, x3, x1, x2, x29, x30, ie_pc, ie_inst);
            $finish;
        end

        $finish;
    end

    initial begin
        #2000000;
        $display("BRIDGE_SOC_INST_ADD_TIMEOUT x26=%h x27=%h case=%0d x1=%h x2=%h x29=%h x30=%h ie_pc=%h ie_inst=%h",
                 x26, x27, x3, x1, x2, x29, x30, ie_pc, ie_inst);
        $finish;
    end

    tinyriscv_soc_fpga_top u_fpga_soc(
        .clk(clk),
        .rst_ext_i(rst_n),
        .succ(),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .uart_debug_pin(1'b0),
        .PWM_out_pin(),
        .IIC_SDA_pin(),
        .IIC_SCL_pin()
    );

endmodule
