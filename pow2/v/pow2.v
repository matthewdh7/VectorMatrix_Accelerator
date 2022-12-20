module pow2
  ( input               clk_i
  , input               reset_i

  , input        [31:0] exp_i
  , input               v_i
  , output              ready_o

  , output logic [31:0] data_o
  , output logic        v_o
  , input               yumi_i
  );

  typedef enum logic [1:0] {eWAIT, eBUSY, eDONE} state_e;

  state_e  state_n, state_r;

  logic [31:0] exp_n, exp_r;
  logic [31:0] data_n, data_r;

  assign ready_o = state_r == eWAIT;
  assign     v_o = state_r == eDONE;

  always_comb
    begin
      state_n = state_r;
      if (ready_o & v_i) begin
        state_n = eBUSY;
      end else if ((state_r == eBUSY) & (exp_n == 32'b0)) begin
        state_n = eDONE;
      end else if (v_o & yumi_i) begin
        state_n = eWAIT;
      end
    end

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
          state_r <= eWAIT;
      else
          state_r <= state_n;
    end

  assign exp_n = (ready_o & v_i) ? exp_i : 
                    (state_r == eBUSY) ? exp_r - 1'b1 : exp_r;

  assign data_n = (ready_o & v_i) ? 32'b1 :
                    (state_r == eBUSY) ? data_r * 2 : data_r;

  always_ff @(posedge clk_i)
    begin
      exp_r  <= exp_n;
      data_r <= data_n;
    end

  assign data_o = data_r;

endmodule

