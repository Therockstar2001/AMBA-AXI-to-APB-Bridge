`timescale 1ns/1ps

import axi_lite_trans_sv_unit::*;
import axi_lite_driver_sv_unit::*;
import axi_lite_monitor_sv_unit::*;
import axi_lite_scoreboard_sv_unit::*;
import axi_lite_coverage_sv_unit::*;

module axi_env_tb;

    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter APB_ADDR_WIDTH = 32;
    parameter APB_DATA_WIDTH = 32;

    logic ACLK;
    logic ARESETn;

    // Clock
    always #5 ACLK = ~ACLK;

    // --------------------------------------------------
    // Interfaces
    // --------------------------------------------------
    axi_lite_if #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH) axi_if (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    apb_if #(APB_ADDR_WIDTH, APB_DATA_WIDTH) apb_if_inst (
        .PCLK    (ACLK),
        .PRESETn (ARESETn)
    );

    // --------------------------------------------------
    // DUT
    // --------------------------------------------------
    axi_lite_to_apb_bridge #(
        .ADDR_WIDTH (AXI_ADDR_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH)
    ) dut (
        .axi (axi_if),
        .apb (apb_if_inst)
    );

    // --------------------------------------------------
    // APB SLAVE
    // --------------------------------------------------
    apb_slave_regs #(
        .ADDR_WIDTH (APB_ADDR_WIDTH),
        .DATA_WIDTH (APB_DATA_WIDTH),
        .NUM_REGS   (4),
        .MAX_WAIT   (3)
    ) apb_slave (
        .apb (apb_if_inst)
    );

    // --------------------------------------------------
    // Components
    // --------------------------------------------------
    axi_lite_driver     drv;
    axi_lite_monitor    mon;
    axi_lite_scoreboard scb;
    axi_lite_coverage   cov;

    mailbox #(axi_lite_trans) mon2scb;
    mailbox #(axi_lite_trans) mon2cov;

    // --------------------------------------------------
    // Init
    // --------------------------------------------------
    initial begin
        ACLK    = 1'b0;
        ARESETn = 1'b0;

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
        mon2cov = new();

        drv = new(axi_if);
        mon = new(axi_if, mon2scb, mon2cov);
        scb = new(mon2scb);
        cov = new(mon2cov);

        fork
            mon.run();
            scb.run();
            cov.run();
        join_none

        repeat (5) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    // --------------------------------------------------
    // Helper Tasks (used by tests)
    // --------------------------------------------------

    task automatic do_write(input [31:0] addr, input [31:0] data);
        axi_lite_trans tr;
        begin
            tr = new();
            tr.write = 1'b1;
            tr.addr  = addr;
            tr.wdata = data;
            tr.wstrb = 4'hF;
            drv.drive(tr);
        end
    endtask

    task automatic do_read(input [31:0] addr, output [31:0] data);
        axi_lite_trans tr;
        begin
            tr = new();
            tr.write = 1'b0;
            tr.addr  = addr;
            tr.wdata = 32'h0000_0000;
            tr.wstrb = 4'hF;
            drv.drive(tr);
            data = tr.rdata;
        end
    endtask

    task automatic do_random();
        axi_lite_trans tr;
        begin
            tr = new();
            assert(tr.randomize())
                else $fatal("AXI transaction randomization failed");
            drv.drive(tr);
        end
    endtask

    task automatic print_coverage();
        cov.report();
    endtask

endmodule