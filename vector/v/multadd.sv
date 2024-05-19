`include "bsg_defines.v"

module multadd #( parameter vdw_p = 32 )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [vdw_p-1:0] a_i
    , input  logic [vdw_p-1:0] b_i
    , input  logic [1:0] alu_op_i
    , input  logic use_fma_i
    , input  logic fma_first_i // true if first fma cycle, where we need to have second adder input be 0 (accum output is invalid)

    , output logic [vdw_p-1:0] data_o

    // unused
    , output logic flag_overflow_o
    , output logic flag_zero_o
    , output logic flag_negative_o
    );

    logic [vdw_p-1:0] from_acc_lo, acc_lo;

    logic [vdw_p-1:0] alu_a_li, alu_b_li, alu_result_lo, pipe_reg_li;
    logic alu_op_li, alu_c_lo;
    logic [(vdw_p*2)-1:0] mult_lo;

    assign alu_op_li = use_fma_i ? 1'b0 : alu_op_i[0];

    bsg_mul_synth #(.width_p(vdw_p))
        multiplier
            (.a_i   (a_i)
            ,.b_i   (b_i)
            ,.o     (mult_lo)
            );

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        alu_a_mux
            (.data_i    ({from_acc_lo, a_i})
            ,.sel_i     (use_fma_i)
            ,.data_o    (alu_a_li)
            );
    
    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        alu_b_mux
            (.data_i    ({mult_lo[vdw_p-1:0], b_i})
            ,.sel_i     (use_fma_i)
            ,.data_o    (alu_b_li)
            );

    alu     #(.vdw_p(vdw_p))
        adder
            (.clk_i     (clk_i)  
            ,.reset_i   (reset_i)

            ,.a_i       (alu_a_li)
            ,.b_i       (alu_b_li)
            ,.op_i      (alu_op_li)

            ,.result_o  (alu_result_lo)

            ,.flag_overflow_o   (flag_overflow_o)
            ,.flag_zero_o       (flag_zero_o)
            ,.flag_negative_o   (flag_negative_o)
            );

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        acc_mux
            (.data_i    ({(vdw_p)'(1'b0), acc_lo})
            ,.sel_i     (fma_first_i)
            ,.data_o    (from_acc_lo)
            );

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        reg_in_mux
            (.data_i    ({mult_lo[vdw_p-1:0], alu_result_lo})
            ,.sel_i     (alu_op_i == 2'b10)
            ,.data_o    (pipe_reg_li)
            ); 

    bsg_dff #(.width_p(vdw_p))
        acc
            (.clk_i     (clk_i)
            ,.data_i    (pipe_reg_li)
            ,.data_o    (acc_lo)
            );
    
    assign data_o = acc_lo;

endmodule