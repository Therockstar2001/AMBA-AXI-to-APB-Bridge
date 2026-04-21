`timescale 1ns/1ps

module axi_error_test;

    logic [31:0] rdata;

    axi_env_tb env();

    initial begin
        wait (env.ARESETn == 1'b1);

        $display("AXI ERROR TEST START");

        env.do_read(32'h0000_0010, rdata);
        env.do_write(32'h0000_0010, 32'hDEAD_BEEF);

        repeat (10) @(posedge env.ACLK);
        env.print_coverage();
        $finish;
    end

endmodule