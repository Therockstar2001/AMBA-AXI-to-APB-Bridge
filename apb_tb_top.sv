`timescale 1ns/1ps

import apb_trans_sv_unit::*;
import apb_driver_sv_unit::*;
import apb_monitor_sv_unit::*;
import apb_scoreboard_sv_unit::*;
import apb_coverage_sv_unit::*;

module apb_tb_top;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    logic PCLK;
    logic PRESETn;

    apb_if #(ADDR_WIDTH, DATA_WIDTH) apb_intf (.PCLK(PCLK), .PRESETn(PRESETn));

    apb_slave_regs #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (4),
        .MAX_WAIT(3)
    ) dut (
        .apb(apb_intf)
    );

    apb_driver drv;
    apb_monitor mon;
    apb_scoreboard scb;
    apb_trans tr;
    apb_coverage cov;

    mailbox #(apb_trans) mon2scb;
    mailbox #(apb_trans) mon2cov;

    always #5 PCLK = ~PCLK;

    // ------------------------------------------------------------
    // APB Assertions
    // ------------------------------------------------------------

    property p_enable_implies_psel;
        @(posedge PCLK)
        apb_intf.PENABLE |-> apb_intf.PSEL;
    endproperty

    assert property (p_enable_implies_psel)
        else $error("APB Protocol Error: PENABLE asserted without PSEL");

    property p_ctrl_stable_during_wait;
        @(posedge PCLK)
        apb_intf.PSEL && apb_intf.PENABLE && !apb_intf.PREADY
        |=> $stable(apb_intf.PADDR) &&
            $stable(apb_intf.PWRITE) &&
            $stable(apb_intf.PWDATA);
    endproperty

    assert property (p_ctrl_stable_during_wait)
        else $error("APB Protocol Error: Control changed during wait state");

    property p_setup_to_access;
        @(posedge PCLK)
        apb_intf.PSEL && !apb_intf.PENABLE
        |=> apb_intf.PSEL && apb_intf.PENABLE;
    endproperty

    assert property (p_setup_to_access)
        else $error("APB Protocol Error: Setup phase not followed by access phase");

    // ------------------------------------------------------------
    // Test Sequence
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
        drv     = new(apb_intf);
        mon     = new(apb_intf, mon2scb, mon2cov);
        scb     = new(mon2scb);
        cov = new(mon2cov);

        fork
            mon.run();
            scb.run();
	    cov.run();
        join_none

        repeat (3) @(posedge PCLK);
        PRESETn = 1;

        $display("APB RANDOM DRIVER-BASED TEST START");

        repeat (20) begin
            tr = new();

            assert(tr.randomize())
                else $fatal("Randomization failed for APB transaction");

            drv.drive(tr);
        end

        repeat (5) @(posedge PCLK);
	cov.report();
        $finish;
    end

endmodule