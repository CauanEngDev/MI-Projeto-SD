// ============================================================================
// TOP-LEVEL DE1-SoC COM HPS - COPROCESSADOR GRAFICO (BUSCA PASSIVA)
// ----------------------------------------------------------------------------
// Une o sistema Platform Designer (soc_system: HPS + avalon_cmd_slave) ao
// coprocessador grafico. O ARM escreve palavras da ISA no registrador CMD do
// avalon_cmd_slave (ponte Lightweight HPS-FPGA, base 0xFF200000); o slave as
// entrega a fila de comandos do coprocessador.
//
//   ARM --(ponte LW / Avalon-MM)--> soc_system.avalon_cmd_slave
//                                      |  cmd_wr / cmd_data / sw_rst  (saidas)
//                                      |  cmd_full / cmd_empty / st_* (entradas)
//                                      v
//                              coprocessador_top (BUSCA_PASSIVA = 1) --> VGA
//
// Este arquivo substitui o DE1_SOC_golden_top.v como TOP_LEVEL_ENTITY: aquele
// ainda instancia o top_video e o test_driver antigos. Ele mantem so os pinos
// necessarios (clock, KEY, LEDR, VGA e HPS), com os mesmos nomes do golden top,
// entao as atribuicoes de pinos do CoProcessador.qsf continuam valendo.
//
// ATENCAO: os nomes das portas de soc_system (memory_*, hps_0_hps_io_*, clk_*,
// reset_*, cmd_*, st_*, sw_rst) dependem de como as interfaces foram exportadas
// no Platform Designer. Confira com soc_system/synthesis/soc_system_inst.v (ou
// soc_system.bsf) depois de gerar o sistema. O mapeamento do HPS abaixo e o
// padrao Terasic da DE1-SoC (EMAC1, QSPI, SDIO, USB1, SPIM1, UART0, I2C0/1 e
// GPIOs da placa).
// ============================================================================

module de1_soc_hps_top (

    input              CLOCK_50,
    input       [3:0]  KEY,
    output      [9:0]  LEDR,

    output      [7:0]  VGA_B,
    output             VGA_BLANK_N,
    output             VGA_CLK,
    output      [7:0]  VGA_G,
    output             VGA_HS,
    output      [7:0]  VGA_R,
    output             VGA_SYNC_N,
    output             VGA_VS,

    /* HPS - pinos dedicados (DDR3, Ethernet, SD, USB, UART, etc.) */
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N, //1.5V
      output             HPS_DDR3_CK_P, //1.5V
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP
);

    // ------------------------------------------------------------------------
    // Sinais entre o soc_system (avalon_cmd_slave) e o coprocessador
    // ------------------------------------------------------------------------
    wire        cmd_wr;
    wire [31:0] cmd_data;
    wire        cmd_full;
    wire        cmd_empty;
    wire        sw_reset;

    wire        st_running;
    wire        st_waiting;
    wire        st_vblank;
    wire        st_error;
    wire        st_init_busy;
    wire        st_pll_locked;
    wire        st_frame_swap;

    // ------------------------------------------------------------------------
    // Sistema Platform Designer: HPS + ponte LW + avalon_cmd_slave
    // reset_reset_n = KEY[0]: o mesmo botao que reseta o coprocessador tambem
    // limpa os registradores do slave. Se o seu soc_system ligar o clk_0 a
    // outros resets importantes do HPS, troque por 1'b1.
    // ------------------------------------------------------------------------
    soc_system u_soc (
        .clk_clk       (CLOCK_50),
        .reset_reset_n (KEY[0]),

        // avalon_cmd_slave <-> coprocessador
        .cmd_wr        (cmd_wr),
        .cmd_data      (cmd_data),
        .cmd_full      (cmd_full),
        .cmd_empty     (cmd_empty),
        .st_running    (st_running),
        .st_waiting    (st_waiting),
        .st_vblank     (st_vblank),
        .st_error      (st_error),
        .st_init_busy  (st_init_busy),
        .st_pll_locked (st_pll_locked),
        .st_frame_swap (st_frame_swap),
        .sw_rst        (sw_reset),

        // DDR3 do HPS
        .memory_mem_a       (HPS_DDR3_ADDR),
        .memory_mem_ba      (HPS_DDR3_BA),
        .memory_mem_ck      (HPS_DDR3_CK_P),
        .memory_mem_ck_n    (HPS_DDR3_CK_N),
        .memory_mem_cke     (HPS_DDR3_CKE),
        .memory_mem_cs_n    (HPS_DDR3_CS_N),
        .memory_mem_ras_n   (HPS_DDR3_RAS_N),
        .memory_mem_cas_n   (HPS_DDR3_CAS_N),
        .memory_mem_we_n    (HPS_DDR3_WE_N),
        .memory_mem_reset_n (HPS_DDR3_RESET_N),
        .memory_mem_dq      (HPS_DDR3_DQ),
        .memory_mem_dqs     (HPS_DDR3_DQS_P),
        .memory_mem_dqs_n   (HPS_DDR3_DQS_N),
        .memory_mem_odt     (HPS_DDR3_ODT),
        .memory_mem_dm      (HPS_DDR3_DM),
        .memory_oct_rzqin   (HPS_DDR3_RZQ),

        // Ethernet (EMAC1)
        .hps_0_hps_io_hps_io_emac1_inst_TX_CLK (HPS_ENET_GTX_CLK),
        .hps_0_hps_io_hps_io_emac1_inst_TXD0   (HPS_ENET_TX_DATA[0]),
        .hps_0_hps_io_hps_io_emac1_inst_TXD1   (HPS_ENET_TX_DATA[1]),
        .hps_0_hps_io_hps_io_emac1_inst_TXD2   (HPS_ENET_TX_DATA[2]),
        .hps_0_hps_io_hps_io_emac1_inst_TXD3   (HPS_ENET_TX_DATA[3]),
        .hps_0_hps_io_hps_io_emac1_inst_RXD0   (HPS_ENET_RX_DATA[0]),
        .hps_0_hps_io_hps_io_emac1_inst_MDIO   (HPS_ENET_MDIO),
        .hps_0_hps_io_hps_io_emac1_inst_MDC    (HPS_ENET_MDC),
        .hps_0_hps_io_hps_io_emac1_inst_RX_CTL (HPS_ENET_RX_DV),
        .hps_0_hps_io_hps_io_emac1_inst_TX_CTL (HPS_ENET_TX_EN),
        .hps_0_hps_io_hps_io_emac1_inst_RX_CLK (HPS_ENET_RX_CLK),
        .hps_0_hps_io_hps_io_emac1_inst_RXD1   (HPS_ENET_RX_DATA[1]),
        .hps_0_hps_io_hps_io_emac1_inst_RXD2   (HPS_ENET_RX_DATA[2]),
        .hps_0_hps_io_hps_io_emac1_inst_RXD3   (HPS_ENET_RX_DATA[3]),

        // QSPI flash
        .hps_0_hps_io_hps_io_qspi_inst_IO0 (HPS_FLASH_DATA[0]),
        .hps_0_hps_io_hps_io_qspi_inst_IO1 (HPS_FLASH_DATA[1]),
        .hps_0_hps_io_hps_io_qspi_inst_IO2 (HPS_FLASH_DATA[2]),
        .hps_0_hps_io_hps_io_qspi_inst_IO3 (HPS_FLASH_DATA[3]),
        .hps_0_hps_io_hps_io_qspi_inst_SS0 (HPS_FLASH_NCSO),
        .hps_0_hps_io_hps_io_qspi_inst_CLK (HPS_FLASH_DCLK),

        // Cartao SD
        .hps_0_hps_io_hps_io_sdio_inst_CMD (HPS_SD_CMD),
        .hps_0_hps_io_hps_io_sdio_inst_D0  (HPS_SD_DATA[0]),
        .hps_0_hps_io_hps_io_sdio_inst_D1  (HPS_SD_DATA[1]),
        .hps_0_hps_io_hps_io_sdio_inst_CLK (HPS_SD_CLK),
        .hps_0_hps_io_hps_io_sdio_inst_D2  (HPS_SD_DATA[2]),
        .hps_0_hps_io_hps_io_sdio_inst_D3  (HPS_SD_DATA[3]),

        // USB
        .hps_0_hps_io_hps_io_usb1_inst_D0  (HPS_USB_DATA[0]),
        .hps_0_hps_io_hps_io_usb1_inst_D1  (HPS_USB_DATA[1]),
        .hps_0_hps_io_hps_io_usb1_inst_D2  (HPS_USB_DATA[2]),
        .hps_0_hps_io_hps_io_usb1_inst_D3  (HPS_USB_DATA[3]),
        .hps_0_hps_io_hps_io_usb1_inst_D4  (HPS_USB_DATA[4]),
        .hps_0_hps_io_hps_io_usb1_inst_D5  (HPS_USB_DATA[5]),
        .hps_0_hps_io_hps_io_usb1_inst_D6  (HPS_USB_DATA[6]),
        .hps_0_hps_io_hps_io_usb1_inst_D7  (HPS_USB_DATA[7]),
        .hps_0_hps_io_hps_io_usb1_inst_CLK (HPS_USB_CLKOUT),
        .hps_0_hps_io_hps_io_usb1_inst_STP (HPS_USB_STP),
        .hps_0_hps_io_hps_io_usb1_inst_DIR (HPS_USB_DIR),
        .hps_0_hps_io_hps_io_usb1_inst_NXT (HPS_USB_NXT),

        // SPI master
        .hps_0_hps_io_hps_io_spim1_inst_CLK  (HPS_SPIM_CLK),
        .hps_0_hps_io_hps_io_spim1_inst_MOSI (HPS_SPIM_MOSI),
        .hps_0_hps_io_hps_io_spim1_inst_MISO (HPS_SPIM_MISO),
        .hps_0_hps_io_hps_io_spim1_inst_SS0  (HPS_SPIM_SS),

        // UART (console serial do Linux)
        .hps_0_hps_io_hps_io_uart0_inst_RX (HPS_UART_RX),
        .hps_0_hps_io_hps_io_uart0_inst_TX (HPS_UART_TX),

        // I2C
        .hps_0_hps_io_hps_io_i2c0_inst_SDA (HPS_I2C1_SDAT),
        .hps_0_hps_io_hps_io_i2c0_inst_SCL (HPS_I2C1_SCLK),
        .hps_0_hps_io_hps_io_i2c1_inst_SDA (HPS_I2C2_SDAT),
        .hps_0_hps_io_hps_io_i2c1_inst_SCL (HPS_I2C2_SCLK),

        // GPIOs da placa
        .hps_0_hps_io_hps_io_gpio_inst_GPIO09 (HPS_CONV_USB_N),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO35 (HPS_ENET_INT_N),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO40 (HPS_LTC_GPIO),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO48 (HPS_I2C_CONTROL),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO53 (HPS_LED),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO54 (HPS_KEY),
        .hps_0_hps_io_hps_io_gpio_inst_GPIO61 (HPS_GSENSOR_INT)
    );

    // ------------------------------------------------------------------------
    // Coprocessador grafico em modo de busca passiva
    // ------------------------------------------------------------------------
    coprocessador_top #(.BUSCA_PASSIVA(1)) u_coprocessador (
        .CLOCK_50    (CLOCK_50),
        .KEY         (KEY),
        .LEDR        (LEDR),

        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_CLK     (VGA_CLK),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),

        .cmd_wr      (cmd_wr),
        .cmd_data    (cmd_data),
        .cmd_full    (cmd_full),
        .cmd_empty   (cmd_empty),
        .sw_reset    (sw_reset),

        .st_running    (st_running),
        .st_waiting    (st_waiting),
        .st_vblank     (st_vblank),
        .st_error      (st_error),
        .st_init_busy  (st_init_busy),
        .st_pll_locked (st_pll_locked),
        .st_frame_swap (st_frame_swap)
    );

endmodule