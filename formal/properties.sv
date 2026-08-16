`timescale 1ns/1ps

module axi_apb_properties #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic                      ACLK,
    input logic                      ARESETn,

    // AXI master request and handshake inputs
    input logic [ADDR_WIDTH-1:0]     AWADDR,
    input logic                      AWVALID,

    input logic [DATA_WIDTH-1:0]     WDATA,
    input logic                      WVALID,
    input logic [(DATA_WIDTH/8)-1:0] WSTRB,
    input logic                      BREADY,

    input logic [ADDR_WIDTH-1:0]     ARADDR,
    input logic                      ARVALID,

    input logic                      RREADY,


    // AXI-Lite outputs from DUT
    input logic                      AWREADY,
    input logic                      WREADY,
    input logic [1:0]                BRESP,
    input logic                      BVALID,

    input logic                      ARREADY,
    input logic [DATA_WIDTH-1:0]     RDATA,
    input logic [1:0]                RRESP,
    input logic                      RVALID,

    // APB slave input needed for FSM transition proofs
    input logic [DATA_WIDTH-1:0]     PRDATA,
    input logic                      PREADY,
    input logic                      PSLVERR,

    // APB outputs from DUT
    input logic [ADDR_WIDTH-1:0]     PADDR,
    input logic                      PSEL,
    input logic                      PENABLE,
    input logic                      PWRITE,
    input logic [DATA_WIDTH-1:0]     PWDATA,

    // Formal-only FSM observation
    input logic [2:0]                FORMAL_STATE,
    input logic 		     FORMAL_HAVE_AW,
    input logic 		     FORMAL_HAVE_W
);

    localparam logic [2:0] IDLE         = 3'd0;
    localparam logic [2:0] WRITE_SETUP  = 3'd1;
    localparam logic [2:0] WRITE_ACCESS = 3'd2;
    localparam logic [2:0] WRITE_RESP   = 3'd3;
    localparam logic [2:0] READ_SETUP   = 3'd4;
    localparam logic [2:0] READ_ACCESS  = 3'd5;
    localparam logic [2:0] READ_RESP    = 3'd6;

    localparam integer APB_MAX_WAIT       = 3;
    localparam integer AXI_MAX_RESP_STALL = 3;
    localparam integer AXI_TRANSACTION_BOUND = 12;

    logic       write_pending;
    logic       read_pending;

    logic [4:0] write_progress_count;
    logic [4:0] read_progress_count;

    logic [2:0] apb_wait_count;
    logic [2:0] bresp_stall_count;
    logic [2:0] rresp_stall_count;

    logic f_past_valid;

    initial f_past_valid = 1'b0;

    always_ff @(posedge ACLK)
        f_past_valid <= 1'b1;

    // ============================================================
    // Phase 7A — AXI master protocol assumptions
    // ============================================================
    //
    // These assumptions constrain the formal environment.
    // They describe legal AXI master behavior.
    //
    // A VALID signal and its payload must remain stable until
    // the corresponding READY/VALID handshake occurs.
    // ============================================================

    // ------------------------------------------------------------
    // AXI write-address channel
    //
    // If AWVALID was asserted but the bridge did not accept the
    // address, the master must keep AWVALID asserted and AWADDR
    // unchanged.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            if ($past(AWVALID && !AWREADY)) begin
                assume (AWVALID);
                assume (AWADDR == $past(AWADDR));
            end
        end
    end

    // ------------------------------------------------------------
    // AXI write-data channel
    //
    // If WVALID was asserted but the bridge did not accept the
    // write data, the master must keep WVALID asserted and preserve
    // WDATA and WSTRB.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            if ($past(WVALID && !WREADY)) begin
                assume (WVALID);
                assume (WDATA == $past(WDATA));
                assume (WSTRB == $past(WSTRB));
            end
        end
    end

    // ------------------------------------------------------------
    // AXI read-address channel
    //
    // If ARVALID was asserted but the bridge did not accept the
    // read address, the master must keep ARVALID asserted and
    // preserve ARADDR.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            if ($past(ARVALID && !ARREADY)) begin
                assume (ARVALID);
                assume (ARADDR == $past(ARADDR));
            end
        end
    end

    // ============================================================
    // Phase 7B — Bounded fairness assumptions
    // ============================================================

    // ------------------------------------------------------------
    // APB slave fairness
    //
    // The APB slave may insert wait states by keeping PREADY low,
    // but it may not stall an active APB access indefinitely.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            apb_wait_count <= 3'd0;
        end
        else begin
            if (PSEL && PENABLE && !PREADY)
                apb_wait_count <= apb_wait_count + 3'd1;
            else
                apb_wait_count <= 3'd0;
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (PSEL && PENABLE && !PREADY)
                assume (apb_wait_count < APB_MAX_WAIT);
        end
    end

    // ============================================================
    // Phase 7C — Write transaction progress tracking
    // ============================================================
    //
    // A write becomes pending when both AXI write-address and
    // write-data channels are accepted.
    //
    // It stops being pending when the AXI write response is
    // accepted using BVALID && BREADY.
    // ============================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            write_pending        <= 1'b0;
            write_progress_count <= 5'd0;
        end
        else begin
            // Complete the outstanding write transaction.
            if (write_pending && BVALID && BREADY) begin
                write_pending        <= 1'b0;
                write_progress_count <= 5'd0;
            end

            // Accept a new AXI write transaction.
            else if (!write_pending &&
                     (FORMAL_HAVE_AW || (AWVALID && AWREADY)) &&
                     (FORMAL_HAVE_W || (WVALID  && WREADY))) begin
                write_pending        <= 1'b1;
                write_progress_count <= 5'd0;
            end

            // Count how long the transaction remains pending.
            else if (write_pending) begin
                write_progress_count <= write_progress_count + 5'd1;
            end
            else begin
                write_progress_count <= 5'd0;
            end
        end
    end

    // ------------------------------------------------------------
    // AXI master write-response fairness
    //
    // Once BVALID is asserted, the AXI master may temporarily
    // deassert BREADY, but it must eventually accept the response.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            bresp_stall_count <= 3'd0;
        end
        else begin
            if (BVALID && !BREADY)
                bresp_stall_count <= bresp_stall_count + 3'd1;
            else
                bresp_stall_count <= 3'd0;
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (BVALID && !BREADY)
                assume (bresp_stall_count < AXI_MAX_RESP_STALL);
        end
    end

    // An accepted AXI write must completely finish within the
    // configured progress bound.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (write_pending) begin
                assert (write_progress_count < AXI_TRANSACTION_BOUND);
            end
        end
    end

    // ============================================================
    // Phase 7C — Read transaction progress tracking
    // ============================================================
    //
    // A read becomes pending when the AXI read-address channel
    // handshakes.
    //
    // It stops being pending when the AXI read response is
    // accepted using RVALID && RREADY.
    // ============================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            read_pending        <= 1'b0;
            read_progress_count <= 5'd0;
        end
        else begin
            // Complete the outstanding read transaction.
            if (read_pending && RVALID && RREADY) begin
                read_pending        <= 1'b0;
                read_progress_count <= 5'd0;
            end

            // Accept a new AXI read transaction.
            else if (!read_pending &&
                     ARVALID && ARREADY) begin
                read_pending        <= 1'b1;
                read_progress_count <= 5'd0;
            end

            // Count how long the transaction remains pending.
            else if (read_pending) begin
                read_progress_count <= read_progress_count + 5'd1;
            end
            else begin
                read_progress_count <= 5'd0;
            end
        end
    end

    // ------------------------------------------------------------
    // AXI master read-response fairness
    //
    // Once RVALID is asserted, the AXI master may temporarily
    // deassert RREADY, but it must eventually accept the response.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            rresp_stall_count <= 3'd0;
        end
        else begin
            if (RVALID && !RREADY)
                rresp_stall_count <= rresp_stall_count + 3'd1;
            else
                rresp_stall_count <= 3'd0;
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (RVALID && !RREADY)
                assume (rresp_stall_count < AXI_MAX_RESP_STALL);
        end
    end

    // An accepted AXI read must completely finish within the
    // configured progress bound.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (read_pending) begin
                assert (read_progress_count < AXI_TRANSACTION_BOUND);
            end
        end
    end

    // The bridge is single-transaction and must not have both
    // a read and a write outstanding simultaneously.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            assert (!(write_pending && read_pending));
        end
    end

    // A write response must correspond to an outstanding write.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (BVALID)
                assert (write_pending);
        end
    end

    // A read response must correspond to an outstanding read.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            if (RVALID)
                assert (read_pending);
        end
    end

    // ============================================================
    // Phase 1 — APB basic safety
    // ============================================================

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn)
            assert (!(PENABLE && !PSEL));
    end

    // ============================================================
    // Phase 2 — Reset proofs
    // ============================================================

    always_ff @(posedge ACLK) begin
        if (f_past_valid && !$past(ARESETn)) begin
	    assert (FORMAL_HAVE_AW == 1'b0);
	    assert (FORMAL_HAVE_W == 1'b0);
            assert (AWREADY == 1'b1);
            assert (WREADY  == 1'b1);
            assert (ARREADY == (!AWVALID && !WVALID));

            assert (BVALID == 1'b0);
            assert (RVALID == 1'b0);

            assert (BRESP == 2'b00);
            assert (RRESP == 2'b00);
            assert (RDATA == {DATA_WIDTH{1'b0}});

            assert (PSEL    == 1'b0);
            assert (PENABLE == 1'b0);

            assert (PADDR  == {ADDR_WIDTH{1'b0}});
            assert (PWDATA == {DATA_WIDTH{1'b0}});
            assert (PWRITE == 1'b0);

            assert (FORMAL_STATE == IDLE);
        end
    end

    // ============================================================
    // Phase 3 — FSM legality
    // ============================================================

    // The FSM must always contain one of the seven legal states.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            assert (
                (FORMAL_STATE == IDLE)         ||
                (FORMAL_STATE == WRITE_SETUP)  ||
                (FORMAL_STATE == WRITE_ACCESS) ||
                (FORMAL_STATE == WRITE_RESP)   ||
                (FORMAL_STATE == READ_SETUP)   ||
                (FORMAL_STATE == READ_ACCESS)  ||
                (FORMAL_STATE == READ_RESP)
            );
        end
    end

    // ============================================================
    // Phase 3 — FSM transition correctness
    // ============================================================

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            case ($past(FORMAL_STATE))

                // ------------------------------------------------
                // IDLE transition priority:
                // write request has priority over read request
                // ------------------------------------------------
                IDLE: begin
    		    if ($past(
        		(FORMAL_HAVE_AW || (AWVALID && AWREADY)) &&
        		(FORMAL_HAVE_W  || (WVALID  && WREADY))
    		    )) begin
        		assert (FORMAL_STATE == WRITE_SETUP);
    		    end
    		    else if ($past(ARVALID && ARREADY)) begin
        		assert (FORMAL_STATE == READ_SETUP);
    		    end
    		    else begin
        		assert (FORMAL_STATE == IDLE);
    		    end
		end

                // ------------------------------------------------
                // APB write path
                // ------------------------------------------------
                WRITE_SETUP:
                    assert (FORMAL_STATE == WRITE_ACCESS);

                WRITE_ACCESS: begin
                    if ($past(PREADY))
                        assert (FORMAL_STATE == WRITE_RESP);
                    else
                        assert (FORMAL_STATE == WRITE_ACCESS);
                end

                WRITE_RESP: begin
                    if ($past(BREADY))
                        assert (FORMAL_STATE == IDLE);
                    else
                        assert (FORMAL_STATE == WRITE_RESP);
                end

                // ------------------------------------------------
                // APB read path
                // ------------------------------------------------
                READ_SETUP:
                    assert (FORMAL_STATE == READ_ACCESS);

                READ_ACCESS: begin
                    if ($past(PREADY))
                        assert (FORMAL_STATE == READ_RESP);
                    else
                        assert (FORMAL_STATE == READ_ACCESS);
                end

                READ_RESP: begin
                    if ($past(RREADY))
                        assert (FORMAL_STATE == IDLE);
                    else
                        assert (FORMAL_STATE == READ_RESP);
                end

                // Illegal previous state must recover to IDLE.
                default:
                    assert (FORMAL_STATE == IDLE);

            endcase
        end
    end

    // ============================================================
    // Phase 4 — APB protocol proofs
    // ============================================================

    // ------------------------------------------------------------
    // APB output behavior must correspond to the current FSM state.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin

            case (FORMAL_STATE)

                // No APB transfer is active while waiting for
                // a new AXI request.
                IDLE: begin
                    assert (PSEL    == 1'b0);
                    assert (PENABLE == 1'b0);
                end

                // APB write setup phase:
                // slave selected, access phase not yet asserted.
                WRITE_SETUP: begin
                    assert (PSEL    == 1'b1);
                    assert (PENABLE == 1'b0);
                    assert (PWRITE  == 1'b1);
                end

                // APB write access phase.
                WRITE_ACCESS: begin
                    assert (PSEL    == 1'b1);
                    assert (PENABLE == 1'b1);
                    assert (PWRITE  == 1'b1);
                end

                // APB has completed; bridge is returning AXI BRESP.
                WRITE_RESP: begin
                    assert (PSEL    == 1'b0);
                    assert (PENABLE == 1'b0);
                end

                // APB read setup phase.
                READ_SETUP: begin
                    assert (PSEL    == 1'b1);
                    assert (PENABLE == 1'b0);
                    assert (PWRITE  == 1'b0);
                end

                // APB read access phase.
                READ_ACCESS: begin
                    assert (PSEL    == 1'b1);
                    assert (PENABLE == 1'b1);
                    assert (PWRITE  == 1'b0);
                end

                // APB has completed; bridge is returning AXI RDATA.
                READ_RESP: begin
                    assert (PSEL    == 1'b0);
                    assert (PENABLE == 1'b0);
                end

                default: begin
                    // FSM legality was proved in Phase 3.
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // PENABLE may only be asserted during an APB access phase.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && PENABLE) begin
            assert (
                (FORMAL_STATE == WRITE_ACCESS) ||
                (FORMAL_STATE == READ_ACCESS)
            );
        end
    end

    // ------------------------------------------------------------
    // Any active APB setup or access must belong to a valid
    // APB transaction state.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && PSEL) begin
            assert (
                (FORMAL_STATE == WRITE_SETUP)  ||
                (FORMAL_STATE == WRITE_ACCESS) ||
                (FORMAL_STATE == READ_SETUP)   ||
                (FORMAL_STATE == READ_ACCESS)
            );
        end
    end

    // ------------------------------------------------------------
    // An APB setup phase must be followed by its corresponding
    // access phase.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(FORMAL_STATE) == WRITE_SETUP) begin
                assert (PSEL    == 1'b1);
                assert (PENABLE == 1'b1);
                assert (PWRITE  == 1'b1);
            end

            if ($past(FORMAL_STATE) == READ_SETUP) begin
                assert (PSEL    == 1'b1);
                assert (PENABLE == 1'b1);
                assert (PWRITE  == 1'b0);
            end
        end
    end

    // ------------------------------------------------------------
    // APB address and control must remain stable from setup
    // into the access phase.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if (($past(FORMAL_STATE) == WRITE_SETUP) ||
                ($past(FORMAL_STATE) == READ_SETUP)) begin

                assert (PADDR  == $past(PADDR));
                assert (PWRITE == $past(PWRITE));
            end

            if ($past(FORMAL_STATE) == WRITE_SETUP)
                assert (PWDATA == $past(PWDATA));
        end
    end

    // ------------------------------------------------------------
    // APB wait-state stability:
    //
    // If the previous cycle was an APB access cycle and PREADY was
    // low, the bridge must keep the transaction active and preserve
    // all request information.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(PSEL && PENABLE && !PREADY)) begin
                assert (PSEL    == 1'b1);
                assert (PENABLE == 1'b1);

                assert (PADDR   == $past(PADDR));
                assert (PWRITE  == $past(PWRITE));
                assert (PWDATA  == $past(PWDATA));
            end
        end
    end

    // ------------------------------------------------------------
    // APB completion must terminate the APB control phase.
    //
    // When PREADY was asserted during an APB access cycle, the
    // bridge must deassert PSEL and PENABLE on the following cycle.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(PSEL && PENABLE && PREADY)) begin
                assert (PSEL    == 1'b0);
                assert (PENABLE == 1'b0);
            end
        end
    end

    // ============================================================
    // Phase 5A — AXI request-acceptance safety
    // ============================================================

    /*
     * AXI write-address and write-data channels are accepted
     * independently and buffered using one-entry holding state.
     *
     * APB write execution begins only after both the AW and W
     * components of the AXI-Lite write transaction are available.
     */
     always_ff @(posedge ACLK) begin
	 if (f_past_valid && ARESETn) begin
	     if (FORMAL_STATE == IDLE) begin
		 assert (AWREADY == !FORMAL_HAVE_AW);
		 assert (WREADY == !FORMAL_HAVE_W);
	         assert(ARREADY == (!FORMAL_HAVE_AW && !FORMAL_HAVE_W && !AWVALID && !WVALID));
  	     end 
	     else begin
		 assert (!AWREADY);
		 assert (!WREADY);
		 assert (!ARREADY);
	     end
	 end
     end

     always_ff @(posedge ACLK) begin
         if (f_past_valid && ARESETn && $past(ARESETn)) begin

             if ($past(
                 AWVALID &&
                 AWREADY &&
                 !FORMAL_HAVE_W &&
                 !(WVALID && WREADY)
             )) begin

                 assert (FORMAL_STATE == IDLE);
                 assert (FORMAL_HAVE_AW);
                 assert (PADDR == $past(AWADDR));

             end
         end
     end

     always_ff @(posedge ACLK) begin
         if (f_past_valid && ARESETn && $past(ARESETn)) begin

             if ($past(
                 WVALID &&
                 WREADY &&
                 !FORMAL_HAVE_AW &&
                 !(AWVALID && AWREADY)
             )) begin

                 assert (FORMAL_STATE == IDLE);
                 assert (FORMAL_HAVE_W);
                 assert (PWDATA == $past(WDATA));

             end
         end
     end

    /*
     * The current FSM can service only one new transaction from IDLE.
     *
     * Therefore, it must never acknowledge both a read and a write
     * during the same clock cycle unless it has buffering for both.
     */
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            assert (!( (
                (FORMAL_HAVE_AW || (AWVALID && AWREADY)) && (FORMAL_HAVE_W || (WVALID && WREADY))) &&
                (ARVALID && ARREADY)
            ));
        end
    end

    // ============================================================
    // Phase 5B — AXI response persistence and handshake behavior
    // ============================================================

    // ------------------------------------------------------------
    // Write response outputs must correspond to WRITE_RESP.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin

            if (FORMAL_STATE == WRITE_RESP)
                assert (BVALID == 1'b1);
            else
                assert (BVALID == 1'b0);

            if (BVALID)
                assert (FORMAL_STATE == WRITE_RESP);
        end
    end

    // ------------------------------------------------------------
    // BVALID and BRESP must remain stable while the master applies
    // write-response backpressure.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(BVALID && !BREADY)) begin
                assert (BVALID == 1'b1);
                assert (BRESP == $past(BRESP));
                assert (FORMAL_STATE == WRITE_RESP);
            end
        end
    end

    // ------------------------------------------------------------
    // Once the write response is accepted, BVALID must deassert
    // on the following cycle.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(BVALID && BREADY)) begin
                assert (BVALID == 1'b0);
                assert (FORMAL_STATE == IDLE);
            end
        end
    end

    // ------------------------------------------------------------
    // Read response outputs must correspond to READ_RESP.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin

            if (FORMAL_STATE == READ_RESP)
                assert (RVALID == 1'b1);
            else
                assert (RVALID == 1'b0);

            if (RVALID)
                assert (FORMAL_STATE == READ_RESP);
        end
    end

    // ------------------------------------------------------------
    // RVALID, RDATA, and RRESP must remain stable while the master
    // applies read-response backpressure.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(RVALID && !RREADY)) begin
                assert (RVALID == 1'b1);
                assert (RDATA == $past(RDATA));
                assert (RRESP == $past(RRESP));
                assert (FORMAL_STATE == READ_RESP);
            end
        end
    end

    // ------------------------------------------------------------
    // Once the read response is accepted, RVALID must deassert
    // on the following cycle.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(RVALID && RREADY)) begin
                assert (RVALID == 1'b0);
                assert (FORMAL_STATE == IDLE);
            end
        end
    end

    // ------------------------------------------------------------
    // The bridge must not advertise request acceptance while busy.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn &&
            (FORMAL_STATE != IDLE)) begin

            assert (AWREADY == 1'b0);
            assert (WREADY  == 1'b0);
            assert (ARREADY == 1'b0);
        end
    end

    // ------------------------------------------------------------
    // Write and read responses must never be active together.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn)
            assert (!(BVALID && RVALID));
    end

    // ============================================================
    // Phase 5C — AXI request capture and APB data mapping
    // ============================================================

    // ------------------------------------------------------------
    // Accepted AXI write request must be transferred correctly
    // into the APB write setup phase.
    //
    // When both AXI write channels handshake in IDLE, the bridge
    // must capture AWADDR and WDATA and present them on PADDR and
    // PWDATA during the following WRITE_SETUP state.
    // ------------------------------------------------------------


    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(AWVALID && AWREADY)) begin
                assert (PADDR == $past(AWADDR));
            end

        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(WVALID && WREADY)) begin
                assert (PWDATA == $past(WDATA));
            end

        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin

            if (FORMAL_STATE == WRITE_SETUP) begin
                assert (PSEL    == 1'b1);
                assert (PENABLE == 1'b0);
                assert (PWRITE  == 1'b1);
            end

        end
    end

    // ------------------------------------------------------------
    // Accepted AXI read request must be transferred correctly
    // into the APB read setup phase.
    //
    // When the AXI read-address channel handshakes in IDLE, the
    // bridge must capture ARADDR and present it on PADDR during
    // the following READ_SETUP state.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(ARVALID && ARREADY)) begin
                assert (FORMAL_STATE == READ_SETUP);

                assert (PADDR  == $past(ARADDR));
                assert (PWRITE == 1'b0);

                assert (PSEL    == 1'b1);
                assert (PENABLE == 1'b0);
            end
        end
    end

    // ------------------------------------------------------------
    // APB write request information must remain stable from the
    // write setup phase into the write access phase.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(FORMAL_STATE) == WRITE_SETUP) begin
                assert (FORMAL_STATE == WRITE_ACCESS);

                assert (PADDR  == $past(PADDR));
                assert (PWDATA == $past(PWDATA));
                assert (PWRITE == 1'b1);
            end
        end
    end

    // ------------------------------------------------------------
    // APB read request information must remain stable from the
    // read setup phase into the read access phase.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(FORMAL_STATE) == READ_SETUP) begin
                assert (FORMAL_STATE == READ_ACCESS);

                assert (PADDR  == $past(PADDR));
                assert (PWRITE == 1'b0);
            end
        end
    end

    // ------------------------------------------------------------
    // Write request information must remain stable for every APB
    // wait-state cycle.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == WRITE_ACCESS) &&
                !PREADY
            )) begin
                assert (FORMAL_STATE == WRITE_ACCESS);

                assert (PADDR  == $past(PADDR));
                assert (PWDATA == $past(PWDATA));
                assert (PWRITE == 1'b1);
            end
        end
    end

    // ------------------------------------------------------------
    // Read request information must remain stable for every APB
    // wait-state cycle.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == READ_ACCESS) &&
                !PREADY
            )) begin
                assert (FORMAL_STATE == READ_ACCESS);

                assert (PADDR  == $past(PADDR));
                assert (PWRITE == 1'b0);
            end
        end
    end

    // ============================================================
    // Phase 6 — APB response to AXI response mapping
    // ============================================================

    // ------------------------------------------------------------
    // Successful APB write completion must produce AXI OKAY.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == WRITE_ACCESS) &&
                PREADY &&
                !PSLVERR
            )) begin
                assert (FORMAL_STATE == WRITE_RESP);
                assert (BVALID == 1'b1);
                assert (BRESP  == 2'b00);
            end
        end
    end

    // ------------------------------------------------------------
    // APB write error must produce AXI SLVERR.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == WRITE_ACCESS) &&
                PREADY &&
                PSLVERR
            )) begin
                assert (FORMAL_STATE == WRITE_RESP);
                assert (BVALID == 1'b1);
                assert (BRESP  == 2'b10);
            end
        end
    end

    // ------------------------------------------------------------
    // Successful APB read completion must produce AXI OKAY and
    // return the APB read data.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == READ_ACCESS) &&
                PREADY &&
                !PSLVERR
            )) begin
                assert (FORMAL_STATE == READ_RESP);
                assert (RVALID == 1'b1);
                assert (RRESP  == 2'b00);
                assert (RDATA  == $past(PRDATA));
            end
        end
    end

    // ------------------------------------------------------------
    // APB read error must produce AXI SLVERR while still returning
    // the captured APB read data.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(
                (FORMAL_STATE == READ_ACCESS) &&
                PREADY &&
                PSLVERR
            )) begin
                assert (FORMAL_STATE == READ_RESP);
                assert (RVALID == 1'b1);
                assert (RRESP  == 2'b10);
                assert (RDATA  == $past(PRDATA));
            end
        end
    end

    // ------------------------------------------------------------
    // AXI write response must remain unchanged while BVALID is
    // asserted and the master has not accepted it.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(BVALID && !BREADY))
                assert (BRESP == $past(BRESP));
        end
    end

    // ------------------------------------------------------------
    // AXI read data and response must remain unchanged while RVALID
    // is asserted and the master has not accepted them.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin

            if ($past(RVALID && !RREADY)) begin
                assert (RDATA == $past(RDATA));
                assert (RRESP == $past(RRESP));
            end
        end
    end

    // ------------------------------------------------------------
    // BRESP may only contain responses implemented by this bridge:
    // OKAY or SLVERR.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && BVALID) begin
            assert (
                (BRESP == 2'b00) ||
                (BRESP == 2'b10)
            );
        end
    end

    // ------------------------------------------------------------
    // RRESP may only contain responses implemented by this bridge:
    // OKAY or SLVERR.
    // ------------------------------------------------------------
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && RVALID) begin
            assert (
                (RRESP == 2'b00) ||
                (RRESP == 2'b10)
            );
        end
    end

    // ============================================================
    // Phase 6 — Cover traces for waveform inspection
    // ============================================================

    // Successful APB write translated to AXI OKAY response.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == WRITE_RESP) &&
                BVALID &&
                (BRESP == 2'b00)
            );
        end
    end

    // APB write error translated to AXI SLVERR response.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == WRITE_RESP) &&
                BVALID &&
                (BRESP == 2'b10)
            );
        end
    end

    // Successful APB read translated to AXI OKAY response with data.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == READ_RESP) &&
                RVALID &&
                (RRESP == 2'b00)
            );
        end
    end

    // APB read error translated to AXI SLVERR response with data.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == READ_RESP) &&
                RVALID &&
                (RRESP == 2'b10)
            );
        end
    end

    // Complete AXI write transaction:
    // request accepted and response eventually consumed.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                write_pending &&
                BVALID &&
                BREADY
            );
        end
    end

    // Complete AXI read transaction:
    // request accepted and response eventually consumed.
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                read_pending &&
                RVALID &&
                RREADY
            );
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == IDLE) &&
                FORMAL_HAVE_AW &&
                !FORMAL_HAVE_W
            );
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn) begin
            cover (
                (FORMAL_STATE == IDLE) &&
                FORMAL_HAVE_W &&
                !FORMAL_HAVE_AW
            );
        end
    end
  
    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            cover (
                (FORMAL_STATE == WRITE_SETUP) &&
                $past(
                    AWVALID && AWREADY &&
                    WVALID  && WREADY
                )
            );
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            cover (
                (FORMAL_STATE == WRITE_SETUP) &&
                $past(
                    FORMAL_HAVE_AW &&
                    WVALID &&
                    WREADY
                )
            );
        end
    end

    always_ff @(posedge ACLK) begin
        if (f_past_valid && ARESETn && $past(ARESETn)) begin
            cover (
                (FORMAL_STATE == WRITE_SETUP) &&
                $past(
                    FORMAL_HAVE_W &&
                    AWVALID &&
                    AWREADY
                )
            );
        end
    end

endmodule