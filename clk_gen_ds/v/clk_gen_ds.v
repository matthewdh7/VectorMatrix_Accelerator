/**
 * Clock Generator with Downsampler -- Toplevel module.
 */
module clk_gen_ds
  ( input clk_reset_i     // Used for the clock generator only!
  , input ds_reset_i      // Used for the downsampler only!
  , input [7:0] select_i  // Lower 4 bits should control clkgen, upper 4 bits should control downsampler
  , output logic clk_o    // Should connect directly to the clkgen if the select is < 16, otherwise should output the downsampler
  );

  // Clock Generator instance
  // TODO: connect ports
  clk_gen CG (
     .reset_i(  )
    ,.select_i(  )
    ,.clk_o(  )
  );

  // TODO: Instantiate your downsampler here. Note the port
  // list above, make sure to connect everything up correctly.

endmodule

