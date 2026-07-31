`timescale 1ns / 1ps

module kalsit_icg (

    input wire clk_i,
    input wire en_i,
    output wire clk_o

    );

    wire en_latched;

    // TLATNX1 is transparent while GN is low. The enable can therefore
    // change only during the low phase of clk_i and remains stable while
    // clk_i is high, preventing glitches on the gated clock.
    TLATNX1 u_enable_latch (.D(en_i), .GN(clk_i), .Q(en_latched), .QN());
    AND2X1 u_clock_and     (.A(clk_i), .B(en_latched), .Y(clk_o));

endmodule
