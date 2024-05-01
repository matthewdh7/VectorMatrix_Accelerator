`include "bsg_defines.v"
module demux   #( parameter data_width_p = -1
                , parameter num_outputs_p = -1

                , localparam sel_width_lp = `BSG_SAFE_CLOG2(num_outputs_p)
                )
    ( input  logic [data_width_p-1:0] in
    , input  logic [sel_width_lp-1:0] sel_i 

    , output logic [num_outputs_p-1:0][data_width_p-1:0] out
    );

    for (genvar i = 0; i < num_outputs_p; i++) begin : out
        assign out[i] = (sel_i == i) ? in : '0;
    end

endmodule