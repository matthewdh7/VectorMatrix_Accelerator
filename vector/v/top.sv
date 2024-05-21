`include "bsg_defines.v"
module top      #( parameter els_p = 8  // number of vectors stored
                 , parameter vlen_p = 8  // number of elements per vector
                 , parameter vdw_p = 8  // number of bits per element
 
                 , parameter lanes_p = 4
 
                 , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
                 , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
                 , localparam addr_width_lp = v_addr_width_lp + local_addr_width_lp
                 , localparam els_per_lane_lp = vlen_p / vdw_p
                 , localparam vectors_per_lane_lp = vlen_p / lanes_p
                 , localparam counter_width_lp = `BSG_SAFE_CLOG2(els_per_lane_lp)
                 , localparam id_width_lp = `BSG_SAFE_CLOG2(lanes_p)
                )
    ( input clk_i
    , input reset_i

    // input interface
    , input logic [3:0] op_i

    , input logic [v_addr_width_lp-1:0] addrA_i // operand 1
    , input logic [v_addr_width_lp-1:0] addrB_i // operand 2
    , input logic [v_addr_width_lp-1:0] addrD_i // destination

    , input logic [vdw_p-1:0] scalar_i
    , input logic [(vlen_p * vdw_p)-1:0] w_data_i

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
    0011: multiply-add - UNUSED AFTER IMPLEMENTING M MUL
    0100: add v&s
    0101: sub v&s
    0110: mult v&s
    1000: read
    1001: write
    1111: matrix multiply
    */

    logic [lanes_p-1:0] v_lo, done_lo;
    logic [lanes_p-1:0][vdw_p-1:0] w_data_li, r_data_lo;
    logic [(vlen_p * vdw_p)-1:0] w_data_i_shift;
    logic [(lanes_p * vdw_p)-1:0] r_data_o_shift;
    logic start_li, start_n;
    logic [3:0] latch_op;

    logic [lanes_p-1:0][v_addr_width_lp-1:0] addrA_li, addrB_li, addrD_li;

    logic fma_counter_set_li, data_counter_set_li;
    logic [counter_width_lp-1:0] fma_count_lo, data_count_lo;

    //// state handler
    enum {s_IDLE, s_LOOP, s_FMA_START, s_FMA_LOOP, s_DONE} ps, ns;
    always_comb begin
        case(ps)
            s_IDLE:         ns = v_i ? ((op_i == 4'b1111) ? s_FMA_START : s_LOOP) : s_IDLE;
            s_LOOP:         ns = &done_lo ? s_DONE : s_LOOP;

            s_FMA_START:    ns = s_FMA_LOOP;
            s_FMA_LOOP:     ns = &done_lo ? (fma_count_lo == vectors_per_lane_lp - 1 ? s_DONE : s_FMA_START) : s_FMA_LOOP;

            s_DONE:         ns = (latch_op == 4'b1000) ? (yumi_i ? s_IDLE : s_DONE) : s_IDLE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i)    ps <= s_IDLE;
        else            ps <= ns;
    end

    assign start_n = (ps == s_IDLE & ns == s_LOOP) | ps == s_FMA_START;
    always_ff @(posedge clk_i) start_li <= start_n;

    assign fma_counter_set_li = ps == s_IDLE;

    bsg_counter_set_en #(.max_val_p(vectors_per_lane_lp-1))
        fma_cycle_counter
            (.clk_i     (clk_i)
            ,.reset_i   (reset_i)

            ,.set_i     (fma_counter_set_li)
            ,.en_i      (&done_lo) // if more v els than lanes, each lane needs to do multiple dot products to finish matrix
            ,.val_i     ('0)
            ,.count_o   (fma_count_lo)
            );

    //// convert external port read/write data to/from lane-usable read/write data
    genvar i;
    for (i = 0; i < lanes_p; i++) begin : lane_data_interface
        assign w_data_li[i] = w_data_i_shift[(i * vdw_p) +: vdw_p];
        assign r_data_o_shift[(i * vdw_p) +: vdw_p] = r_data_lo[i];
    end

    always_ff @(posedge clk_i) begin
        if (ps == s_IDLE) begin      
            w_data_i_shift <= w_data_i;
            r_data_o <= '0;
            latch_op <= op_i;
        end
        else if (ps == s_LOOP | ps == s_FMA_LOOP) begin
            if (&v_lo)
                r_data_o[(lanes_p*vdw_p)*data_count_lo +: (lanes_p*vdw_p)] <= r_data_o_shift;
            w_data_i_shift <= w_data_i_shift >> lanes_p * vdw_p;
        end    
    end

    assign data_counter_set_li = ps == s_IDLE;

    bsg_counter_set_en #(.max_val_p(2**counter_width_lp - 1))
        r_data_counter
            (.clk_i     (clk_i)
            ,.reset_i   (reset_i)

            ,.set_i     (data_counter_set_li)
            ,.en_i      (&v_lo & ps == s_LOOP)
            ,.val_i     ('0)
            ,.count_o   (data_count_lo)
            );

    //// lane address decode
    for (i = 0; i < lanes_p; i++) begin : lane_addresses
        assign addrA_li[i] = addrA_i;
        assign addrB_li[i] = (latch_op == 4'b1111) ? addrB_i + (v_addr_width_lp)'(i) + (fma_count_lo * lanes_p): addrB_i;
        assign addrD_li[i] = addrD_i;
    end

    //// lanes
    logic [lanes_p-1:0][local_addr_width_lp-1:0] r_addr_lo, w_addr_lo;
    logic [lanes_p-1:0][vdw_p-1:0] r0_data_li, r1_data_li, w_data_lo;
    logic [lanes_p-1:0] w_en_lo;

    // only used for dot product
    logic [local_addr_width_lp-1:0] w_addr_offset_li;
    assign w_addr_offset_li = (fma_count_lo * lanes_p);

    for (i = 0; i < lanes_p; i++) begin : lane
        lane #(.els_p(els_p)
                ,.vlen_p(vlen_p)
                ,.vdw_p(vdw_p)
                ,.lanes_p(lanes_p)
                ,.op_width_p(4))
            lane
                (.clk_i     (clk_i)
                ,.reset_i   (reset_i)
  
                ,.my_id_i   ((id_width_lp)'(i))

                ,.op_i      (op_i)
                ,.start_i   (start_li)

                ,.w_addr_offset_i (w_addr_offset_li)
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

    //// vrf
    vrf #(.els_p(els_p)
         ,.vlen_p(vlen_p)
         ,.vdw_p(vdw_p)
         ,.lanes_p(lanes_p)
        ) int_vrf 
            (.clk_i         (clk_i)
            ,.reset_i       (reset_i)

            ,.r_reg0_addr_i (addrA_li)
            ,.r_reg1_addr_i (addrB_li)

            ,.r_addr_i      (r_addr_lo)
            ,.r0_data_o     (r0_data_li)
            ,.r1_data_o     (r1_data_li)

            ,.w_reg_addr_i  (addrD_i)

            ,.w_addr_i      (w_addr_lo)
            ,.w_data_i      (w_data_lo)
            ,.w_en_i        (w_en_lo)
        );

    //// external output signals
    assign done_o = ps == s_DONE;
    assign ready_o = ps == s_IDLE;
    assign v_o = done_o;

endmodule