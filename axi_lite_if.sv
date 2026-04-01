`timescale 1ns/1ps

interface axi_lite_if #(parameter ADDR_WIDTH = 32,
                         parameter DATA_WIDTH = 32)
                        (input logic ACLK,
                         input logic ARESETn);

    // -----------------------------
    // WRITE ADDRESS CHANNEL
    // -----------------------------
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic                  AWVALID;
    logic                  AWREADY;

    // -----------------------------
    // WRITE DATA CHANNEL
    // -----------------------------
    logic [DATA_WIDTH-1:0] WDATA;
    logic [(DATA_WIDTH/8)-1:0] WSTRB;
    logic                  WVALID;
    logic                  WREADY;

    // -----------------------------
    // WRITE RESPONSE CHANNEL
    // -----------------------------
    logic [1:0] BRESP;
    logic       BVALID;
    logic       BREADY;

    // -----------------------------
    // READ ADDRESS CHANNEL
    // -----------------------------
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic                  ARVALID;
    logic                  ARREADY;

    // -----------------------------
    // READ DATA CHANNEL
    // -----------------------------
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RVALID;
    logic                  RREADY;

    // -----------------------------
    // MODPORTS
    // -----------------------------

    // MASTER (Driver side)
    modport master (
        input  ACLK, ARESETn,
        output AWADDR, AWVALID,
        input  AWREADY,

        output WDATA, WSTRB, WVALID,
        input  WREADY,

        input  BRESP, BVALID,
        output BREADY,

        output ARADDR, ARVALID,
        input  ARREADY,

        input  RDATA, RRESP, RVALID,
        output RREADY
    );

    // SLAVE (DUT side)
    modport slave (
        input  ACLK, ARESETn,
        input  AWADDR, AWVALID,
        output AWREADY,

        input  WDATA, WSTRB, WVALID,
        output WREADY,

        output BRESP, BVALID,
        input  BREADY,

        input  ARADDR, ARVALID,
        output ARREADY,

        output RDATA, RRESP, RVALID,
        input  RREADY
    );

endinterface