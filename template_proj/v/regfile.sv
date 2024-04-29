`include "bsg_defines.v"

module vrf #( parameter els_p = 32  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 32  // number of bits per element

            , parameter lanes_p = 4

            , localparam addr_width_lp = `BSG_SAFE_CLOG2(els_p / lanes_p)
            , localparam rw_data_width_lp = vlen_p * vdw_p
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [lanes_p-1:0][addr_width_lp-1:0] r_addr_i
    , output logic [lanes_p-1:0][rw_data_width_lp-1:0] r_data_o

    , input  logic [lanes_p-1:0][addr_width_lp-1:0] w_addr_i
    , input  logic [lanes_p-1:0][rw_data_width_lp-1:0] w_data_i
    , input  logic [lanes_p-1:0] w_en_i
    );


    // declare register array, with (els_p) registers, each register containing a (vlen_p)-long vector. 
    // each vector element is (vdw_p) bits wide
    logic [vlen_p-1:0][vdw_p-1:0] reg_arr [els_p-1:0];

    // read
    for (genvar i = 0; i < lanes_p; i++) begin: r_lane
        assign r_data_o[i] = reg_arr[{i, r_addr_i}];
    end // r_lane

    // write
    for (genvar i = 0; i < lanes_p; i++) begin: w_lane
        always_ff @(posedge clk_i) begin
            if (w_en_i[i] == 1'b1) begin
                reg_arr[{i, w_addr_i}] <= w_data_i[i];
            end
        end
    end // w_lane
    

endmodule
