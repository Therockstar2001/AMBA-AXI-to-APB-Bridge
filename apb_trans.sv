package apb_trans_sv_unit;

    class apb_trans;

        rand bit        write;
        rand bit [7:0]  addr;
        rand bit [31:0] wdata;

        bit  [31:0]     rdata;
        bit             slverr;

        constraint addr_align {
            addr[1:0] == 2'b00;
        }
	
	constraint addr_valid {
            addr inside {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10}; // include invalid case
        }

        constraint rw_mix {
            write dist {1 := 50, 0 := 50};
        }

        function void display(string tag);
            $display("[%s] write=%0d addr=0x%0h wdata=0x%0h rdata=0x%0h err=%0d",
                     tag, write, addr, wdata, rdata, slverr);
        endfunction

    endclass

endpackage