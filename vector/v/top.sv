`include "bsg_defines.v"
module top      #( parameter els_p = 32  // number of vectors stored
                 , parameter vlen_p = 8  // number of elements per vector
                 , parameter vdw_p = 8  // number of bits per element
 
                 , parameter lanes_p = 4
 
                 , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                 , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
                 , localparam addr_width_lp = v_addr_width_lp + local_addr_width_lp
                )
    ( input clk_i
    , input reset_i

    // input interface
    , input logic [vdw_p-1:0] scalar_i
    , input logic [3:0] op_i
    , input v_i
    , output ready_o

    // output interface (valid, data and more?)
    , output logic [(vlen_p * vdw_p)-1:0] r_data_o
    , output v_o
    , input yumi_i
    );

    /* OP CODES
    0000: add
    0001: sub
    0010: mult
    0100: add v&s
    0101: sub v&s
    0110: mult v&s
    1000: read
    1001: write
    */

    // vrf
    vrf #(
        .els_p(els_p),
        .vlen_p(vlen_p),
        .vdw_p(vdw_p),
        .lanes_p(lanes_p)
    ) int_vrf (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .r0_addr_i  (),
        .r1_addr_i  (),
        .r0_data_o  (),
        .r1_data_o  (),
        .w_addr_i   (),
        .w_data_i   (),
        .w_en_i     ()
    );

endmodule