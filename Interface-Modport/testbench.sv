class transaction;

    rand bit [31:0] add;
    rand bit [31:0] data;
    rand bit        writing;


    // Address must stay between 0 and 255
    constraint address_c {
        add inside {[0:255]};
    }


    function void display(string tag);

        $display(
            "[%s] ADD=%0d DATA=%h WRITE=%b",
            tag,
            add,
            data,
            writing
        );

    endfunction

endclass

class generator;

    transaction tr;

    mailbox gen2drv;


    function new(mailbox gen2drv);

        this.gen2drv = gen2drv;

    endfunction


    task run();

        repeat (10) begin

            tr = new();

            // Randomize transaction
            assert(tr.randomize())
            else $error("[GEN] Randomization failed");


            tr.display("GEN");


            // Send transaction to driver
            gen2drv.put(tr);

            #10;

        end

    endtask

endclass

class driver;

    transaction tr;

    mailbox gen2drv;

    virtual apb_if.DRIVER vif;


    function new(
        mailbox gen2drv,
        virtual apb_if.DRIVER vif
    );

        this.gen2drv = gen2drv;
        this.vif = vif;

    endfunction


    task run();

        repeat (10) begin

            // Receive transaction
            gen2drv.get(tr);


            // Transaction → hardware signals
            vif.add     = tr.add;
            vif.data    = tr.data;
            vif.writing = tr.writing;


            tr.display("DRV");


            #10;

        end

    endtask

endclass

class monitor;

    transaction tr;

    virtual apb_if.MONITOR vif;

    mailbox mon2sb;


    function new(
        virtual apb_if.MONITOR vif,
        mailbox mon2sb
    );

        this.vif = vif;
        this.mon2sb = mon2sb;

    endfunction


    task run();

        repeat (10) begin

            #1;

            tr = new();


            // Hardware → transaction
            tr.add     = vif.add;
            tr.writing = vif.writing;


            if (vif.writing) begin

                // WRITE
                tr.data = vif.data;

            end

            else begin

                // READ
                tr.data = vif.read_data;

            end


            tr.display("MON");


            // Send observed transaction
            // to scoreboard
            mon2sb.put(tr);


            #9;

        end

    endtask

endclass

class scoreboard;

    transaction tr;

    mailbox mon2sb;

    logic [31:0] expected_mem [0:255];

    integer i;

    integer pass_count = 0;
    integer fail_count = 0;


    function new(mailbox mon2sb);

        this.mon2sb = mon2sb;

        // Initialize reference memory
        for (i = 0; i < 256; i++)
            expected_mem[i] = 32'b0;

    endfunction


    task run();

        repeat (10) begin

            // Receive observed transaction
            mon2sb.get(tr);


            if (tr.writing) begin

                // For WRITE:
                // update expected memory

                expected_mem[tr.add] = tr.data;


                $display(
                    "[SCOREBOARD] WRITE : ADD=%0d DATA=%h",
                    tr.add,
                    tr.data
                );

            end

            else begin

                // For READ:
                // compare DUT result
                // against expected result

                if (tr.data == expected_mem[tr.add]) begin

                    $display(
                        "[SCOREBOARD] READ PASS : ADD=%0d EXPECTED=%h ACTUAL=%h",
                        tr.add,
                        expected_mem[tr.add],
                        tr.data
                    );

                    pass_count++;

                end

                else begin

                    $display(
                        "[SCOREBOARD] READ FAIL : ADD=%0d EXPECTED=%h ACTUAL=%h",
                        tr.add,
                        expected_mem[tr.add],
                        tr.data
                    );

                    fail_count++;

                end

            end

        end


        $display("----------------------------------------");
        $display("SCOREBOARD RESULT");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("----------------------------------------");

    endtask

endclass

module tb;

    // Mailboxes
    mailbox gen2drv;
    mailbox mon2sb;


    // Verification components
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sb;


    // Interface
    apb_if vif();


    // DUT
    slave dut(vif);


    initial begin

        // Create mailboxes
        gen2drv = new();
        mon2sb  = new();
      
      	$dumpfile("wave.vcd");
        $dumpvars(0, tb);

        // Create components
        gen = new(gen2drv);

        drv = new(
            gen2drv,
            vif
        );

        mon = new(
            vif,
            mon2sb
        );

        sb = new(
            mon2sb
        );


        // Run concurrently
        fork

            gen.run();

            drv.run();

            mon.run();

            sb.run();

        join


        $display("========================================");
        $display("           TEST COMPLETED");
        $display("========================================");


        $finish;

    end

endmodule
