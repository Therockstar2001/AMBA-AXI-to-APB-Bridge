`timescale 1ns/1ps

module axi_lite_to_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    axi_lite_if.slave axi,
    apb_if.master     apb
);

    typedef enum logic [2:0] {
        IDLE,
        WRITE_SETUP,
        WRITE_ACCESS,
        WRITE_RESP,
        READ_SETUP,
        READ_ACCESS,
        READ_RESP
    } state_t;

    state_t state, next_state;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic                  write_en;

    logic have_aw;
    logic have_w;

    logic aw_accept; 
    logic w_accept;
    logic ar_accept;
    logic write_start;

    logic [1:0] bresp_reg;
    logic [1:0] rresp_reg;
    logic [DATA_WIDTH-1:0] rdata_reg;

    // -----------------------------
    // AXI READY SIGNALS
    // -----------------------------
    // ------------------------------------------------------------
    // Independent AXI write-channel acceptance
    // ------------------------------------------------------------

    assign axi.AWREADY =
       (state == IDLE) &&
       !have_aw;

    assign axi.WREADY =
       (state == IDLE) &&
       !have_w;

    // Read is accepted only when there is no partial or incoming
    // write request. This preserves write priority and prevents
    // accepting a read while one half of a write is buffered.
    assign axi.ARREADY =
        (state == IDLE) &&
        !have_aw &&
        !have_w &&
        !axi.AWVALID &&
        !axi.WVALID;

    assign aw_accept = axi.AWVALID && axi.AWREADY;
    assign w_accept  = axi.WVALID  && axi.WREADY;
    assign ar_accept = axi.ARVALID && axi.ARREADY;

    // A write may begin when both components are available,
    // whether captured previously or accepted this cycle.
    assign write_start =
        (have_aw || aw_accept) &&
        (have_w  || w_accept);

    // -----------------------------
    // AXI RESPONSE OUTPUTS
    // -----------------------------
    assign axi.BRESP  = bresp_reg;
    assign axi.RRESP  = rresp_reg;
    assign axi.RDATA  = rdata_reg;

    // -----------------------------
    // STATE REGISTER
    // -----------------------------
    always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
        if (!axi.ARESETn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // -----------------------------
    // NEXT STATE LOGIC
    // -----------------------------
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (write_start)
                    next_state = WRITE_SETUP;
                else if (ar_accept)
                    next_state = READ_SETUP;
            end

            WRITE_SETUP: begin
                next_state = WRITE_ACCESS;
            end

            WRITE_ACCESS: begin
                if (apb.PREADY)
                    next_state = WRITE_RESP;
            end

            WRITE_RESP: begin
                if (axi.BREADY)
                    next_state = IDLE;
            end

            READ_SETUP: begin
                next_state = READ_ACCESS;
            end

            READ_ACCESS: begin
                if (apb.PREADY)
                    next_state = READ_RESP;
            end

            READ_RESP: begin
                if (axi.RREADY)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // -----------------------------
    // CAPTURE INPUTS / RESPONSES
    // -----------------------------
    always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
        if (!axi.ARESETn) begin
            addr_reg  <= '0;
            wdata_reg <= '0;
            write_en  <= 1'b0;
	    have_aw <= 1'b0;
	    have_w <= 1'b0;
            bresp_reg <= 2'b00;
            rresp_reg <= 2'b00;
            rdata_reg <= '0;
        end
        else begin
            if (state == IDLE) begin

                // Capture AW independently.
                if (aw_accept)
                    addr_reg <= axi.AWADDR;

                // Capture W independently.
                if (w_accept)
                    wdata_reg <= axi.WDATA;

      	        // Both write components are now available and will be
                // consumed by the APB write transaction.
                if (write_start) begin
                    write_en <= 1'b1;

                    have_aw <= 1'b0;
                    have_w  <= 1'b0;
                end
                else begin
                    // Preserve partial write information while waiting
                    // for the other independent AXI channel.
                    if (aw_accept)
                        have_aw <= 1'b1;

                    if (w_accept)
                        have_w <= 1'b1;

                    // A read can only be accepted when no write component
                    // is pending or arriving.
                    if (ar_accept) begin
                        addr_reg <= axi.ARADDR;
                        write_en <= 1'b0;
                    end
                end
            end

            if (state == WRITE_ACCESS && apb.PREADY) begin
                bresp_reg <= (apb.PSLVERR) ? 2'b10 : 2'b00; // SLVERR : OKAY
            end

            if (state == READ_ACCESS && apb.PREADY) begin
                rdata_reg <= apb.PRDATA;
                rresp_reg <= (apb.PSLVERR) ? 2'b10 : 2'b00; // SLVERR : OKAY
            end
        end
    end

    // -----------------------------
    // APB CONTROL SIGNALS
    // -----------------------------
    assign apb.PADDR   = addr_reg;
    assign apb.PWDATA  = wdata_reg;
    assign apb.PWRITE  = write_en;

    assign apb.PSEL    = (state == WRITE_SETUP) || (state == WRITE_ACCESS) ||
                         (state == READ_SETUP)  || (state == READ_ACCESS);

    assign apb.PENABLE = (state == WRITE_ACCESS) || (state == READ_ACCESS);

    // -----------------------------
    // AXI VALID OUTPUTS
    // -----------------------------
    assign axi.BVALID = (state == WRITE_RESP);
    assign axi.RVALID = (state == READ_RESP);

endmodule