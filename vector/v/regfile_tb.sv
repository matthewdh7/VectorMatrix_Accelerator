
module regfile_tb;

    parameter els_p = 4;
    parameter vlen_p = 4;
    parameter vdw_p = 32;
    parameter lanes_p = 2;
    localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p);
    localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p);

    /* Dump Test Waveform To VPD File */
    initial begin
        // $fsdbDumpfile("waveform.fsdb");
        // $fsdbDumpvars(0);
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk, reset;
    bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

    logic [v_addr_width_lp-1:0] r_reg0_addr_i, r_reg1_addr_i, w_reg_addr_i; // select which register to operate
    logic [lanes_p-1:0][local_addr_width_lp-1:0] r_addr_i, w_addr_i; // select what element within the register
    logic [lanes_p-1:0][vdw_p-1:0] r0_data_o, r1_data_o, w_data_i;
    logic [lanes_p-1:0] w_en_i;

    vrf    #(.els_p(els_p) 
            ,.vlen_p(vlen_p)
            ,.vdw_p(vdw_p)  
            ,.lanes_p(lanes_p))
        dut
            (.clk_i     (clk)
            ,.reset_i   (reset)

            ,.r_reg0_addr_i (r_reg0_addr_i)
            ,.r_reg1_addr_i (r_reg1_addr_i)

            ,.r_addr_i  (r_addr_i)
            ,.r0_data_o (r0_data_o)
            ,.r1_data_o (r1_data_o)

            ,.w_reg_addr_i (w_reg_addr_i)

            ,.w_addr_i  (w_addr_i)
            ,.w_data_i  (w_data_i)
            ,.w_en_i    (w_en_i)
            );

    initial begin
        $display("================ STARTING TEST ================");
        r_reg0_addr_i <= 'd0; r_reg1_addr_i <= 'd0; r_addr_i <= 'd0; w_reg_addr_i <= 'd0; w_addr_i <= 'd0; w_data_i <= 'd0; w_en_i <= 0; reset <= 1; @(posedge clk);
        reset <= 0; repeat(2) @(posedge clk);

        // write(0, 0, 0, 100);
        // write(0, 1, 0, 101);

        // @(posedge clk);

        // read(0, 0, 0, 0, 100);
        // read(0, 1, 1, 0, 101);

        repeat(10) randomTest(/*seed*/);

        $display("================ ENDING TEST ================");
        $finish;
    end



    task randomTest();
    begin
        int lane, v_reg, local_addr, data;
        v_reg = $urandom_range(0, els_p-1);
        local_addr = $urandom_range(0, vlen_p-1);
        lane = local_addr % lanes_p;
        data = $urandom_range(0, (2**vdw_p)-1);

        $display("Running random test. Lane = %d, Reg = %d, Addr = %d, Data = 'h%h", lane, v_reg, local_addr, data);

        write(lane, v_reg, local_addr, data);
        read(lane, $urandom_range(1), v_reg, local_addr, data);
    end
    endtask

    task write(input int lane, w_reg_addr, w_addr, w_data);
    begin
        @(posedge clk);
        w_en_i[lane] = 1;
        w_reg_addr_i = w_reg_addr;
        w_addr_i[lane] = w_addr;
        w_data_i[lane] = w_data;

        @(posedge clk);
        w_en_i[lane] = 0;
    end
    endtask

    task read(input int lane, r_port, r_reg_addr, r_addr, r_data);
    begin
        r_addr_i[lane] = r_addr;
        if (r_port) r_reg1_addr_i = r_reg_addr;
        else        r_reg0_addr_i = r_reg_addr;

        @(posedge clk);

        if (r_port) assert(r1_data_o[lane] == r_data) else $error("output = %d, expected = %d", r1_data_o[lane], r_data);
        else        assert(r0_data_o[lane] == r_data) else $error("output = %d, expected = %d", r0_data_o[lane], r_data);

        @(posedge clk);
    end
    endtask


endmodule
