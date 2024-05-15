`include "bsg_defines.v"
module top_tb;

    parameter els_p = 8;  // number of vectors stored
    parameter vlen_p = 4;  // number of elements per vector
    parameter vdw_p = 4;  // number of bits per element
    parameter lanes_p = 2; // also used as stride in local addr calculation
    localparam v_addr_width_lp = `BSG_SAFE_CLOG2(els_p);

    /* Dump Test Waveform To VPD File */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0);
    end

    /* Non-synth clock generator */
    logic clk, reset;
    bsg_nonsynth_clock_gen #(1000) clk_gen_1 (clk);

    logic [v_addr_width_lp-1:0] addrA_i, addrB_i, addrC_i;
    logic [vlen_p*vdw_p-1:0] w_data_i, r_data_o;
    logic v_i, ready_o, v_o, yumi_i, done_o;
    logic [vdw_p-1:0] scalar_i;
    logic [3:0] op_i;

    top     #(.els_p(els_p)
             ,.vlen_p(vlen_p)
             ,.vdw_p(vdw_p)
             ,.lanes_p(lanes_p))
        dut
            (.clk_i     (clk)
            ,.reset_i   (reset)

            // input interface
            ,.addrA_i   (addrA_i)
            ,.addrB_i   (addrB_i)
            ,.addrC_i   (addrC_i)
            ,.scalar_i  (scalar_i)
            ,.w_data_i  (w_data_i)
            ,.op_i      (op_i)
            ,.v_i       (v_i)
            ,.ready_o   (ready_o)

            // output interface
            ,.done_o    (done_o)
            ,.r_data_o  (r_data_o)
            ,.v_o       (v_o)
            ,.yumi_i    (yumi_i)
            );

    initial begin
        op_i <= '0; addrA_i <= '0; addrB_i <= '0; addrC_i <= '0; w_data_i <= '0; v_i <= 0; yumi_i <= 0; scalar_i <= '0; reset <= 1; @(posedge clk);
        reset <= 0; repeat(1) @(posedge clk);
        $display("================ STARTING TEST ================");
        // write(0, 16'b1111_0111_0011_0001);
        // @(posedge clk);
        // read(0);
        // write(2, 16'b0000_0010_0100_1000);
        // @(posedge clk);
        // read(2);
        // read(0);

        write(1, 16'b0000_0001_0000_0001);
        write(2, 16'b0001_0001_0100_0100);
        alu(0, 1, 2, 0, 0, 0); // add R0, R1, R2
        read(0); // expected 16'b0001_0010_0100_0101 - YES

        alu(1, 2, 1, 3, 0, 0); // sub R3, R2, R1
        read(3); // expected 16'b0001_0000_0100_0011 - YES

        alu(2, 1, 3, 5, 0, 0); // mul R5, R1, R3
        read(5); // expected 16'b0000_0000_0000_0011 - YES
        $display("================ ENDING TEST ================");
        $finish;
    end

    task write(input int addr, w_data);
    begin
        op_i = 4'b1001; w_data_i = w_data; v_i = 1; addrC_i = addr;
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

    task alu(input int op, addr1, addr2, addrOut, use_scalar, scalar);
    begin
        @(posedge clk);
        op_i[3:2] = (use_scalar == 1) ? 2'b01 : 2'b00;
        case (op)
            /*add*/ 0: op_i[1:0] = 2'b00;
            /*sub*/ 1: op_i[1:0] = 2'b01;
            /*mul*/ 2: op_i[1:0] = 2'b10;
        endcase

        addrA_i = addr1; addrB_i = addr2; addrC_i = addrOut; v_i = 1;
        @(posedge clk);
        v_i = 0;
        while(~done_o) begin
            $display("alu operation busy...");
            @(posedge clk);
        end
    end
    endtask

endmodule
