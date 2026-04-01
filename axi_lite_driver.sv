`timescale 1ns/1ps

import axi_lite_trans_sv_unit::*;

class axi_lite_driver;

    virtual axi_lite_if.master vif;

    function new(virtual axi_lite_if.master vif);
        this.vif = vif;
    endfunction

    // ------------------------------------------------------------
    // MAIN ENTRY
    // ------------------------------------------------------------
    task drive(axi_lite_trans tr);
        if (tr.write)
            drive_write(tr);
        else
            drive_read(tr);
    endtask

    // ------------------------------------------------------------
    // WRITE CHANNEL
    // ------------------------------------------------------------
    task drive_write(axi_lite_trans tr);
        begin
            // AW + W phase
            @(negedge vif.ACLK);
            vif.AWADDR  <= tr.addr;
            vif.AWVALID <= 1'b1;

            vif.WDATA   <= tr.wdata;
            vif.WSTRB   <= tr.wstrb;
            vif.WVALID  <= 1'b1;

            vif.BREADY  <= 1'b0;

            // Wait for handshake
            wait (vif.AWREADY && vif.WREADY);

            @(negedge vif.ACLK);
            vif.AWVALID <= 1'b0;
            vif.WVALID  <= 1'b0;

            // Response phase
            vif.BREADY <= 1'b1;

            wait (vif.BVALID);

            tr.bresp = vif.BRESP;

            // Critical: allow FSM to exit
            @(posedge vif.ACLK);

            @(negedge vif.ACLK);
            vif.BREADY <= 1'b0;

            tr.display("DRV_WRITE");
        end
    endtask

    // ------------------------------------------------------------
    // READ CHANNEL
    // ------------------------------------------------------------
    task drive_read(axi_lite_trans tr);
        begin
            @(negedge vif.ACLK);
            vif.ARADDR  <= tr.addr;
            vif.ARVALID <= 1'b1;

            vif.RREADY  <= 1'b0;

            wait (vif.ARREADY);

            @(negedge vif.ACLK);
            vif.ARVALID <= 1'b0;

            vif.RREADY  <= 1'b1;

            wait (vif.RVALID);

            tr.rdata = vif.RDATA;
            tr.rresp = vif.RRESP;

            // Critical: allow FSM to exit
            @(posedge vif.ACLK);

            @(negedge vif.ACLK);
            vif.RREADY <= 1'b0;

            tr.display("DRV_READ");
        end
    endtask

endclass