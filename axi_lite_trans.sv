`timescale 1ns/1ps

package axi_lite_trans_sv_unit;

    class axi_lite_trans;

        rand bit        write;
        rand bit [31:0] addr;
        rand bit [31:0] wdata;
        rand bit [3:0]  wstrb;

        bit [31:0] rdata;
        bit [1:0]  bresp;
        bit [1:0]  rresp;

        // -----------------------------------
        // Constraints
        // -----------------------------------

        constraint c_align {
            addr[1:0] == 2'b00;
        }

        constraint c_addr_space {
            addr inside {
                32'h0000_0000,
                32'h0000_0004,
                32'h0000_0008,
                32'h0000_000C,
                32'h0000_0010
            };
        }

        constraint c_rw_mix {
            write dist {1 := 50, 0 := 50};
        }

        constraint c_wstrb {
            wstrb == 4'b1111;
        }

        constraint c_read_defaults {
            if (!write)
                wdata == 32'h0000_0000;
        }

        function void display(string tag);
            $display("[%s] write=%0d addr=0x%08h wdata=0x%08h rdata=0x%08h bresp=0x%0h rresp=0x%0h wstrb=0x%0h",
                     tag, write, addr, wdata, rdata, bresp, rresp, wstrb);
        endfunction

    endclass

endpackage