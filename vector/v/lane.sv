`include "bsg_defines.v"

module lane #(parameter els_p = 32  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 32  // number of bits per element

            , parameter lanes_p = 4 // also used as stride in local addr calculation

            , parameter op_width_p = 3;

            , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
            , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            , localparam id_width_lp = `BSG_SAFE_CLOG2(lanes_p)

            , localparam counter_width_lp = `BSG_SAFE_CLOG2(vlen_p / lanes_p)
            , localparam counter_max_lp = (vlen_p / lanes_p) - 1;
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [id_width_lp-1:0] my_id_i

    , input  logic [op_width_p-1:0] op_i
    , input  logic start_i

    , input  logic [vdw_p-1:0] scalar_i

    , output logic [vdw_p-1:0] r_data_o
    , output logic v_o

    // regfile connections
    , output logic [local_addr_width_lp-1:0] r_addr_o
    , input  logic [vdw_p-1:0] r0_data_i
    , input  logic [vdw_p-1:0] r1_data_i

    , output logic [local_addr_width_lp-1:0] w_addr_o
    , output logic [vdw_p-1:0] w_data_o
    , output logic w_en_o
    );

    enum {s_IDLE, s_LOOP, s_DONE} ps, ns;

    // // datapath
    // logic [vdw_p-1:0] scalar_li, , alu_result_lo; 
    // logic [op_width_p-1:0] alu_op_li;
    // logic [counter_width_lp-1:0] count_lo;

    // logic [local_addr_width_lp-1:0] r_addr_lo;

    // // control
    // logic counter_en_li, init;

    // next state logic
    always_comb begin
        case (ps)
            s_IDLE: ns = start ? s_LOOP : s_IDLE;
            s_LOOP: ns = (count_lo == counter_max_lp) ? s_DONE : s_LOOP;
            s_DONE: ns = s_IDLE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset)  ps <= s_IDLE;
        else        ps <= ns;
    end

    // REG/DECODE stage
    // should be all external inputs

    // EX stage
    logic [vdw_p-1:0] alu_a_li, alu_b_li, alu_result_lo;
    logic [op_width_p-1:0] alu_op_li;
    logic [local_addr_width_lp-1:0] EX_w_addr;
    logic [vdw_p-1:0] EX_w_data_ext; // external write data, if opcode is a write
    logic EX_w_en;

    always_ff @(posedge clk_i) begin
        alu_a_li <= 
        alu_b_li <=
        EX_w_addr <=
        EX_w_data_ext <= 
        EX_w_en <= 
    end

    // WB stage
    logic [local_addr_width_lp-1:0] WB_w_addr;
    logic [vdw_p-1:0] WB_w_data_ext, WB_w_data_alu, WB_w_data;
    logic WB_w_en;

    bsg_counter_set_en #(.max_val_p(counter_max_lp))
        addr_counter
            (.clk_i     (clk_i)
            ,.reset_i   (reset_i)

            ,.set_i     (counter_set_li)
            ,.en_i      (counter_en_li)
            ,.val_i     ('0)
            ,.count_o   (count_lo)
            );


    alu   #(.vdw_p(vdw_p)
           ,.op_width_p(op_width_p))
        alu
            (.clk_i     (clk_i)  
            ,.reset_i   (reset_i)

            ,.a_i       (alu_a_li)
            ,.b_i       (alu_b_li)
            ,.op_i      (alu_op_li)

            ,.result_o  (alu_result_lo)

            ,.flag_overflow_o   ()
            ,.flag_zero_o       ()
            ,.flag_negative_o   ()
            );

endmodule
