// clk_gen_ds_tb.v
//
// This file contains the toplevel testbench for testing
// this design. 
//

module clk_gen_ds_tb;

  /* Dump Test Waveform To VPD File */
  initial begin
    $vcdpluson;
    $vcdplusmemon;
    $vcdplusautoflushon;
  end

  /* Non-synth clock generator */
  logic clk;
  bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

  /* Non-synth reset generators */
  logic cg_reset;
  bsg_nonsynth_reset_gen #(.num_clocks_p(1),.reset_cycles_lo_p(5),. reset_cycles_hi_p(5))
    reset_gen
      (.clk_i        ( clk )
      ,.async_reset_o( cg_reset )
      );

  logic ds_reset;
  bsg_nonsynth_reset_gen #(.num_clocks_p(1),.reset_cycles_lo_p(10),. reset_cycles_hi_p(15))
    ds_reset_gen
      (.clk_i        ( clk )
      ,.async_reset_o( ds_reset )
      );

  /* Device under test (DUT) */

  logic [7:0] dut_cfg;
  logic       dut_clk;

  clk_gen_ds DUT
    (.select_i(dut_cfg)
    ,.clk_reset_i(cg_reset)
    ,.ds_reset_i(ds_reset)
    ,.clk_o(dut_clk)
    );

  /* Reports Clock Period and Changes */
  bsg_nonsynth_clk_watcher #(.tolerance_p(0)) clk_watcher (.clk_i(dut_clk));

  /* Sequential steps to test the DUT */
  initial begin

    for (integer i = 0; i < 2**$bits(dut_cfg); i++) begin
        dut_cfg   = i;
        #1000
        $display("### START TESTING CONFIG %b", dut_cfg);
        for (integer j = 0; j < 25; j++) begin
            @(posedge dut_clk);
        end
        #1000
        $display("### FINISH TESTING CONFIG %b", dut_cfg);
    end

    $finish();

  end

endmodule
