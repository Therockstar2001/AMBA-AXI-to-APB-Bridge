`timescale 1ns/1ps

package axi_lite_scoreboard_sv_unit;

    import axi_lite_trans_sv_unit::*;

    class axi_lite_scoreboard;

        mailbox #(axi_lite_trans) mon2scb;

        bit [31:0] reg_model [0:3];

        function new(mailbox #(axi_lite_trans) mon2scb);
            this.mon2scb = mon2scb;
            foreach (reg_model[i])
                reg_model[i] = 32'h0;
        endfunction

        function int get_index(bit [31:0] addr);
            return addr >> 2;
        endfunction

        function bit is_valid_addr(bit [31:0] addr);
            return (addr inside {32'h0000_0000,
                                 32'h0000_0004,
                                 32'h0000_0008,
                                 32'h0000_000C});
        endfunction

        task run();
            axi_lite_trans tr;
            int idx;

            forever begin
                mon2scb.get(tr);

                if (tr.write) begin
                    if (is_valid_addr(tr.addr)) begin
                        idx = get_index(tr.addr);
                        reg_model[idx] = tr.wdata;

                        if (tr.bresp !== 2'b00)
                            $error("[AXI_SCB] WRITE RESP MISMATCH addr=0x%08h exp=0x0 got=0x%0h",
                                   tr.addr, tr.bresp);
                        else
                            $display("[AXI_SCB] WRITE OK addr=0x%08h data=0x%08h",
                                     tr.addr, tr.wdata);
                    end
                    else begin
                        if (tr.bresp !== 2'b10)
                            $error("[AXI_SCB] INVALID WRITE RESP MISMATCH addr=0x%08h exp=0x2 got=0x%0h",
                                   tr.addr, tr.bresp);
                        else
                            $display("[AXI_SCB] INVALID WRITE OK addr=0x%08h", tr.addr);
                    end
                end
                else begin
                    if (is_valid_addr(tr.addr)) begin
                        idx = get_index(tr.addr);

                        if (tr.rresp !== 2'b00)
                            $error("[AXI_SCB] READ RESP MISMATCH addr=0x%08h exp=0x0 got=0x%0h",
                                   tr.addr, tr.rresp);
                        else if (tr.rdata !== reg_model[idx])
                            $error("[AXI_SCB] READ DATA MISMATCH addr=0x%08h exp=0x%08h got=0x%08h",
                                   tr.addr, reg_model[idx], tr.rdata);
                        else
                            $display("[AXI_SCB] READ OK addr=0x%08h data=0x%08h",
                                     tr.addr, tr.rdata);
                    end
                    else begin
                        if (tr.rresp !== 2'b10)
                            $error("[AXI_SCB] INVALID READ RESP MISMATCH addr=0x%08h exp=0x2 got=0x%0h",
                                   tr.addr, tr.rresp);
                        else
                            $display("[AXI_SCB] INVALID READ OK addr=0x%08h data=0x%08h",
                                     tr.addr, tr.rdata);
                    end
                end
            end
        endtask

    endclass

endpackage