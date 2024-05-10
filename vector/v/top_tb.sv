
module top_tb;

    parameter els_p = 32;  // number of vectors stored
    parameter vlen_p = 8;  // number of elements per vector
    parameter vdw_p = 8;  // number of bits per element
    parameter lanes_p = 2; // also used as stride in local addr calculation

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk, reset;
    bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

    top     #(.els_p(els_p)
             ,.vlen_p(vlen_p)
             ,.vdw_p(vdw_p)
             ,.lanes_p(lanes_p))
        dut
            (.clk_i     (clk)
            ,.reset_i   (reset)

            // input interface
            ,.addrA_i   ()
            ,.addrB_i   ()
            ,.addrC_i   ()
            ,.scalar_i  ()
            ,.w_data_i  ()
            ,.op_i      ()
            ,.v_i       ()
            ,.ready_o   ()

            // output interface
            ,.done_o    ()
            ,.r_data_o  ()
            ,.v_o       ()
            ,.yumi_i    ()
            );

    initial begin
        reset <= 1; @(posedge clk);
        reset <= 0; repeat(1) @(posedge clk);
        $display("================ STARTING TEST ================");
        
        $display("================ ENDING TEST ================");
        $finish;
    end

endmodule
