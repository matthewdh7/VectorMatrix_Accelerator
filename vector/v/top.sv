`include "bsg_defines.v"
module top      #( parameter els_p = 32  // number of vectors stored
                 , parameter vlen_p = 8  // number of elements per vector
                 , parameter vdw_p = 8  // number of bits per element
 
                 , parameter lanes_p = 4
 
                 , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                 , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
                 , localparam addr_width_lp = v_addr_width_lp + local_addr_width_lp
                 , localparam els_per_lane_lp = vlen_p / vdw_p
                 , localparam counter_width_lp = `BSG_SAFE_CLOG2(els_per_lane_lp)
                )
    ( input clk_i
    , input reset_i

    // input interface
    , input logic [v_addr_width_lp-1:0] addrA_i // operand 1
    , input logic [v_addr_width_lp-1:0] addrB_i // operand 2
    , input logic [v_addr_width_lp-1:0] addrC_i // destination
    , input logic [vdw_p-1:0] scalar_i
    , input logic [(vlen_p * vdw_p)-1:0] w_data_i
    , input logic [3:0] op_i
    , input v_i
    , output ready_o

    // output interface
    , output logic done_o
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

    logic [lanes_p-1:0] v_lo, done_lo;
    logic [lanes_p-1:0][vdw_p-1:0] w_data_li, r_data_lo;

    logic [counter_width_lp-1:0] count_lo;

    enum {s_IDLE, s_LOOP, s_DONE} ps, ns;
    always_comb begin
        case(ps)
            s_IDLE: ns = v_i ? s_LOOP : s_IDLE;
            s_LOOP: ns = &done_lo ? s_DONE : s_LOOP;
            s_DONE: ns = yumi_i ? s_IDLE : s_DONE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i)    ps <= s_IDLE;
        else            ps <= ns;
    end

    bsg_counter_set_en #(.max_val_p(els_per_lane_lp))
        data_counter
            (.clk_i     (clk_i)
            ,.reset_i   (reset_i)

            ,.set_i     (ps == s_IDLE)
            ,.en_i      (ps == s_LOOP)
            ,.val_i     ('0)
            ,.count_o   (count_lo)
            );

    genvar i;
    for (i = 0; i < lanes_p; i++) begin : lane_data_interface
        always_ff @(posedge clk_i) begin
            // access next write data based on start    jump size           # jumps     + width of one element
            w_data_li[i] <= w_data_i[(i * vdw_p) + (lanes_p * vdw_p) * (count_lo) +: vdw_p];
            if (v_lo[i])
                r_data_o[(i * vdw_p) + (lanes_p * vdw_p) * (count_lo) +: vdw_p] <= r_data_lo[i];
        end
    end


    // lanes
    logic [lanes_p-1:0][local_addr_width_lp-1:0] r_addr_lo, w_addr_lo;
    logic [lanes_p-1:0][vdw_p-1:0] r0_data_li, r1_data_li, w_data_lo;
    logic [lanes_p-1:0] w_en_lo;

    for (i = 0; i < lanes_p; i++) begin : lane
        lane #(.els_p(els_p)
                ,.vlen_p(vlen_p)
                ,.vdw_p(vdw_p)
                ,.lanes_p(lanes_p)
                ,.op_width_p(4))
            lane
                (.clk_i     (clk_i)
                ,.reset_i   (reset_i)
  
                ,.my_id_i   (i)

                ,.op_i      (op_i)
                ,.start_i   (v_i)

                ,.scalar_i  (scalar_i)
                ,.w_data_i  (w_data_li[i])
                ,.r_data_o  (r_data_lo[i])
                ,.v_o       (v_lo[i])
                ,.done_o    (done_lo[i])

                // regfile connections
                ,.r_addr_o  (r_addr_lo[i])
                ,.r0_data_i (r0_data_li[i])
                ,.r1_data_i (r1_data_li[i])

                ,.w_addr_o  (w_addr_lo[i])
                ,.w_data_o  (w_data_lo[i])
                ,.w_en_o    (w_en_lo[i])
                );
    end

    // vrf
    vrf #(.els_p(els_p)
         ,.vlen_p(vlen_p)
         ,.vdw_p(vdw_p)
         ,.lanes_p(lanes_p)
        ) int_vrf 
            (.clk_i         (clk_i)
            ,.reset_i       (reset_i)

            ,.r_reg0_addr_i (addrA_i)
            ,.r_reg1_addr_i (addrB_i)

            ,.r_addr_i      (r_addr_lo)
            ,.r0_data_o     (r0_data_li)
            ,.r1_data_o     (r1_data_li)

            ,.w_reg_addr_i  (addrC_i)

            ,.w_addr_i      (w_addr_lo)
            ,.w_data_i      (w_data_lo)
            ,.w_en_i        (w_en_lo)
        );

endmodule