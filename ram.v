// Single-port synchronous RAM for SPI slave backend
// Command encoding via din[9:8]:
//   2'b00 = latch write address
//   2'b01 = write data to write_address
//   2'b10 = latch read address
//   2'b11 = read data from read_address → dout, assert tx_valid

module ram #(
    parameter MEM_WIDTH = 8,
    parameter MEM_DEPTH = 256,
    parameter ADDR_BITS = 8
)(
    input                  clk,
    input                  rst_n,
    input                  rx_valid,
    input      [9:0]       din,
    output reg [7:0]       dout,
    output reg             tx_valid
);

    reg [MEM_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    reg [ADDR_BITS-1:0] wr_addr, rd_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout     <= 8'b0;
            tx_valid <= 1'b0;
            wr_addr  <= {ADDR_BITS{1'b0}};
            rd_addr  <= {ADDR_BITS{1'b0}};
        end else begin
            tx_valid <= 1'b0;   // default; overridden on read-data command

            if (rx_valid) begin
                case (din[9:8])
                    2'b00: wr_addr         <= din[7:0];  // write address
                    2'b01: mem[wr_addr]    <= din[7:0];  // write data
                    2'b10: rd_addr         <= din[7:0];  // read address
                    2'b11: begin                          // read data
                        dout     <= mem[rd_addr];
                        tx_valid <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
