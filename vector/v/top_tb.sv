`include "bsg_defines.v"
module top_tb;

    // unused
    parameter els_p = 12;   // number of vectors stored
    parameter vlen_p = 4;   // number of elements per vector
    parameter vdw_p = 6;    // number of bits per element
    parameter lanes_p = 2;  // also used as stride in local addr calculation
    localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p);

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk_i, reset_i;
    bsg_nonsynth_clock_gen #(10) clk_gen_1 (clk_i);

    logic [v_addr_width_lp-1:0] addrA_i, addrB_i, addrD_i;
    logic [vlen_p*vdw_p-1:0] w_data_i, r_data_o;
    logic v_i, ready_o, v_o, yumi_i, done_o;
    logic [vdw_p-1:0] scalar_i;
    logic [3:0] op_i;
    logic [v_addr_width_lp-1:0] fma_cycles_i;

    top // use top default parameters
        dut
            (.clk_i         (clk_i)
            ,.reset_i       (reset_i)

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
        op_i <= '0; addrA_i <= '0; addrB_i <= '0; addrD_i <= '0; w_data_i <= '0; v_i <= 0; yumi_i <= 0; scalar_i <= '0; reset_i <= 1; repeat(5) @(posedge clk_i);
        reset_i <= 0; repeat(1) @(posedge clk_i);
        $display("================ STARTING TEST ================");

        /*
        1 1 1 1     1 3 1 3     8  8  7  6
        1 2 1 2  *  3 2 2 1  =  12 12 12 8
        2 1 2 1     3 1 1 1     12 12 9  10
        1 2 2 1     1 2 3 1     14 11 10 8
        */
        /* vector storage (how its represented in the regfile for the hardware):
        1 1 1 1     1 3 3 1     
        1 2 1 2     3 2 1 2
        2 1 2 1     1 2 1 3
        1 2 2 1     3 1 1 1
        */
        $display($time);
        write(0, 32'b00000001_00000001_00000001_00000001); // 1 1 1 1 
        write(1, 32'b00000001_00000010_00000001_00000010); // 1 2 1 2
        write(2, 32'b00000010_00000001_00000010_00000001); // 2 1 2 1
        write(3, 32'b00000001_00000010_00000010_00000001); // 1 2 2 1

        write(4, 32'b00000001_00000011_00000011_00000001); // 1 3 3 1
        write(5, 32'b00000011_00000010_00000001_00000010); // 3 2 1 2
        write(6, 32'b00000001_00000010_00000001_00000011); // 1 2 1 3
        write(7, 32'b00000011_00000001_00000001_00000001); // 3 1 1 1

        $display($time);
        mmul(8, 0, 4);
        $display($time);
        readMatrix(8);
        $display($time);
 
        $display("================ ENDING TEST ================");
        $finish;
    end

    //// TASKS ////
    
    task write(input int addr, w_data);
    begin
        op_i = 4'b1001; w_data_i = w_data; v_i = 1; addrD_i = addr;
        @(posedge clk_i);
        v_i = 0;
        $write("writing...");
        while(~done_o) @(posedge clk_i);
        $display(" -done writing");
    end
    endtask

    task read(input int addr);
    begin
        op_i = 4'b1000; v_i = 1; addrA_i = addr;
        @(posedge clk_i);
        v_i = 0; yumi_i = 1;
        while(~done_o) @(posedge clk_i);

        $display("-r_data_o: %b", r_data_o);
        @(posedge clk_i);
        yumi_i = 0;
    end
    endtask

    task readMatrix(input int addr);
    begin
        op_i = 4'b1000;
        $display("-r_data_o for matrix:");
        for (int i = 0; i < 4; i++) begin
            v_i = 1; addrA_i = addr + i;
            @(posedge clk_i);
            v_i = 0; yumi_i = 1;
            while(~done_o) @(posedge clk_i);

            $display("%d %d %d %d", r_data_o[3*vdw_p +: vdw_p], r_data_o[2*vdw_p +: vdw_p], r_data_o[vdw_p +: vdw_p], r_data_o[0 +: vdw_p]);
            @(posedge clk_i);
            yumi_i = 0;
        end
    end
    endtask

    task alu(input int op, addrOut, addr1, addr2, use_scalar, scalar);
    begin
        @(posedge clk_i);
        op_i[3:2] = (use_scalar == 1) ? 2'b01 : 2'b00;
        case (op)
            /*add*/ 0: op_i[1:0] = 2'b00;
            /*sub*/ 1: op_i[1:0] = 2'b01;
            /*mul*/ 2: op_i[1:0] = 2'b10;
        endcase

        addrA_i = addr1; addrB_i = addr2; addrD_i = addrOut; v_i = 1; scalar_i = scalar;
        @(posedge clk_i);
        v_i = 0;

        $display("alu operation start at %t", $time);
        while(~done_o) @(posedge clk_i);
        $display("alu operation done at  %t", $time);
    end
    endtask

    task mmul(input int addrOut, addr1, addr2);
    begin
        @(posedge clk_i);
        op_i = 4'b1111; addrA_i = addr1; addrB_i = addr2; addrD_i = addrOut; v_i = 1;
        @(posedge clk_i);
        v_i = 0;

        $display("dot product start at %t", $time);
        while(~done_o) @(posedge clk_i);
        $display("dot product done at  %t", $time);
    end
    endtask

endmodule
