`timescale 1ns/1ps

// ============================================================
// APB INTERFACE
// ============================================================

interface apb_if;

    logic        PCLK;
    logic        PRESETn;

    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;

    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;


    // ========================================================
    // MASTER MODPORT
    // ========================================================

    modport master (
        input  PCLK,
        input  PRESETn,

        output PSEL,
        output PENABLE,
        output PWRITE,
        output PADDR,
        output PWDATA,

        input PRDATA,
        input PREADY,
        input PSLVERR
    );


    // ========================================================
    // SLAVE MODPORT
    // ========================================================

    modport slave (
        input PCLK,
        input PRESETn,

        input PSEL,
        input PENABLE,
        input PWRITE,
        input PADDR,
        input PWDATA,

        output PRDATA,
        output PREADY,
        output PSLVERR
    );

endinterface


// ============================================================
// APB RAM - SLAVE
// ============================================================

module apb_ram (
    apb_if.slave apb
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS,
        TRANSFER
    } state_t;

    state_t state;

    logic [31:0] mem [0:255];


    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin

        if (!apb.PRESETn) begin

            state       <= IDLE;
            apb.PRDATA  <= 32'd0;
            apb.PREADY  <= 1'b0;
            apb.PSLVERR <= 1'b0;

        end

        else begin

            case (state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                IDLE: begin

                    apb.PREADY <= 1'b0;

                    if (apb.PSEL)
                        state <= SETUP;

                end


                // ------------------------------------------------
                // SETUP
                // ------------------------------------------------

                SETUP: begin

                    apb.PREADY <= 1'b0;

                    if (apb.PSEL && apb.PENABLE)
                        state <= ACCESS;
                    else
                        state <= IDLE;

                end


                // ------------------------------------------------
                // ACCESS
                // ------------------------------------------------

                ACCESS: begin

                    if (apb.PWRITE) begin

                        mem[apb.PADDR] <= apb.PWDATA;

                        $display(
                            "[DUT] WRITE: addr = %h, data = %h",
                            apb.PADDR,
                            apb.PWDATA
                        );

                    end

                    else begin

                        apb.PRDATA <= mem[apb.PADDR];

                        $display(
                            "[DUT] READ: addr = %h, data = %h",
                            apb.PADDR,
                            mem[apb.PADDR]
                        );

                    end

                    state <= TRANSFER;

                end


                // ------------------------------------------------
                // TRANSFER
                // ------------------------------------------------

                TRANSFER: begin

                    apb.PREADY <= 1'b1;

                    if (apb.PSEL)
                        state <= SETUP;
                    else
                        state <= IDLE;

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule