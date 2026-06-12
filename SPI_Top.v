// SPI Top-level wrapper
// Connects SPI_slave (bit-serial framing) to the RAM backend.

module SPI_Top (
    input  clk,
    input  rst_n,
    input  MOSI,
    input  SS_n,
    output MISO
);

    wire [9:0] rx_data;
    wire       rx_valid;
    wire [7:0] tx_data;
    wire       tx_valid;

    SPI_slave spi_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .SS_n     (SS_n),
        .MOSI     (MOSI),
        .MISO     (MISO),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    ram ram_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_valid (rx_valid),
        .din      (rx_data),
        .dout     (tx_data),
        .tx_valid (tx_valid)
    );

endmodule
