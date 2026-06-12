`timescale 1ns/1ps

// SPI Slave Testbench
// Tests all four command types in order:
//   1. Write address  (cmd = 2'b00)
//   2. Write data     (cmd = 2'b01)
//   3. Read address   (cmd = 2'b10)
//   4. Read data      (cmd = 2'b11)
//
// Frame format: 10 bits, MSB first.
// The first MOSI bit is sampled during CHK_CMD (one idle cycle after SS_n
// goes low), so the driver asserts bit [9] one cycle early and then shifts
// bits [8:0] on subsequent falling edges.

module SPI_TB;

    reg  clk, rst_n, SS_n, MOSI;
    wire MISO;

    reg  [9:0] frame;
    integer    i;

    // DUT
    SPI_Top dut (
        .clk   (clk),
        .rst_n (rst_n),
        .MOSI  (MOSI),
        .SS_n  (SS_n),
        .MISO  (MISO)
    );

    // 10 MHz clock (100 ns period)
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // Helper task: send a 10-bit SPI frame
    task send_frame;
        input [9:0] data;
        integer bit_idx;
        begin
            frame = data;
            @(negedge clk);
            SS_n = 1'b0;
            MOSI = frame[9];        // bit sampled by CHK_CMD

            repeat (2) @(negedge clk);  // let FSM reach WRITE / READ_ADD

            for (bit_idx = 8; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                MOSI = frame[bit_idx];
                @(negedge clk);
            end

            SS_n = 1'b1;
            MOSI = 1'b0;
            #20;
        end
    endtask

    // Main stimulus
    initial begin
        // Initialise
        rst_n = 1'b0;
        MOSI  = 1'b0;
        SS_n  = 1'b1;

        // Preload RAM with known data (optional; requires a mem.dat in sim dir)
        // $readmemh("mem.dat", dut.ram_inst.mem);

        // Release reset
        #40;
        rst_n = 1'b1;
        #20;

        // 1. Write address: target address = 0xFF
        send_frame(10'b00_1111_1111);

        // 2. Write data: value = 0x7D to address 0xFF
        send_frame(10'b01_0111_1101);

        // 3. Read address: source address = 0xFF
        send_frame(10'b10_1111_1111);

        // 4. Read data: triggers MISO output (address bits ignored by RAM,
        //    but the slave still clocks them in as the "read data" frame)
        @(negedge clk);
        SS_n = 1'b0;
        MOSI = 1'b1;                // cmd[1] = 1

        repeat (2) @(negedge clk);  // CHK_CMD → READ_DATA

        for (i = 8; i >= 0; i = i - 1) begin
            MOSI = 1'b0;            // address bits don't matter for this test
            @(negedge clk);
        end

        // Wait for all 8 MISO bits to be clocked out
        repeat (12) @(negedge clk);

        SS_n = 1'b1;
        MOSI = 1'b0;

        #50;
        $display("Simulation complete.");
        $stop;
    end

endmodule
