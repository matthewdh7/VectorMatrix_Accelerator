`include "bsg_defines.v"

module lane #(parameter els_p = 32  // number of vectors stored
            , parameter vlen_p = 8  // number of elements per vector
            , parameter vdw_p = 32  // number of bits per element

            , parameter lanes_p = 4 // also used as stride in local addr calculation

            , parameter op_width_p = 4

            , localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
            , localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p)
            , localparam id_width_lp = `BSG_SAFE_CLOG2(lanes_p)

            , localparam counter_width_lp = `BSG_SAFE_CLOG2(vlen_p / lanes_p)
            , localparam counter_max_lp = (vlen_p / lanes_p) - 1
            )
    ( input  logic clk_i
    , input  logic reset_i
        
    , input  logic [id_width_lp-1:0] my_id_i

    , input  logic [op_width_p-1:0] op_i
    , input  logic start_i

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

    enum {s_IDLE, s_LOOP, s_DONE} ps, ns;

    //// next state logic
    always_comb begin
        case (ps)
            s_IDLE: ns = start_i ? s_LOOP : s_IDLE;
            s_LOOP: ns = (count_lo == counter_max_lp) ? s_DONE : s_LOOP;
            s_DONE: ns = s_IDLE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i)  ps <= s_IDLE;
        else          ps <= ns;
    end

    //// datapath 

    // REG/DECODE stage
    logic [local_addr_width_lp-1:0] REG_addr;
    logic [vdw_p-1:0] REG_w_data_ext;
    logic REG_w_en, REG_done;

    assign REG_addr = my_id_i + (lanes_p * count_lo);
    //assign REG_w_data_ext = w_data_i;
    assign REG_w_en = (op_i != 4'b1000) & (ps == s_LOOP);
    assign REG_done = ps == s_DONE;

    always_ff @(posedge clk_i) begin // latches write data at time of start assertion
        REG_w_data_ext <= w_data_i;        
    end

    // regfile stuff
    assign r_addr_o = REG_addr;
    assign r_data_o = r0_data_i;
    assign v_o = ps == s_LOOP;

    // EX stage
    logic [vdw_p-1:0] alu_a_li, alu_b_li, alu_result_lo, EX_r1_data, EX_scalar;
    logic [1:0] alu_op_li;
    logic [local_addr_width_lp-1:0] EX_w_addr;
    logic [vdw_p-1:0] EX_w_data_ext; // external write data, if opcode is a write
    logic EX_w_en, EX_done;

    always_ff @(posedge clk_i) begin
        alu_a_li <= r0_data_i;
        // alu_b_li handled by mux
        alu_op_li <= op_i[1:0];
        EX_w_addr <= REG_addr;
        EX_w_data_ext <= REG_w_data_ext;
        EX_w_en <= REG_w_en;
        EX_scalar <= scalar_i;
        EX_r1_data <= r1_data_i;
        EX_done <= REG_done;
    end

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        alu_b_mux
            (.data_i    ({EX_scalar, EX_r1_data})
            ,.sel_i     (op_i[2])
            ,.data_o    (alu_b_li)
            );

    // WB stage
    logic [local_addr_width_lp-1:0] WB_w_addr;
    logic [vdw_p-1:0] WB_w_data_ext, WB_w_data_alu, WB_w_data;
    logic WB_w_en, WB_done;

    always_ff @(posedge clk_i) begin
        WB_w_addr <= EX_w_addr;
        WB_w_data_ext <= EX_w_data_ext;
        WB_w_data_alu <= alu_result_lo;
        WB_w_en <= EX_w_en;
        WB_done <= EX_done;
    end

    bsg_mux    #(.width_p(vdw_p)
                ,.els_p(2))
        w_data_mux
            (.data_i    ({WB_w_data_ext, WB_w_data_alu})
            ,.sel_i     (op_i[3])
            ,.data_o    (WB_w_data)
            );

    // WB external outputs
    assign w_addr_o = WB_w_addr;
    assign w_data_o = WB_w_data;
    assign w_en_o = WB_w_en;


    assign counter_set_li = (ps == s_IDLE);
    assign counter_en_li = (ps == s_LOOP);

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
           ,.op_width_p(2))
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

    assign done_o = (op_i == 4'b1000) ? ps == s_DONE : WB_done;

endmodule
