package apb_driver_sv_unit;

    import apb_trans_sv_unit::*;

    class apb_driver;

        virtual apb_if #(8,32) vif;

        function new(virtual apb_if #(8,32) vif);
            this.vif = vif;
        endfunction

        task drive(apb_trans tr);

            // Setup phase
            @(negedge vif.PCLK);
            vif.PADDR   = tr.addr;
            vif.PWRITE  = tr.write;
            vif.PWDATA  = tr.wdata;
            vif.PSEL    = 1'b1;
            vif.PENABLE = 1'b0;

            // Access phase
            @(negedge vif.PCLK);
            vif.PENABLE = 1'b1;

            // Wait until ready
            while (vif.PREADY !== 1'b1)
                @(posedge vif.PCLK);

            // Capture read data
            if (!tr.write) begin
                #1;
                tr.rdata = vif.PRDATA;
            end

            tr.slverr = vif.PSLVERR;

            // Cleanup
            @(negedge vif.PCLK);
            vif.PSEL    = 1'b0;
            vif.PENABLE = 1'b0;
            vif.PADDR   = '0;
            vif.PWRITE  = 1'b0;
            vif.PWDATA  = '0;

        endtask

    endclass

endpackage