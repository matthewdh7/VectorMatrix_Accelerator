// DEPRECATED

`include "bsg_defines.v"

// Multiply-add unit, R0*R1 + R2 -> R3
module mult_add #(parameter vdw_p = 32)
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [vdw_p-1:0] r0_i
    , input  logic [vdw_p-1:0] r1_i
    , input  logic [vdw_p-1:0] r2_i

    , output logic [vdw_p-1:0] result_o
    );

    logic [(vdw_p*2)-1:0] mult_lo;
    logic adder_c_lo;

    bsg_mul_synth #(.width_p(vdw_p))
        multiplier
            (.a_i   (r0_i)
            ,.b_i   (r1_i)
            ,.o     (mult_lo)
            );

    bsg_adder_ripple_carry #(.width_p(vdw_p))
        adder
            (.a_i   (mult_lo[vdw_p-1:0])
            ,.b_i   (r2_i)
            ,.s_o   (result_o)
            ,.c_o   (adder_c_lo)
            );

endmodule