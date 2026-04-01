interface apb_if #(parameter ADDR_WIDTH = 8, DATA_WIDTH = 32) (input logic PCLK, input logic PRESETn);

    logic [ADDR_WIDTH-1:0] PADDR;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PREADY;
    logic                  PSLVERR;

    modport master (
        input  PCLK,
        input  PRESETn,
        output PADDR,
        output PSEL,
        output PENABLE,
        output PWRITE,
        output PWDATA,
        input  PRDATA,
        input  PREADY,
        input  PSLVERR
    );

    modport slave (
        input  PCLK,
        input  PRESETn,
        input  PADDR,
        input  PSEL,
        input  PENABLE,
        input  PWRITE,
        input  PWDATA,
        output PRDATA,
        output PREADY,
        output PSLVERR
    );

endinterface