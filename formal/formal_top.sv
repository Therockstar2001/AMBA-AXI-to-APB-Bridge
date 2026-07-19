`timescale 1ns/1ps

module formal_top;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // Formal global clock.
    (* gclk *) logic ACLK;

    logic ARESETn;

    // Symbolic AXI master inputs.
    (* anyseq *) logic [ADDR_WIDTH-1:0]     AWADDR;
    (* anyseq *) logic                      AWVALID;

    (* anyseq *) logic [DATA_WIDTH-1:0]     WDATA;
    (* anyseq *) logic [(DATA_WIDTH/8)-1:0] WSTRB;
    (* anyseq *) logic                      WVALID;

    (* anyseq *) logic                      BREADY;

    (* anyseq *) logic [ADDR_WIDTH-1:0]     ARADDR;
    (* anyseq *) logic                      ARVALID;

    (* anyseq *) logic                      RREADY;

    // Symbolic APB slave inputs.
    (* anyseq *) logic [DATA_WIDTH-1:0]     PRDATA;
    (* anyseq *) logic                      PREADY;
    (* anyseq *) logic                      PSLVERR;

    // DUT outputs.
    logic                      AWREADY;
    logic                      WREADY;
    logic [1:0]                BRESP;
    logic                      BVALID;

    logic                      ARREADY;
    logic [DATA_WIDTH-1:0]     RDATA;
    logic [1:0]                RRESP;
    logic                      RVALID;

    logic [ADDR_WIDTH-1:0]     PADDR;
    logic                      PSEL;
    logic                      PENABLE;
    logic                      PWRITE;
    logic [DATA_WIDTH-1:0]     PWDATA;
    logic [2:0] FORMAL_STATE;

    // Deterministic formal reset:
    // asserted initially and released after the first rising edge.
    initial ARESETn = 1'b0;

    always_ff @(posedge ACLK)
        ARESETn <= 1'b1;

    axi_lite_to_apb_bridge_flat #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .ACLK     (ACLK),
        .ARESETn  (ARESETn),

        .AWADDR   (AWADDR),
        .AWVALID  (AWVALID),
        .AWREADY  (AWREADY),

        .WDATA    (WDATA),
        .WSTRB    (WSTRB),
        .WVALID   (WVALID),
        .WREADY   (WREADY),

        .BRESP    (BRESP),
        .BVALID   (BVALID),
        .BREADY   (BREADY),

        .ARADDR   (ARADDR),
        .ARVALID  (ARVALID),
        .ARREADY  (ARREADY),

        .RDATA    (RDATA),
        .RRESP    (RRESP),
        .RVALID   (RVALID),
        .RREADY   (RREADY),

        .PADDR    (PADDR),
        .PSEL     (PSEL),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PWDATA   (PWDATA),
        .PRDATA   (PRDATA),
        .PREADY   (PREADY),
        .PSLVERR  (PSLVERR),
        .FORMAL_STATE (FORMAL_STATE)
    );

    axi_apb_properties #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) properties (
        .ACLK         (ACLK),
        .ARESETn      (ARESETn),

        .AWADDR      (AWADDR),
        .AWVALID     (AWVALID),

	.WDATA       (WDATA),
	.WVALID      (WVALID),
	.WSTRB       (WSTRB),
	.BREADY      (BREADY),

	.ARADDR      (ARADDR),
	.ARVALID     (ARVALID),

	.RREADY      (RREADY),

        .AWREADY      (AWREADY),
        .WREADY       (WREADY),
        .BRESP        (BRESP),
        .BVALID       (BVALID),

        .ARREADY      (ARREADY),
        .RDATA        (RDATA),
        .RRESP        (RRESP),
        .RVALID       (RVALID),
	.PRDATA       (PRDATA),
        .PREADY       (PREADY),
	.PSLVERR      (PSLVERR),
        .PADDR        (PADDR),
        .PSEL         (PSEL),
        .PENABLE      (PENABLE),
        .PWRITE       (PWRITE),
        .PWDATA       (PWDATA),

        .FORMAL_STATE (FORMAL_STATE)
    );

endmodule