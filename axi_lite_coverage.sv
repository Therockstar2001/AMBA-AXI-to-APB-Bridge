`timescale 1ns/1ps

package axi_lite_coverage_sv_unit;

    import axi_lite_trans_sv_unit::*;

    class axi_lite_coverage;

        mailbox #(axi_lite_trans) mon2cov;

        axi_lite_trans tr;

        // ----------------------------
        // Covergroup
        // ----------------------------
        covergroup cg;

            option.per_instance = 1;

            // Operation type
            coverpoint tr.write {
                bins write = {1};
                bins read  = {0};
            }

            // Address coverage
            coverpoint tr.addr {
                bins valid[]   = {[0:12]};
                bins invalid   = {16};
            }

            // Write response
            coverpoint tr.bresp {
                bins ok  = {0};
                bins err = {2};
            }

            // Read response
            coverpoint tr.rresp {
                bins ok  = {0};
                bins err = {2};
            }

            // Cross coverage
            cross tr.write, tr.addr;

        endgroup

        // ----------------------------
        // Constructor
        // ----------------------------
        function new(mailbox #(axi_lite_trans) mon2cov);
            this.mon2cov = mon2cov;
            cg = new();
        endfunction

        // ----------------------------
        // Run
        // ----------------------------
        task run();
            forever begin
                mon2cov.get(tr);
                cg.sample();
            end
        endtask

        // ----------------------------
        // Report
        // ----------------------------
        function void report();
            $display("=================================");
            $display(" AXI COVERAGE = %0.2f %%", cg.get_coverage());
            $display("=================================");
        endfunction

    endclass

endpackage