`timescale 1ns/1ps

module axi_lite_to_apb_bridge_flat #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // AXI-Lite write-address channel
    input  logic [ADDR_WIDTH-1:0]     AWADDR,
    input  logic                      AWVALID,
    output logic                      AWREADY,

    // AXI-Lite write-data channel
    input  logic [DATA_WIDTH-1:0]     WDATA,
    input  logic [(DATA_WIDTH/8)-1:0] WSTRB,
    input  logic                      WVALID,
    output logic                      WREADY,

    // AXI-Lite write-response channel
    output logic [1:0]                BRESP,
    output logic                      BVALID,
    input  logic                      BREADY,

    // AXI-Lite read-address channel
    input  logic [ADDR_WIDTH-1:0]     ARADDR,
    input  logic                      ARVALID,
    output logic                      ARREADY,

    // AXI-Lite read-data channel
    output logic [DATA_WIDTH-1:0]     RDATA,
    output logic [1:0]                RRESP,
    output logic                      RVALID,
    input  logic                      RREADY,

    // APB master interface
    output logic [ADDR_WIDTH-1:0]     PADDR,
    output logic                      PSEL,
    output logic                      PENABLE,
    output logic                      PWRITE,
    output logic [DATA_WIDTH-1:0]     PWDATA,
    input  logic [DATA_WIDTH-1:0]     PRDATA,
    input  logic                      PREADY,
    input  logic                      PSLVERR,
    output logic [2:0]                FORMAL_STATE
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

    state_t state;
    state_t next_state;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic                  write_en;

    logic [1:0]            bresp_reg;
    logic [1:0]            rresp_reg;
    logic [DATA_WIDTH-1:0] rdata_reg;

    // WSTRB is present at the AXI boundary but the current RTL bridge
    // supports full-word transfers and does not process byte strobes.

    assign AWREADY = (state == IDLE) && WVALID;
    assign WREADY  = (state == IDLE) && AWVALID;
    assign ARREADY = (state == IDLE) &&
                     !(AWVALID && WVALID);

    assign BRESP = bresp_reg;
    assign RRESP = rresp_reg;
    assign RDATA = rdata_reg;

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (AWVALID && WVALID)
                    next_state = WRITE_SETUP;
                else if (ARVALID)
                    next_state = READ_SETUP;
            end

            WRITE_SETUP:
                next_state = WRITE_ACCESS;

            WRITE_ACCESS: begin
                if (PREADY)
                    next_state = WRITE_RESP;
            end

            WRITE_RESP: begin
                if (BREADY)
                    next_state = IDLE;
            end

            READ_SETUP:
                next_state = READ_ACCESS;

            READ_ACCESS: begin
                if (PREADY)
                    next_state = READ_RESP;
            end

            READ_RESP: begin
                if (RREADY)
                    next_state = IDLE;
            end

            default:
                next_state = IDLE;
        endcase
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            addr_reg  <= '0;
            wdata_reg <= '0;
            write_en  <= 1'b0;
            bresp_reg <= 2'b00;
            rresp_reg <= 2'b00;
            rdata_reg <= '0;
        end
        else begin
            if (state == IDLE) begin
                if (AWVALID && WVALID) begin
                    addr_reg  <= AWADDR;
                    wdata_reg <= WDATA;
                    write_en  <= 1'b1;
                end
                else if (ARVALID) begin
                    addr_reg <= ARADDR;
                    write_en <= 1'b0;
                end
            end

            if ((state == WRITE_ACCESS) && PREADY)
                bresp_reg <= PSLVERR ? 2'b10 : 2'b00;

            if ((state == READ_ACCESS) && PREADY) begin
                rdata_reg <= PRDATA;
                rresp_reg <= PSLVERR ? 2'b10 : 2'b00;
            end
        end
    end

    assign PADDR  = addr_reg;
    assign PWDATA = wdata_reg;
    assign PWRITE = write_en;

    assign PSEL =
        (state == WRITE_SETUP)  ||
        (state == WRITE_ACCESS) ||
        (state == READ_SETUP)   ||
        (state == READ_ACCESS);

    assign PENABLE =
        (state == WRITE_ACCESS) ||
        (state == READ_ACCESS);

    assign BVALID = (state == WRITE_RESP);
    assign RVALID = (state == READ_RESP);
    assign FORMAL_STATE = state;

endmodule