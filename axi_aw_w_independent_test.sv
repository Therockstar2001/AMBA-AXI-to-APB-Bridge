`timescale 1ns/1ps

module axi_aw_w_independent_test;

    logic [31:0] rdata;

    axi_env_tb env();

    initial begin

        wait (env.ARESETn == 1'b1);

        $display("AXI INDEPENDENT AW/W TEST START");

        // --------------------------------------------------------
        // AW first, W later
        // --------------------------------------------------------
        env.do_write_skew(
            32'h0000_0000,
            32'h1111_AAAA,
            0,
            3
        );

        env.do_read(32'h0000_0000, rdata);

        if (rdata !== 32'h1111_AAAA)
            $error("AW-first write failed");

        // --------------------------------------------------------
        // W first, AW later
        // --------------------------------------------------------
        env.do_write_skew(
            32'h0000_0004,
            32'h2222_BBBB,
            3,
            0
        );

        env.do_read(32'h0000_0004, rdata);

        if (rdata !== 32'h2222_BBBB)
            $error("W-first write failed");

        // --------------------------------------------------------
        // AW and W together
        // --------------------------------------------------------
        env.do_write_skew(
            32'h0000_0008,
            32'h3333_CCCC,
            0,
            0
        );

        env.do_read(32'h0000_0008, rdata);

        if (rdata !== 32'h3333_CCCC)
            $error("Simultaneous AW/W write failed");

        repeat (10)
            @(posedge env.ACLK);

        env.print_coverage();

        $finish;
    end

endmodule