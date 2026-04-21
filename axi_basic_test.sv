`timescale 1ns/1ps

module axi_basic_test;

    logic [31:0] rdata;

    axi_env_tb env();

    initial begin
        wait (env.ARESETn == 1'b1);

        $display("AXI BASIC TEST START");

        env.do_write(32'h0000_0000, 32'hA5A5_1111);
        env.do_write(32'h0000_0004, 32'h1234_5678);

        env.do_read(32'h0000_0000, rdata);
        if (rdata !== 32'hA5A5_1111)
            $error("Mismatch at addr 0x00000000. Exp=0xA5A51111 Got=0x%08h", rdata);

        env.do_read(32'h0000_0004, rdata);
        if (rdata !== 32'h1234_5678)
            $error("Mismatch at addr 0x00000004. Exp=0x12345678 Got=0x%08h", rdata);

        env.do_read(32'h0000_0010, rdata);

        repeat (10) @(posedge env.ACLK);
        env.print_coverage();
        $finish;
    end

endmodule