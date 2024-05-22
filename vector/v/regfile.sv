`include "bsg_defines.v"

module vrf #( parameter els_p = 32  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 32  // number of bits per element

            , parameter lanes_p = 4

            , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
            , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            )
    ( input  logic clk_i
    , input  logic reset_i

    , input  logic [lanes_p-1:0][v_addr_width_lp-1:0] r_reg0_addr_i
    , input  logic [lanes_p-1:0][v_addr_width_lp-1:0] r_reg1_addr_i

    // only need one addr per lane, because access pattern is same addr for each read vector
    , input  logic [lanes_p-1:0][local_addr_width_lp-1:0] r_addr_i
    , output logic [lanes_p-1:0][vdw_p-1:0] r0_data_o
    , output logic [lanes_p-1:0][vdw_p-1:0] r1_data_o

    , input  logic [v_addr_width_lp-1:0] w_reg_addr_i

    , input  logic [lanes_p-1:0][local_addr_width_lp-1:0] w_addr_i
    , input  logic [lanes_p-1:0][vdw_p-1:0] w_data_i
    , input  logic [lanes_p-1:0] w_en_i
    );

    logic [els_p-1:0][lanes_p-1:0][vdw_p-1:0] r_data_lo;
    logic [els_p-1:0][lanes_p-1:0] w_en_li;

    // declare register array, with (els_p) registers, each register containing a (vlen_p)-long vector. 
    // each vector element is (vdw_p) bits wide
    genvar i;
    for (i = 0; i < els_p; i++) begin : v_reg
        v_reg    #(.vlen_p(vlen_p)
                  ,.vdw_p(vdw_p)
                  ,.lanes_p(lanes_p))
            v_register
                (.clk_i     (clk_i)
                ,.reset_i   (reset_i)

                ,.r_addr_i  (r_addr_i)
                ,.r_data_o  (r_data_lo[i])

                ,.w_addr_i  (w_addr_i)
                ,.w_data_i  (w_data_i)
                ,.w_en_i    (w_en_li[i])
                );
        
        assign w_en_li[i] = w_en_i & {lanes_p{(w_reg_addr_i == i)}};
        // alternative
        // assign w_en_li[i] = (w_reg_addr_i == i) ? w_en_i : '0;
        
    end // v_reg

    //// read muxes
    generate
        for (i = 0; i < lanes_p; i++) begin : lanes
            logic [lanes_p-1:0][vdw_p-1:0] r0_data_lo, r1_data_lo, r2_data_lo;
            
            bsg_mux    #(.width_p(lanes_p*vdw_p)
                        ,.els_p(els_p))
                els_to_lanes_mux0
                    (.data_i    (r_data_lo)
                    ,.sel_i     (r_reg0_addr_i[i])
                    ,.data_o    (r0_data_lo)
                    );
            bsg_mux    #(.width_p(vdw_p)
                        ,.els_p(lanes_p))
                lanes_to_lane_mux0
                    (.data_i    (r0_data_lo)
                    ,.sel_i     ((`BSG_SAFE_CLOG2(lanes_p))'(i))
                    ,.data_o    (r0_data_o[i])
                    );

            bsg_mux    #(.width_p(lanes_p*vdw_p)
                        ,.els_p(els_p))
                els_to_lanes_mux1
                    (.data_i    (r_data_lo)
                    ,.sel_i     (r_reg1_addr_i[i])
                    ,.data_o    (r1_data_lo)
                    );
            bsg_mux    #(.width_p(vdw_p)
                        ,.els_p(lanes_p))
                lanes_to_lane_mux1
                    (.data_i    (r1_data_lo)
                    ,.sel_i     ((`BSG_SAFE_CLOG2(lanes_p))'(i))
                    ,.data_o    (r1_data_o[i])
                    );
        end // lanes
    endgenerate

endmodule
