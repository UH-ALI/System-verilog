interface apb_if;

    logic [31:0] add;
    logic [31:0] data;
    logic        writing;

    logic [31:0] read_data;


    // Driver → DUT
    modport DRIVER (
        output add,
        output data,
        output writing
    );


    // DUT receives request and produces read data
    modport DUT (
        input  add,
        input  data,
        input  writing,
        output read_data
    );


    // Monitor observes everything
    modport MONITOR (
        input add,
        input data,
        input writing,
        input read_data
    );

endinterface


module slave(apb_if.DUT vif);

    logic [31:0] mem [0:255];

    initial begin
        for (int i = 0; i < 256; i++)
            mem[i] = 32'b0;

        vif.read_data = 32'b0;
    end

    always @(*) begin

        if (vif.writing) begin

            mem[vif.add] = vif.data;

            $display("[DUT] WRITE : ADD=%0d DATA=%h",
                     vif.add, vif.data);

        end
        else begin

            vif.read_data = mem[vif.add];

            $display("[DUT] READ  : ADD=%0d DATA=%h",
                     vif.add, vif.read_data);

        end

    end

endmodule