// SPI Slave FSM
// Protocol: 10-bit frames (2 command bits + 8 data/address bits)
// Command bits [9:8]:
//   00 = write address   01 = write data
//   10 = read address    11 = read data (clocks out MISO)

module SPI_slave (
    input        clk,
    input        rst_n,
    input        SS_n,
    input        MOSI,
    input        tx_valid,
    input  [7:0] tx_data,
    output reg [9:0] rx_data,
    output reg       rx_valid,
    output reg       MISO
);

    // ---------- FSM state encoding ----------
    localparam [2:0]
        IDLE      = 3'd0,
        CHK_CMD   = 3'd1,
        WRITE     = 3'd2,
        READ_ADD  = 3'd3,
        READ_DATA = 3'd4;

    reg [2:0] state, nxt_state;
    reg [3:0] bit_ctr;          // counts bits remaining to shift
    reg       addr_latched;     // set after READ_ADD completes, cleared after READ_DATA

    // ---------- Next-state logic (combinational) ----------
    always @(*) begin
        nxt_state = state;
        if (SS_n) begin
            nxt_state = IDLE;
        end else begin
            case (state)
                IDLE:
                    nxt_state = CHK_CMD;

                CHK_CMD:
                    if      (!MOSI)        nxt_state = WRITE;
                    else if (addr_latched) nxt_state = READ_DATA;
                    else                   nxt_state = READ_ADD;

                WRITE:
                    nxt_state = (bit_ctr == 0) ? IDLE : WRITE;

                READ_ADD:
                    nxt_state = (bit_ctr == 0) ? IDLE : READ_ADD;

                READ_DATA:
                    // Stay until the full byte has been clocked out
                    nxt_state = (tx_valid && bit_ctr == 0) ? IDLE : READ_DATA;

                default:
                    nxt_state = IDLE;
            endcase
        end
    end

    // ---------- Sequential datapath ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            rx_data      <= 10'd0;
            rx_valid     <= 1'b0;
            MISO         <= 1'b0;
            bit_ctr      <= 4'd0;
            addr_latched <= 1'b0;
        end else begin
            state    <= nxt_state;
            rx_valid <= 1'b0;   // default; overridden below when a frame completes

            case (state)
                // ---- Preload counter so it's ready the moment we enter WRITE / READ_ADD ----
                IDLE: begin
                    bit_ctr <= 4'd9;  // 10 bits: indices 9..0 (bit 9 is the first MOSI bit
                                      // captured in CHK_CMD, so we load 9 here and count
                                      // down the remaining 9 bits in the data states)
                end

                CHK_CMD: begin
                    // The first MOSI bit (cmd[1]) was sampled here; store it
                    rx_data[9] <= MOSI;
                    // bit_ctr stays at 9; data states will consume bits 8..0
                end

                WRITE, READ_ADD: begin
                    if (bit_ctr != 0) begin
                        rx_data[bit_ctr - 1] <= MOSI;
                        bit_ctr              <= bit_ctr - 1;
                    end else begin
                        // Final bit already stored in the cycle that decremented to 0;
                        // assert rx_valid for one cycle to trigger the RAM
                        rx_valid <= 1'b1;
                        if (state == READ_ADD)
                            addr_latched <= 1'b1;
                    end
                end

                READ_DATA: begin
                    if (!tx_valid) begin
                        // Phase 1: shift in the 10-bit address frame (reusing rx_data / bit_ctr)
                        if (bit_ctr != 0) begin
                            rx_data[bit_ctr - 1] <= MOSI;
                            bit_ctr              <= bit_ctr - 1;
                        end else begin
                            rx_valid <= 1'b1;   // ask RAM for the data
                            bit_ctr  <= 4'd7;   // prepare 8-bit MISO counter
                        end
                    end else begin
                        // Phase 2: clock out tx_data on MISO
                        if (bit_ctr != 0) begin
                            MISO    <= tx_data[bit_ctr - 1];
                            bit_ctr <= bit_ctr - 1;
                        end else begin
                            addr_latched <= 1'b0;   // read transaction complete
                        end
                    end
                end

                default: ; // IDLE reset already handled above
            endcase
        end
    end

endmodule
