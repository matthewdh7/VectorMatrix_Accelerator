
module multadd_tb;

    parameter vdw_p = 32;

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars();
    end

    /* Non-synth clock generator */
    logic clk_i;
    bsg_nonsynth_clock_gen #(10000) clk_gen_1 (clk_i);

    logic reset_i;

    logic signed [vdw_p-1:0] a_i, b_i, data_o;
    logic [1:0] alu_op_i;
    logic use_fma_i, fma_first_i;
    logic flag_overflow_o, flag_zero_o, flag_negative_o;

    multadd #(.vdw_p(vdw_p))
        dut
            (.*);

    initial begin
        a_i <= 'd0; b_i <= 'd0; alu_op_i <= 'd0; use_fma_i <= 0; fma_first_i <= 0; reset_i <= 1; @(posedge clk_i);
        reset_i <= 0; repeat(2) @(posedge clk_i);

        a_i <= 'd1; b_i <= 'd3; alu_op_i <= 'd0; repeat(2) @(posedge clk_i);
        $display("Output = %d", data_o); // 4

        a_i <= 'd10; b_i <= 'd2; alu_op_i <= 'd1; repeat(2) @(posedge clk_i);
        $display("Output = %d", data_o); // 8

        reset_i <= 1; @(posedge clk_i);
        reset_i <= 0; @(posedge clk_i);

        // simulate fma operation
        use_fma_i <= 1; fma_first_i <= 1;
        for (int i = 0; i < 4; i++) begin
            a_i <= 'd1; b_i <= i+1; @(posedge clk_i);
            fma_first_i <= 0;
            $display("Output = %d", data_o);
        end
        @(posedge clk_i);
        $display("Output = %d", data_o); // expected = 10

        a_i <= 'd7; b_i <= 'd3; alu_op_i <= 'd2; repeat(2) @(posedge clk_i);
        $display("Output = %d", data_o); // 21
        
        $finish;
    end

endmodule
