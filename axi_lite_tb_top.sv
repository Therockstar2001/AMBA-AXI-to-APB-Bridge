`timescale 1ns/1ps

import axi_lite_trans_sv_unit::*;
import axi_lite_driver_sv_unit::*;
import axi_lite_monitor_sv_unit::*;
import axi_lite_scoreboard_sv_unit::*;

module axi_lite_tb_top;

    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter APB_ADDR_WIDTH = 32;
    parameter APB_DATA_WIDTH = 32;

    logic ACLK;
    logic ARESETn;

    axi_lite_if #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH) axi_if (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    apb_if #(APB_ADDR_WIDTH, APB_DATA_WIDTH) apb_if_inst (
        .PCLK    (ACLK),
        .PRESETn (ARESETn)
    );

    axi_lite_to_apb_bridge #(
        .ADDR_WIDTH (AXI_ADDR_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH)
    ) dut (
        .axi (axi_if),
        .apb (apb_if_inst)
    );

    apb_slave_regs #(
        .ADDR_WIDTH (APB_ADDR_WIDTH),
        .DATA_WIDTH (APB_DATA_WIDTH),
        .NUM_REGS   (4),
        .MAX_WAIT   (3)
    ) apb_slave (
        .apb(apb_if_inst)
    );

    axi_lite_driver     drv;
    axi_lite_monitor    mon;
    axi_lite_scoreboard scb;
    axi_lite_trans      tr;

    mailbox #(axi_lite_trans) mon2scb;

    always #5 ACLK = ~ACLK;

    initial begin
        ACLK    = 0;
        ARESETn = 0;

        // AXI init
        axi_if.AWADDR  = '0;
        axi_if.AWVALID = 1'b0;
        axi_if.WDATA   = '0;
        axi_if.WSTRB   = '0;
        axi_if.WVALID  = 1'b0;
        axi_if.BREADY  = 1'b0;
        axi_if.ARADDR  = '0;
        axi_if.ARVALID = 1'b0;
        axi_if.RREADY  = 1'b0;

        mon2scb = new();

        drv = new(axi_if);
        mon = new(axi_if, mon2scb);
        scb = new(mon2scb);

        fork
            mon.run();
            scb.run();
        join_none

        repeat (3) @(posedge ACLK);
        ARESETn = 1'b1;

        $display("AXI-LITE TO APB BRIDGE RANDOM TEST START");

        // ----------------------------------------
        // Warm-up directed sanity transactions
        // ----------------------------------------
        tr = new();
        tr.write = 1'b1;
        tr.addr  = 32'h0000_0000;
        tr.wdata = 32'hA5A5_1111;
        tr.wstrb = 4'b1111;
        drv.drive(tr);

        tr = new();
        tr.write = 1'b1;
        tr.addr  = 32'h0000_0004;
        tr.wdata = 32'h1234_5678;
        tr.wstrb = 4'b1111;
        drv.drive(tr);

        tr = new();
        tr.write = 1'b0;
        tr.addr  = 32'h0000_0000;
        tr.wdata = 32'h0000_0000;
        tr.wstrb = 4'b1111;
        drv.drive(tr);

        // ----------------------------------------
        // Constrained-random traffic
        // ----------------------------------------
        repeat (50) begin
            tr = new();

            assert(tr.randomize())
                else $fatal("AXI transaction randomization failed");

            drv.drive(tr);
        end

        repeat (10) @(posedge ACLK);
	#50;
	env.cov.report();
        $finish;
    end

endmodule