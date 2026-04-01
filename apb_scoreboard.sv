package apb_scoreboard_sv_unit;

    import apb_trans_sv_unit::*;

    class apb_scoreboard;

        mailbox #(apb_trans) mon2scb;

        bit [31:0] reg_model [0:3];

        function new(mailbox #(apb_trans) mon2scb);
            this.mon2scb = mon2scb;

            // Reset model
            foreach (reg_model[i])
                reg_model[i] = 32'h0;
        endfunction

        function int get_index(bit [7:0] addr);
            return addr >> 2; // word aligned
        endfunction

        task run();
            apb_trans tr;
            int idx;

            forever begin
                mon2scb.get(tr);

                idx = get_index(tr.addr);

                // -------------------------------
                // VALID ADDRESS
                // -------------------------------
                if (idx >= 0 && idx < 4) begin

                    if (tr.write) begin
                        reg_model[idx] = tr.wdata;
                        $display("[SCB] WRITE OK addr=0x%0h data=0x%0h",
                                 tr.addr, tr.wdata);
                    end
                    else begin
                        if (tr.rdata !== reg_model[idx]) begin
                            $error("[SCB] READ MISMATCH addr=0x%0h exp=0x%0h got=0x%0h",
                                   tr.addr, reg_model[idx], tr.rdata);
                        end
                        else begin
                            $display("[SCB] READ OK addr=0x%0h data=0x%0h",
                                     tr.addr, tr.rdata);
                        end
                    end

                    if (tr.slverr != 0) begin
                        $error("[SCB] Unexpected PSLVERR on valid addr=0x%0h", tr.addr);
                    end
                end

                // -------------------------------
                // INVALID ADDRESS
                // -------------------------------
                else begin
                    if (tr.slverr != 1) begin
                        $error("[SCB] Expected PSLVERR=1 for invalid addr=0x%0h", tr.addr);
                    end
                    else begin
                        $display("[SCB] INVALID ACCESS OK addr=0x%0h", tr.addr);
                    end
                end
            end
        endtask

    endclass

endpackage