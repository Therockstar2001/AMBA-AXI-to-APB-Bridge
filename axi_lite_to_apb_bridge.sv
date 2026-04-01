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

    logic [1:0] bresp_reg;
    logic [1:0] rresp_reg;
    logic [DATA_WIDTH-1:0] rdata_reg;

    // -----------------------------
    // AXI READY SIGNALS
    // -----------------------------
    assign axi.AWREADY = (state == IDLE);
    assign axi.WREADY  = (state == IDLE);
    assign axi.ARREADY = (state == IDLE);

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
                if (axi.AWVALID && axi.WVALID)
                    next_state = WRITE_SETUP;
                else if (axi.ARVALID)
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
            bresp_reg <= 2'b00;
            rresp_reg <= 2'b00;
            rdata_reg <= '0;
        end
        else begin
            if (state == IDLE) begin
                if (axi.AWVALID && axi.WVALID) begin
                    addr_reg  <= axi.AWADDR;
                    wdata_reg <= axi.WDATA;
                    write_en  <= 1'b1;
                end
                else if (axi.ARVALID) begin
                    addr_reg <= axi.ARADDR;
                    write_en <= 1'b0;
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