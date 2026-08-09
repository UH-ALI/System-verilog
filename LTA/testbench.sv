`timescale 1ns/1ps

// ============================================================
// APB TRANSACTION
// ============================================================

class apb_transaction;

    // Request information
    rand bit        write;
    rand bit [7:0]  addr;
    rand bit [31:0] wdata;

    // Response information
    bit [31:0] rdata;
    bit        slverr;


    // Display transaction
    function void display();

        $display(
            "[TRANSACTION] write=%0d addr=%h wdata=%h rdata=%h",
            write,
            addr,
            wdata,
            rdata
        );

    endfunction

endclass



// ============================================================
// APB DRIVER
// ============================================================

class apb_driver;

    // --------------------------------------------------------
    // VIRTUAL INTERFACE
    // --------------------------------------------------------

    virtual apb_if.master vif;


    // --------------------------------------------------------
    // CONSTRUCTOR
    // --------------------------------------------------------

    function new(virtual apb_if.master vif);

        this.vif = vif;

    endfunction


    // --------------------------------------------------------
    // WRITE TASK
    // --------------------------------------------------------

    task write(apb_transaction tr);

        $display(
            "[DRIVER] WRITE addr=%h data=%h",
            tr.addr,
            tr.wdata
        );


        // ----------------------------------------------------
        // SETUP PHASE
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PSEL    <= 1'b1;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b1;
        vif.PADDR   <= tr.addr;
        vif.PWDATA  <= tr.wdata;


        // ----------------------------------------------------
        // ACCESS PHASE
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PENABLE <= 1'b1;


        // ----------------------------------------------------
        // WAIT FOR NEW PREADY
        // ----------------------------------------------------

        // PREADY may still be high from the previous
        // transaction. First wait for it to go LOW.

        while (vif.PREADY)
            @(posedge vif.PCLK);


        // Now wait for PREADY belonging to THIS transaction.

        while (!vif.PREADY)
            @(posedge vif.PCLK);


        // ----------------------------------------------------
        // END TRANSACTION
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b0;


        $display("[DRIVER] WRITE COMPLETE");

    endtask



    // --------------------------------------------------------
    // READ TASK
    // --------------------------------------------------------

    task read(apb_transaction tr);

        $display(
            "[DRIVER] READ addr=%h",
            tr.addr
        );


        // ----------------------------------------------------
        // SETUP PHASE
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PSEL    <= 1'b1;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b0;
        vif.PADDR   <= tr.addr;


        // ----------------------------------------------------
        // ACCESS PHASE
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PENABLE <= 1'b1;


        // ----------------------------------------------------
        // WAIT FOR NEW PREADY
        // ----------------------------------------------------

        // PREADY may still be high from the previous
        // transaction. First wait for it to go LOW.

        while (vif.PREADY)
            @(posedge vif.PCLK);


        // Now wait for PREADY belonging to THIS transaction.

        while (!vif.PREADY)
            @(posedge vif.PCLK);


        // ----------------------------------------------------
        // CAPTURE READ DATA
        // ----------------------------------------------------

        tr.rdata = vif.PRDATA;


        // ----------------------------------------------------
        // END TRANSACTION
        // ----------------------------------------------------

        @(posedge vif.PCLK);

        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;


        $display(
            "[DRIVER] READ COMPLETE: data=%h",
            tr.rdata
        );

    endtask



    // --------------------------------------------------------
    // DRIVE TRANSACTION
    // --------------------------------------------------------

    task drive(apb_transaction tr);

        if (tr.write)
            write(tr);
        else
            read(tr);

    endtask

endclass



// ============================================================
// TESTBENCH
// ============================================================

module tb_apb_ram;

    // --------------------------------------------------------
    // CREATE REAL APB INTERFACE
    // --------------------------------------------------------

    apb_if apb();


    // --------------------------------------------------------
    // INSTANTIATE DUT
    // --------------------------------------------------------

    apb_ram uut (
        .apb(apb)
    );


    // --------------------------------------------------------
    // CLOCK
    // --------------------------------------------------------

    initial begin

        apb.PCLK = 1'b0;

        forever
            #5 apb.PCLK = ~apb.PCLK;

    end


    // --------------------------------------------------------
    // TEST
    // --------------------------------------------------------

    initial begin

        apb_driver      driver;
        apb_transaction tr;
        bit [31:0]      expected_data;


        expected_data = 32'h00000001;


        // ====================================================
        // INITIALIZE SIGNALS
        // ====================================================

        apb.PRESETn = 1'b0;

        apb.PSEL    = 1'b0;
        apb.PENABLE = 1'b0;
        apb.PWRITE  = 1'b0;
        apb.PADDR   = 8'd0;
        apb.PWDATA  = 32'd0;


        // ====================================================
        // CREATE DRIVER
        // ====================================================

        driver = new(apb);


        // ====================================================
        // RESET
        // ====================================================

        $display("");
        $display("==============================");
        $display("           RESET");
        $display("==============================");

        repeat (2)
            @(posedge apb.PCLK);

        apb.PRESETn = 1'b1;


        // ====================================================
        // WRITE
        // ====================================================

        $display("");
        $display("==============================");
        $display("         WRITE TEST");
        $display("==============================");

        tr = new();

        tr.write = 1'b1;
        tr.addr  = 8'h00;
        tr.wdata = expected_data;

        tr.display();

        driver.drive(tr);


        // ====================================================
        // READ
        // ====================================================

        $display("");
        $display("==============================");
        $display("          READ TEST");
        $display("==============================");

        tr = new();

        tr.write = 1'b0;
        tr.addr  = 8'h00;

        tr.display();

        driver.drive(tr);


        // ====================================================
        // CHECK RESULT
        // ====================================================

        $display("");
        $display("==============================");
        $display("        CHECK RESULT");
        $display("==============================");

        if (tr.rdata == expected_data) begin

            $display("TEST PASSED");

            $display(
                "Expected = %h, Got = %h",
                expected_data,
                tr.rdata
            );

        end

        else begin

            $display("TEST FAILED");

            $display(
                "Expected = %h, Got = %h",
                expected_data,
                tr.rdata
            );

        end


        // ====================================================
        // FINISH
        // ====================================================

        #20;

        $finish;

    end


    // --------------------------------------------------------
    // WAVEFORM
    // --------------------------------------------------------

    initial begin

        $dumpfile("test.vcd");
        $dumpvars(0, tb_apb_ram);

    end

endmodule