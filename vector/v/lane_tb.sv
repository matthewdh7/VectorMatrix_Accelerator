
module lane_tb;

    parameter els_p = 32;  // number of vectors stored
    parameter vlen_p = 8;  // number of elements per vector
    parameter vdw_p = 8;  // number of bits per element
    parameter lanes_p = 2; // also used as stride in local addr calculation
    parameter op_width_p = 4;
    localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p);
    localparam local_addr_width_lp = `BSG_SAFE_CLOG2(vlen_p);
    localparam num_cycles = vlen_p / lanes_p;

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk, reset;
    bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

    logic [op_width_p-1:0] op_i;
    logic start_i, v_o, w_en_o, done_o;
    logic [vdw_p-1:0] scalar_i, w_data_i, r_data_o, r0_data_i, r1_data_i, w_data_o;
    logic [local_addr_width_lp-1:0] r_addr_o, w_addr_o;

    lane   #(.els_p(els_p)
            ,.vlen_p(vlen_p)
            ,.vdw_p(vdw_p)
            ,.lanes_p(lanes_p)
            ,.op_width_p(op_width_p))
        dut
            (.clk_i     (clk)
            ,.reset_i   (reset)
            
            ,.my_id_i   (1'b0)

            ,.op_i      (op_i)
            ,.start_i   (start_i)

            ,.scalar_i  (scalar_i)
            ,.w_data_i  (w_data_i)
            ,.r_data_o  (r_data_o)
            ,.v_o       (v_o)
            ,.done_o    (done_o)

            // regfile connections, simulating in testbench
            ,.r_addr_o  (r_addr_o)
            ,.r0_data_i (r0_data_i)
            ,.r1_data_i (r1_data_i)

            ,.w_addr_o  (w_addr_o)
            ,.w_data_o  (w_data_o)
            ,.w_en_o    (w_en_o)
            );

    initial begin
        op_i <= 0; start_i <= 0; scalar_i <= 0; w_data_i <= 0; r0_data_i <= 0; r1_data_i <= 0; reset <= 1; @(posedge clk);
        reset <= 0; repeat(1) @(posedge clk);
        $display("================ STARTING TEST ================");
        read();
        $display("================ ENDING TEST ================");
        $finish;
    end

    task alu(input int use_scalar, op);
    begin
        if (use_scalar == 1)    op_i[3:2] = 2'b01;
        else                    op_i[3:2] = 2'b00;

        case (op)
            0: op_i[1:0] = 2'b00;
            1: op_i[1:0] = 2'b01;
            2: op_i[1:0] = 2'b10;
        endcase

        r0_data_i = $urandom_range(0, 0.5 * (2**vdw_p)-1);
        r1_data_i = $urandom_range(0, 0.5 * (2**vdw_p)-1);
        scalar_i = $urandom_range(0, 0.5 * (2**vdw_p)-1);
        w_data_i = 0;
        $display("scalar: 'h%h, data0: 'h%h, data1: 'h%h", scalar_i, r0_data_i, r1_data_i);
        
        @(posedge clk);
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        while(~done_o) begin
            // $display("scalar: 'h%h, data0: 'h%h, data1: 'h%h", scalar_i, r0_data_i, r1_data_i);
            $display("w_addr: %d, w_data: 'h%h, w_en: %b", w_addr_o, w_data_o, w_en_o);
            @(posedge clk);
        end
    end
    endtask

    // simulate writing of sequential data
    task write(input int write_data);
    begin
        op_i = 4'b1001;

        r0_data_i = 0;
        r1_data_i = 0;
        scalar_i = 0;
        w_data_i = write_data;
        
        @(posedge clk);
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        while(~done_o) begin
            w_data_i++;
            $display("w_addr: %d, w_data: 'h%h, w_en: %b", w_addr_o, w_data_o, w_en_o);
            @(posedge clk);
        end
    end
    endtask

    task read();
    begin
        op_i = 4'b1000;
        r0_data_i = 'h10;
        @(posedge clk);
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        while(~done_o) begin
            $display("r_addr_o: %d, v_o: %b", r_addr_o, v_o);
            @(posedge clk);
        end
    end
    endtask

endmodule
