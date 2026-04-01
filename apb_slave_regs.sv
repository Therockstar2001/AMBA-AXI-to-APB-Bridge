module apb_slave_regs #(
    parameter ADDR_WIDTH  = 8,
    parameter DATA_WIDTH  = 32,
    parameter NUM_REGS    = 4,
    parameter MAX_WAIT    = 3
)(
    apb_if.slave apb
);

    logic [DATA_WIDTH-1:0] reg_array [0:NUM_REGS-1];
    logic [DATA_WIDTH-1:0] prdata_next;
    logic                  pslverr_next;

    logic [1:0] addr_index;
    logic       valid_addr;
    logic       apb_access;

    integer wait_count;
    integer wait_target;
    logic   in_access_phase;

    assign apb_access = apb.PSEL && apb.PENABLE;
    assign addr_index = apb.PADDR[3:2];
    assign valid_addr = (apb.PADDR[1:0] == 2'b00) && (apb.PADDR < (NUM_REGS * 4));

    always_comb begin
        prdata_next  = apb.PRDATA;
        pslverr_next = 1'b0;

        if (apb_access && (wait_count == wait_target)) begin
            if (!valid_addr) begin
                pslverr_next = 1'b1;
                prdata_next  = '0;
            end
            else if (!apb.PWRITE) begin
                prdata_next = reg_array[addr_index];
            end
            else begin
                prdata_next = '0;
            end
        end
    end

    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
        integer i;
        if (!apb.PRESETn) begin
            for (i = 0; i < NUM_REGS; i++) begin
                reg_array[i] <= '0;
            end
            apb.PRDATA       <= '0;
            apb.PREADY       <= 1'b0;
            apb.PSLVERR      <= 1'b0;
            wait_count       <= 0;
            wait_target      <= 0;
            in_access_phase  <= 1'b0;
        end
        else begin
            apb.PSLVERR <= 1'b0;

            if (apb_access) begin
                if (!in_access_phase) begin
                    // First cycle of this APB access phase
                    in_access_phase <= 1'b1;
                    wait_count      <= 0;
                    wait_target     <= $urandom_range(0, MAX_WAIT);
                    apb.PREADY      <= 1'b0;
                end
                else if (wait_count < wait_target) begin
                    wait_count <= wait_count + 1;
                    apb.PREADY <= 1'b0;
                end
                else begin
                    apb.PREADY  <= 1'b1;
                    apb.PRDATA  <= prdata_next;
                    apb.PSLVERR <= pslverr_next;

                    if (apb.PWRITE && valid_addr) begin
                        reg_array[addr_index] <= apb.PWDATA;
                    end
                end
            end
            else begin
                wait_count      <= 0;
                wait_target     <= 0;
                in_access_phase <= 1'b0;
                apb.PREADY      <= 1'b0;
                apb.PRDATA      <= '0;
            end
        end
    end

endmodule