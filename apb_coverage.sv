package apb_coverage_sv_unit;

    import apb_trans_sv_unit::*;

    class apb_coverage;

        mailbox #(apb_trans) mon2cov;

        covergroup apb_cg;
            option.per_instance = 1;

            cp_write: coverpoint tr.write {
                bins read  = {0};
                bins write = {1};
            }

            cp_addr: coverpoint tr.addr {
                bins addr_00  = {8'h00};
                bins addr_04  = {8'h04};
                bins addr_08  = {8'h08};
                bins addr_0c  = {8'h0C};
                bins addr_10  = {8'h10};
            }

            cp_err: coverpoint tr.slverr {
                bins no_err = {0};
                bins err    = {1};
            }

            cross cp_write, cp_addr;
            cross cp_write, cp_err;
            cross cp_addr,  cp_err;
        endgroup

        apb_trans tr;

        function new(mailbox #(apb_trans) mon2cov);
            this.mon2cov = mon2cov;
            apb_cg = new();
        endfunction

        task run();
            forever begin
                mon2cov.get(tr);
                apb_cg.sample();
            end
        endtask

        function void report();
            $display("[COV] Functional Coverage = %0.2f%%", apb_cg.get_inst_coverage());
        endfunction

    endclass

endpackage