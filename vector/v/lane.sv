`include "bsg_defines.v"

module lane #(parameter els_p = 8  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 8  // number of bits per element

            , parameter lanes_p = 4 // also used as stride in local addr calculation

            , parameter op_width_p = 4

            , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
            , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            , localparam id_width_lp = `BSG_SAFE_CLOG2(lanes_p)

            , localparam counter_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [id_width_lp-1:0] my_id_i

    , input  logic [op_width_p-1:0] op_i
    , input  logic start_i

    , input  logic [local_addr_width_lp-1:0] w_addr_offset_i // used for fma operations
    , input  logic [vdw_p-1:0] scalar_i
    , input  logic [vdw_p-1:0] w_data_i
    , output logic [vdw_p-1:0] r_data_o
    , output logic v_o
    , output logic done_o

    // regfile connections
    , output logic [local_addr_width_lp-1:0] r_addr_o
    , input  logic [vdw_p-1:0] r0_data_i
    , input  logic [vdw_p-1:0] r1_data_i

    , output logic [local_addr_width_lp-1:0] w_addr_o
    , output logic [vdw_p-1:0] w_data_o
    , output logic w_en_o
    );

    //// counter definitions
    logic [counter_width_lp-1:0] count_lo;
    logic counter_set_li, counter_en_li; 

    logic [counter_width_lp-1:0] counter_max;
    assign counter_max = (counter_width_lp)'((op_i == 4'b1111) ? vlen_p - 1 : (vlen_p / lanes_p) - 1);

    enum {s_IDLE, s_LOOP, s_DONE} ps, ns;

    //// next state logic
    always_comb begin
        case (ps)
            s_IDLE: ns = start_i ? s_LOOP : s_IDLE;
            s_LOOP: ns = (count_lo == counter_max) ? s_DONE : s_LOOP;
            s_DONE: ns = s_IDLE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i)  ps <= s_IDLE;
        else          ps <= ns;
    end

    //// ==== DATAPATH ====

    //// REG/DECODE stage
    logic [local_addr_width_lp-1:0] REG_normal_rd_addr, REG_fma_rd_addr, REG_r_addr, REG_w_addr;
    logic [vdw_p-1:0] REG_w_data_ext, REG_scalar;
    logic [1:0] REG_alu_op;
    logic REG_w_en, REG_done, REG_w_use_ext, REG_use_fma, REG_fma_start;
    logic REG_use_scalar;

    assign REG_normal_rd_addr = my_id_i + (lanes_p * count_lo);
    assign REG_fma_rd_addr = count_lo;
    assign REG_r_addr = (op_i == 4'b1111) ? REG_fma_rd_addr : REG_normal_rd_addr;
    assign REG_w_addr = (op_i == 4'b1111) ? (local_addr_width_lp)'(my_id_i) + w_addr_offset_i : REG_normal_rd_addr;
    // write if not read operation AND if not fma operation (unless on the final accumulation)
    assign REG_w_en = (ps == s_LOOP) & ((op_i == 4'b1111) ? 
                                        (count_lo == counter_max) :
                                        (op_i != 4'b1000));
    assign REG_done = ps == s_DONE;
    assign REG_use_w_ext = op_i == 4'b1001;
    assign REG_use_fma = &op_i;
    // assign REG_w_data_src = &op_i; // = op_i == 4'b1111
    assign REG_alu_op = op_i[1:0];
    assign REG_fma_start = count_lo == 1'b0;
    assign REG_use_scalar = op_i[2] & (op_i != 4'b1111);
    assign REG_scalar = scalar_i;

    always_ff @(posedge clk_i) begin // latches write data at time of start assertion
        REG_w_data_ext <= w_data_i;        
    end

    // regfile stuff
    assign r_addr_o = REG_r_addr;
    assign r_data_o = r0_data_i;
    assign v_o = ps == s_LOOP; // only used for read operations, which are ready instantly (don't need pipeline)

    //// EX stage
    // multadd unit signals
    logic [vdw_p-1:0] EX_a_li, EX_b_li, multadd_a_li, multadd_b_li, EX_scalar;
    logic [1:0] EX_alu_op_li;
    logic EX_use_fma_li, EX_fma_first_li;
    // passthrough pipeline signals
    logic [local_addr_width_lp-1:0] EX_w_addr;
    logic [vdw_p-1:0] EX_w_data_ext;
    logic EX_w_en, EX_done, EX_use_w_ext, EX_use_scalar;

    always_ff @(posedge clk_i) begin
        EX_a_li <= r0_data_i;
        EX_b_li <= r1_data_i;
        EX_alu_op_li <= REG_alu_op;
        EX_use_fma_li <= REG_use_fma;
        EX_fma_first_li <= REG_fma_start;
        EX_w_addr <= REG_w_addr;
        EX_w_data_ext <= REG_w_data_ext;
        EX_w_en <= REG_w_en;
        EX_done <= REG_done;
        EX_use_w_ext <= REG_use_w_ext;
        EX_scalar <= REG_scalar;
        EX_use_scalar <= REG_use_scalar;
    end

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        alu_b_mux
            (.data_i    ({EX_scalar, EX_b_li})
            ,.sel_i     (EX_use_scalar)
            ,.data_o    (multadd_b_li)
            );

    assign multadd_a_li = EX_a_li;

    //// WB stage
    logic [vdw_p-1:0] WB_data_lo; // from multadd unit
    logic [vdw_p-1:0] WB_w_data;
    logic [local_addr_width_lp-1:0] WB_w_addr;
    logic [vdw_p-1:0] WB_w_data_ext;
    logic WB_w_en, WB_done, WB_use_w_ext;

    always_ff @(posedge clk_i) begin
        WB_w_addr <= EX_w_addr;
        WB_w_data_ext <= EX_w_data_ext;
        WB_w_en <= EX_w_en;
        WB_done <= EX_done;
        WB_use_w_ext <= EX_use_w_ext;
    end

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        w_data_mux
            (.data_i    ({WB_w_data_ext, WB_data_lo})
            ,.sel_i     (WB_use_w_ext)
            ,.data_o    (WB_w_data)
            );

    // WB external outputs
    assign w_addr_o = WB_w_addr;
    assign w_data_o = WB_w_data;
    assign w_en_o = WB_w_en;

    assign counter_set_li = (ps == s_IDLE);
    assign counter_en_li = (ps == s_LOOP);

    bsg_counter_set_en #(.max_val_p(2**counter_width_lp - 1))
        addr_counter
            (.clk_i     (clk_i)
            ,.reset_i   (reset_i)

            ,.set_i     (counter_set_li)
            ,.en_i      (counter_en_li)
            ,.val_i     ('0)
            ,.count_o   (count_lo)
            );


    multadd #(.vdw_p(vdw_p))
        exe_unit
            (.clk_i         (clk_i)
            ,.reset_i       (reset_i)

            ,.a_i           (multadd_a_li)
            ,.b_i           (multadd_b_li)
            ,.alu_op_i      (EX_alu_op_li)
            ,.use_fma_i     (EX_use_fma_li)
            ,.fma_first_i   (EX_fma_first_li)

            ,.data_o        (WB_data_lo)

            ,.flag_overflow_o   ()
            ,.flag_zero_o       ()
            ,.flag_negative_o   ()
            );


    assign done_o = (op_i == 4'b1000) ? ps == s_DONE : WB_done;

endmodule
