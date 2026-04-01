`timescale 1ns/1ps

import apb_trans_sv_unit::*;
import apb_driver_sv_unit::*;
import apb_monitor_sv_unit::*;
import apb_scoreboard_sv_unit::*;

module apb_tb_reset_mid;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    logic PCLK;
    logic PRESETn;

    apb_if #(ADDR_WIDTH, DATA_WIDTH) apb_intf (.PCLK(PCLK), .PRESETn(PRESETn));

    apb_slave_regs #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (4),
        .MAX_WAIT   (3)
    ) dut (
        .apb(apb_intf)
    );

    apb_driver     drv;
    apb_monitor    mon;
    apb_scoreboard scb;

    mailbox #(apb_trans) mon2scb;
    mailbox #(apb_trans) mon2cov;
    apb_trans tr;

    always #5 PCLK = ~PCLK;

    // ------------------------------------------------------------
    // Assertions
    // ------------------------------------------------------------

    property p_enable_implies_psel;
        @(posedge PCLK)
        disable iff (!apb_intf.PRESETn)
        apb_intf.PENABLE |-> apb_intf.PSEL;
    endproperty

    assert property (p_enable_implies_psel)
        else $error("APB Protocol Error: PENABLE asserted without PSEL");

    // NOTE:
    // p_ctrl_stable_during_wait is intentionally omitted in this reset-abort
    // testbench because reset is used to interrupt an active APB access.

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    initial begin
        PCLK = 0;
        PRESETn = 0;

        apb_intf.PADDR   = '0;
        apb_intf.PSEL    = 1'b0;
        apb_intf.PENABLE = 1'b0;
        apb_intf.PWRITE  = 1'b0;
        apb_intf.PWDATA  = '0;

        mon2scb = new();
        mon2cov = new();

        drv = new(apb_intf);
        mon = new(apb_intf, mon2scb, mon2cov);
        scb = new(mon2scb);

        fork
            mon.run();
            scb.run();
        join_none

        repeat (3) @(posedge PCLK);
        PRESETn = 1'b1;

        $display("APB RESET-MID-TRANSACTION TEST START");

        // --------------------------------------------------------
        // Manually start a write transaction
        // --------------------------------------------------------
        @(negedge PCLK);
        apb_intf.PADDR   = 8'h00;
        apb_intf.PWRITE  = 1'b1;
        apb_intf.PWDATA  = 32'hDEAD_BEEF;
        apb_intf.PSEL    = 1'b1;
        apb_intf.PENABLE = 1'b0;

        @(negedge PCLK);
        apb_intf.PENABLE = 1'b1;

        // Assert reset mid-cycle
        @(posedge PCLK);
        @(negedge PCLK);
        $display("Asserting reset in middle of APB access phase");
        PRESETn = 1'b0;

        // Hold reset for a couple of cycles
        repeat (2) @(posedge PCLK);

        // Release reset
        PRESETn = 1'b1;

        // Clean interface after reset
        @(negedge PCLK);
        apb_intf.PADDR   = '0;
        apb_intf.PWRITE  = 1'b0;
        apb_intf.PWDATA  = '0;
        apb_intf.PSEL    = 1'b0;
        apb_intf.PENABLE = 1'b0;

        repeat (2) @(posedge PCLK);

        // --------------------------------------------------------
        // Post-reset sanity traffic
        // --------------------------------------------------------
        tr = new();
        tr.write = 1'b1;
        tr.addr  = 8'h04;
        tr.wdata = 32'h1234_5678;
        drv.drive(tr);

        tr = new();
        tr.write = 1'b0;
        tr.addr  = 8'h04;
        tr.wdata = 32'h0;
        drv.drive(tr);

        repeat (5) @(posedge PCLK);
        $finish;
    end

endmodule