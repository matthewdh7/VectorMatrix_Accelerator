`include "bsg_defines.v"

module v_reg   #( parameter vlen_p = 8  // number of elements in vector
                , parameter vdw_p = 32  // number of bits per element

                , parameter lanes_p = 4 // number of lanes = banks

                , localparam addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
                , localparam lane_addr_width_lp = `BSG_SAFE_CLOG2(lanes_p)
                , localparam els_per_bank_lp = vlen_p / lanes_p
                , localparam bank_addr_width_lp = `BSG_SAFE_CLOG2(els_per_bank_lp)
                )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [lanes_p-1:0][addr_width_lp-1:0] r_addr_i
    , output logic [lanes_p-1:0][vdw_p-1:0] r_data_o

    , input  logic [lanes_p-1:0][addr_width_lp-1:0] w_addr_i
    , input  logic [lanes_p-1:0][vdw_p-1:0] w_data_i
    , input  logic [lanes_p-1:0] w_en_i
    );

    logic [lanes_p-1:0][bank_addr_width_lp-1:0] r_addr_li, w_addr_li;
    logic [lanes_p-1:0][lane_addr_width_lp-1:0] which_bank;

    // array of vlen_p elements, each vdw_p bits wide
    // banked to allow for each lane to access independently
    logic [els_per_bank_lp-1:0][vdw_p-1:0] bank [lanes_p-1:0];

    genvar i;
    if (lanes_p > 1) begin
        for (i = 0; i < lanes_p; i++) begin: r_lane
            // read
            assign r_addr_li[i] = r_addr_i[i] >> lane_addr_width_lp;
            assign which_bank[i] = r_addr_i[i][lane_addr_width_lp-1:0];
            assign r_data_o[i] = bank[which_bank[i]][r_addr_li[i]];

            // write
            assign w_addr_li[i] = w_addr_i[i] >> lane_addr_width_lp;
            always_ff @(posedge clk_i) begin
                if (w_en_i[i]) bank[i][w_addr_li[i]] <= w_data_i[i];
            end // always_ff
        end // r_lane
    end 
    else begin // special case for single lane
        assign r_data_o = bank[0][r_addr_i];
        always_ff @(posedge clk_i) begin
            if (w_en_i) bank[0][w_addr_i] <= w_data_i;
        end // always_ff
    end

endmodule
