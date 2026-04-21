`timescale 1ns/1ps

package axi_lite_monitor_sv_unit;

    import axi_lite_trans_sv_unit::*;

    class axi_lite_monitor;

        virtual axi_lite_if.slave vif;
        mailbox #(axi_lite_trans) mon2scb;
	mailbox #(axi_lite_trans) mon2cov;

        // hold accepted channel information until response completes
        bit [31:0] awaddr_q;
        bit [31:0] wdata_q;
        bit [3:0]  wstrb_q;
        bit        have_aw;
        bit        have_w;

        bit [31:0] araddr_q;
        bit        have_ar;

        function new(virtual axi_lite_if.slave vif,
                     mailbox #(axi_lite_trans) mon2scb,
		     mailbox #(axi_lite_trans) mon2cov);
            this.vif     = vif;
            this.mon2scb = mon2scb;
	    this.mon2cov = mon2cov;

            have_aw = 1'b0;
            have_w  = 1'b0;
            have_ar = 1'b0;
        endfunction

        task run();
            axi_lite_trans tr;

            forever begin
                @(posedge vif.ACLK);

                if (!vif.ARESETn) begin
                    have_aw <= 1'b0;
                    have_w  <= 1'b0;
                    have_ar <= 1'b0;
                end
                else begin
                    // -----------------------------
                    // Capture accepted write address
                    // -----------------------------
                    if (vif.AWVALID && vif.AWREADY) begin
                        awaddr_q = vif.AWADDR;
                        have_aw  = 1'b1;
                    end

                    // -----------------------------
                    // Capture accepted write data
                    // -----------------------------
                    if (vif.WVALID && vif.WREADY) begin
                        wdata_q = vif.WDATA;
                        wstrb_q = vif.WSTRB;
                        have_w  = 1'b1;
                    end

                    // -----------------------------
                    // Capture accepted read address
                    // -----------------------------
                    if (vif.ARVALID && vif.ARREADY) begin
                        araddr_q = vif.ARADDR;
                        have_ar  = 1'b1;
                    end

                    // -----------------------------
                    // Completed write transaction
                    // -----------------------------
                    if (vif.BVALID && vif.BREADY) begin
                        tr = new();
                        tr.write = 1'b1;
                        tr.addr  = awaddr_q;
                        tr.wdata = wdata_q;
                        tr.wstrb = wstrb_q;
                        tr.bresp = vif.BRESP;
                        tr.rdata = '0;
                        tr.rresp = '0;

                        mon2scb.put(tr);
                        tr.display("MON_WRITE");

                        have_aw = 1'b0;
                        have_w  = 1'b0;
                    end

                    // -----------------------------
                    // Completed read transaction
                    // -----------------------------
                    if (vif.RVALID && vif.RREADY) begin
                        tr = new();
                        tr.write = 1'b0;
                        tr.addr  = araddr_q;
                        tr.wdata = '0;
                        tr.wstrb = 4'b0000;
                        tr.rdata = vif.RDATA;
                        tr.rresp = vif.RRESP;
                        tr.bresp = '0;

                        mon2scb.put(tr);
			mon2cov.put(tr);
                        tr.display("MON_READ");

                        have_ar = 1'b0;
                    end
                end
            end
        endtask

    endclass

endpackage