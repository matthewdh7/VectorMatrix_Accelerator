`include "bsg_defines.v"

module vrf #( parameter els_p = 32  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 32  // number of bits per element

            , parameter lanes_p = 4

            , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
            , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            , localparam addr_width_lp = v_addr_width_lp + local_addr_width_lp
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [lanes_p-1:0][addr_width_lp-1:0] r0_addr_i
    , input  logic [lanes_p-1:0][addr_width_lp-1:0] r1_addr_i
    , output logic [lanes_p-1:0][vdw_p-1:0] r0_data_o
    , output logic [lanes_p-1:0][vdw_p-1:0] r1_data_o

    , input  logic [lanes_p-1:0][addr_width_lp-1:0] w_addr_i
    , input  logic [lanes_p-1:0][vdw_p-1:0] w_data_i
    , input  logic [lanes_p-1:0] w_en_i
    );

    logic [lanes_p-1:0][local_addr_width_lp-1:0] r0_local_addr, r1_local_addr, w_local_addr;
    logic [lanes_p-1:0][v_addr_width_lp-1:0] r0_bank_addr, r1_bank_addr, w_bank_addr;

    // regfile
    logic [vlen_p-1:0][vdw_p-1:0] regfile [els_p-1:0];

    // read
    for (genvar i = 0; i < lanes_p; i++) begin: r_lane
        assign r0_data_o[i] = regfile[r0_bank_addr][r0_local_addr];
        assign r1_data_o[i] = regfile[r1_bank_addr][r1_local_addr];
    end // r_lane

    // write
    for (genvar i = 0; i < lanes_p; i++) begin: w_lane
        always_ff @(posedge clk_i) begin
            if (w_en_i[i] == 1'b1) begin
                regfile[w_bank_addr][w_local_addr] <= w_data_i[i];
            end
        end
    end // w_lane


    // check for conflicting writes
    always_ff @ (negedge clk_i) begin
        if (~reset_i) begin
            for (genvar i = 0; i < lanes_p; i++) begin
                for (genvar j = 0; j < lanes_p; j++) begin
                    if (i != j) begin
                        assert((w_en_i[i] != w_en_i[j]) | (w_addr_i[i] != w_addr_i[j]))
                            else $fatal(1, "Conflicting writes enabled. Writing to addr %b from %d, %d.", w_addr_i[i], i, j);
                    end
                end
            end
        end
    end
    
    // logic [els_p-1:0][local_addr_width_lp-1:0] r_addr_li;
    // logic [els_p-1:0][vdw_p-1:0] r_data_lo;

    // for (genvar i = 0; i < els_p; i++) begin : rd_mux
    //     bsg_mux    #(.width_p(local_addr_width_lp)
    //                 ,.els_p(2))
    //         r_addr_mux
    //             (.data_i    ({r1_addr_i[0+:local_addr_width_lp], r0_addr_i[0+:local_addr_width_lp]})
    //             ,.sel_i     (r1_addr_i[local_addr_width_lp+:v_addr_width_lp] == i)
    //             ,.data_o    (r_addr_li[i])
    //             );
    // end // rd_mux

    // // declare register array, with (els_p) registers, each register containing a (vlen_p)-long vector. 
    // // each vector element is (vdw_p) bits wide
    // for (genvar i = 0; i < els_p; i++) begin : v_reg
    //     v_reg    #(.vlen_p(vlen_p)
    //               ,.vdw_p(vdw_p)
    //               ,.lanes_p(lanes_p))
    //         v_register
    //             (.clk_i     (clk_i)
    //             ,.reset_i   (reset_i)

    //             ,.r_addr_i  (r_addr_li)
    //             ,.r_data_o  (r_data_lo[i])

    //             ,.w_addr_i  (w_addr_i)
    //             ,.w_data_i  (w_data_i)
    //             ,.w_en_i    ()
    //             )
    // end // v_reg

endmodule
