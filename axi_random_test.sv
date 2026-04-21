`timescale 1ns/1ps

module axi_random_test;

    axi_env_tb env();

    initial begin
        wait (env.ARESETn == 1'b1);

        $display("AXI RANDOM TEST START");

        // Warm-up directed traffic
        env.do_write(32'h0000_0000, 32'hA5A5_1111);
        env.do_write(32'h0000_0004, 32'h1234_5678);

        // Random traffic
        repeat (50) begin
            env.do_random();
        end

        repeat (10) @(posedge env.ACLK);
        env.print_coverage();
        $finish;
    end

endmodule