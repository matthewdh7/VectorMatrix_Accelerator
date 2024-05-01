
module alu_tb;

    parameter vdw_p = 32;
    parameter op_len_p = 2;

    /* Dump Test Waveform To VPD File */
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars();
    end

    /* Non-synth clock generator */
    logic clk;
    bsg_nonsynth_clock_gen #(10000) clk_gen_1 (clk);

    logic reset;

    logic signed [vdw_p-1:0] a, b, out;
    logic [op_len_p-1:0] op;
    logic flag_overflow, flag_zero, flag_negative;

    alu #(.vdw_p(vdw_p)
         ,.op_len_p(op_len_p))
        dut
            (.clk_i     (clk)
            ,.reset_i   (reset)

            ,.a_i       (a)
            ,.b_i       (b)
            ,.op_i      (op)

            ,.result_o  (out)

            ,.flag_overflow_o   (flag_overflow)
            ,.flag_zero_o       (flag_zero)
            ,.flag_negative_o   (flag_negative)
            );

    initial begin
        a <= 'd0; b <= 'd0; op <= 'd0; reset <= 1; @(posedge clk);
        reset <= 0; repeat(2) @(posedge clk);

        $display("Output = %d", out); // 0

        a <= 'd1; b <= 'd1; op <= 'd0; @(posedge clk);
        $display("Output = %d", out); // 2

        a <= 'd2; b <= 'd2; op <= 'd0; @(posedge clk);
        $display("Output = %d", out); // 4

        a <= 'd3; b <= 'd3; op <= 'd2; @(posedge clk);
        $display("Output = %d", out); // 9

        a <= 'd11; b <= 'd4; op <= 'd2; @(posedge clk);
        $display("Output = %d", out); // 44

        a <= 'd10; b <= 'd8; op <= 'd1; @(posedge clk);
        $display("Output = %d", out); // 2

        a <= 'd4; b <= 'd10; op <= 'd1; @(posedge clk);
        $display("Output = %d", out); // -6

        $finish;
    end

endmodule
