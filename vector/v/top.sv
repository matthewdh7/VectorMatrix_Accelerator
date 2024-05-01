`include "bsg_defines.v"
module top      #( parameter els_p = 32  // number of vectors stored
                , parameter vlen_p = 8  // number of elements per vector
                , parameter vdw_p = 32  // number of bits per element

                , parameter lanes_p = 4

                , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
                , localparam addr_width_lp = v_addr_width_lp + local_addr_width_lp
                )
    ( 
    , input clk_i
    , input reset_i

    // input interface (valid, element and more?)
    , input logic [vdw_p-1:0] element_i
    , input v_i
    , output ready_o

    // output interface (valid, data and more?)
    , output logic out
    , output v_o
    , input yumi_i
    );

    //////////////////////////////
    //                          //
    //        ID STAGE          //
    //                          //
    //////////////////////////////
    
    // ctrl signal that we need for vrf

    // pipeline signal

    // vrf
    vrf #(
        .els_p(4),
        .vlen_p(8),
        .vdw_p(32),
        .lanes_p(4)
    ) int_vrf (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .r0_addr_i(),
        .r1_addr_i(),
        .r0_data_o(),
        .r1_data_o(),
        .w_addr_i(),
        .w_data_i(),
        .w_en_i()
    );

    //////////////////////////////
    //                          //
    //        EXE STAGE         //
    //                          //
    //////////////////////////////

    // ctrl signal that we need for alu
    logic a_li, b_li;
    // pipeline signal

    // alu
    alu #(
        .vdw_p(32),
        .op_len_p(2)
    ) alu_inst (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .a_i(a_li),
        .b_i(b_li),
        .op_i(),
        .result_o(),
        .flag_overflow_o(),
        .flag_zero_o(),
        .flag_negative_o()
    );
endmodule