// 5/18: simplified to remove multiplication in process of converting EX stage to multiply-accumulate

`include "bsg_defines.v"

module alu #( parameter vdw_p = 32
            , parameter op_width_p = 1
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [vdw_p-1:0] a_i
    , input  logic [vdw_p-1:0] b_i
    , input  logic [op_width_p-1:0] op_i

    , output logic [vdw_p-1:0] result_o

    , output logic flag_overflow_o
    , output logic flag_zero_o
    , output logic flag_negative_o
    );

    // typedef enum logic [op_width_p-1:0] {
    //     eAdd='d0,
    //     eSub='d1,
    // } eOp;

    logic [vdw_p-1:0] b_inv, adder_b_li, adder_s_lo;
    logic adder_c_lo;
    logic [(vdw_p*2)-1:0] mult_lo;

    assign b_inv = (-1'b1) * b_i;
    assign adder_b_li = (op_i == 1'b1) ? b_inv : b_i;

    bsg_adder_ripple_carry #(.width_p(vdw_p))
        adder
            (.a_i   (a_i)
            ,.b_i   (adder_b_li)
            ,.s_o   (adder_s_lo)
            ,.c_o   (adder_c_lo)
            );
    
    bsg_mul_synth #(.width_p(vdw_p))
        multiplier
            (.a_i   (a_i)
            ,.b_i   (b_i)
            ,.o     (mult_lo)
            );

    always_comb begin
        case (op_i)
            1'b0: begin
                result_o = adder_s_lo;
                flag_overflow_o = adder_c_lo;
            end
            1'b1: begin
                result_o = adder_s_lo;
                flag_overflow_o = ~adder_c_lo;
            end
            eMult: begin
                result_o = mult_lo[vdw_p-1:0];
                flag_overflow_o = mult_lo[vdw_p];
            end
        endcase
    end

    assign flag_zero_o = result_o == '0;
    assign flag_negative_o = result_o[vdw_p-1];

endmodule