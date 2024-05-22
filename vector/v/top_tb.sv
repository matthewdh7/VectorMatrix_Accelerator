`include "bsg_defines.v"
module top_tb;

    parameter els_p = 12;  // number of vectors stored
    parameter vlen_p = 2;  // number of elements per vector
    parameter vdw_p = 4;  // number of bits per element
    parameter lanes_p = 1; // also used as stride in local addr calculation
    localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p);

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk, reset;
    bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

    logic [v_addr_width_lp-1:0] addrA_i, addrB_i, addrD_i;
    logic [vlen_p*vdw_p-1:0] w_data_i, r_data_o;
    logic v_i, ready_o, v_o, yumi_i, done_o;
    logic [vdw_p-1:0] scalar_i;
    logic [3:0] op_i;
    logic [v_addr_width_lp-1:0] fma_cycles_i;

    top     #(.els_p(els_p)
             ,.vlen_p(vlen_p)
             ,.vdw_p(vdw_p)
             ,.lanes_p(lanes_p))
        dut
            (.clk_i         (clk)
            ,.reset_i       (reset)

            // input interface
            ,.op_i          (op_i)

            ,.addrA_i       (addrA_i)
            ,.addrB_i       (addrB_i)
            ,.addrD_i       (addrD_i)

            ,.scalar_i      (scalar_i)
            ,.w_data_i      (w_data_i)
            
            ,.v_i           (v_i)
            ,.ready_o       (ready_o)

            // output interface
            ,.done_o        (done_o)
            ,.r_data_o      (r_data_o)
            ,.v_o           (v_o)
            ,.yumi_i        (yumi_i)
            );

    initial begin
        op_i <= '0; addrA_i <= '0; addrB_i <= '0; addrD_i <= '0; w_data_i <= '0; v_i <= 0; yumi_i <= 0; scalar_i <= '0; reset <= 1; @(posedge clk);
        reset <= 0; repeat(1) @(posedge clk);
        $display("================ STARTING TEST ================");

        // /* 
        // 1 1 1 1     1 2 3 4     8  12 10 10
        // 2 2 2 2  x  4 3 2 1  =  16 24 20 20
        // 3 3 3 3     1 3 1 3     24 36 30 30
        // 1 2 3 4     2 4 4 2     20 33 26 23
        // */
        // write(0, 24'b000001_000001_000001_000001); // 1 1 1 1
        // write(1, 24'b000010_000010_000010_000010); // 2 2 2 2
        // write(2, 24'b000011_000011_000011_000011); // 3 3 3 3
        // write(3, 24'b000001_000010_000011_000100); // 1 2 3 4

        // // this matrix is already transposed before storing
        // write(4, 24'b000001_000100_000001_000010); // 1 4 1 2
        // write(5, 24'b000010_000011_000011_000100); // 2 3 3 4
        // write(6, 24'b000011_000010_000001_000100); // 3 2 1 4
        // write(7, 24'b000100_000001_000011_000010); // 4 1 3 2

        // repeat(5) @(posedge clk); // to make it easier to identify break in waveform

        // mmul(8, 0, 4);
        // read(8); // expect  001000_001100_001010_001010
        // read(9); //         010000_011000_010100_010100
        // read(10); //        011000_100100_011110_011110
        // read(11); //        010100_100001_011010_010111

        write(0, 8'b0001_0001);
        write(1, 8'b0010_0010);

        write(2, 8'b0001_0100);
        write(3, 8'b0011_0010);

        read(0);
        read(2);

        mmul(4, 0, 2);
        read(4);
        read(5);
        
 
        $display("================ ENDING TEST ================");
        $finish;
    end

    task write(input int addr, w_data);
    begin
        op_i = 4'b1001; w_data_i = w_data; v_i = 1; addrD_i = addr;
        @(posedge clk);
        v_i = 0;
        $display("writing...");
        while(~done_o) @(posedge clk);
        $display("--done writing");
    end
    endtask

    task read(input int addr);
    begin
        op_i = 4'b1000; v_i = 1; addrA_i = addr;
        @(posedge clk);
        v_i = 0; yumi_i = 1;
        while(~done_o) @(posedge clk);

        $display("--r_data_o: %b", r_data_o);
        @(posedge clk);
        yumi_i = 0;
    end
    endtask

    task alu(input int op, addrOut, addr1, addr2, use_scalar, scalar);
    begin
        @(posedge clk);
        op_i[3:2] = (use_scalar == 1) ? 2'b01 : 2'b00;
        case (op)
            /*add*/ 0: op_i[1:0] = 2'b00;
            /*sub*/ 1: op_i[1:0] = 2'b01;
            /*mul*/ 2: op_i[1:0] = 2'b10;
        endcase

        addrA_i = addr1; addrB_i = addr2; addrD_i = addrOut; v_i = 1; scalar_i = scalar;
        @(posedge clk);
        v_i = 0;
        while(~done_o) begin
            $display("alu operation busy...");
            @(posedge clk);
        end
    end
    endtask

    task mmul(input int addrOut, addr1, addr2);
    begin
        @(posedge clk);
        op_i = 4'b1111; addrA_i = addr1; addrB_i = addr2; addrD_i = addrOut; v_i = 1;
        @(posedge clk);
        v_i = 0;
        while(~done_o) begin
            $display("dot product working...");
            @(posedge clk);
        end
    end
    endtask

endmodule
