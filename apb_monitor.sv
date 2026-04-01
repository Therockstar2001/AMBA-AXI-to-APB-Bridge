package apb_monitor_sv_unit;

    import apb_trans_sv_unit::*;

    class apb_monitor;

        virtual apb_if #(8,32) vif;
        mailbox #(apb_trans) mon2scb;
        mailbox #(apb_trans) mon2cov;

        function new(virtual apb_if #(8,32) vif,
                     mailbox #(apb_trans) mon2scb,
                     mailbox #(apb_trans) mon2cov);
            this.vif     = vif;
            this.mon2scb = mon2scb;
            this.mon2cov = mon2cov;
        endfunction

        task run();
            apb_trans tr_scb;
            apb_trans tr_cov;

            forever begin
                @(posedge vif.PCLK);

                if (vif.PSEL && vif.PENABLE && vif.PREADY) begin
                    tr_scb = new();
                    tr_cov = new();

                    tr_scb.write  = vif.PWRITE;
                    tr_scb.addr   = vif.PADDR;
                    tr_scb.wdata  = vif.PWDATA;
                    tr_scb.slverr = vif.PSLVERR;

                    tr_cov.write  = vif.PWRITE;
                    tr_cov.addr   = vif.PADDR;
                    tr_cov.wdata  = vif.PWDATA;
                    tr_cov.slverr = vif.PSLVERR;

                    if (!vif.PWRITE) begin
                        tr_scb.rdata = vif.PRDATA;
                        tr_cov.rdata = vif.PRDATA;
                    end
                    else begin
                        tr_scb.rdata = '0;
                        tr_cov.rdata = '0;
                    end

                    mon2scb.put(tr_scb);
                    mon2cov.put(tr_cov);

                    tr_scb.display("MON");
                end
            end
        endtask

    endclass

endpackage