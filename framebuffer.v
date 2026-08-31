module framebuffer (
    // Escrita - rasterizador/compositor, clock de sistema
    input  wire        clk_sys,
    input  wire        we,
    input  wire [8:0]  wr_x,
    input  wire [7:0]  wr_y,
    input  wire [8:0]  wr_data,

    // Leitura - VGA driver, pixel clock
    input  wire        clk_pixel,
    input  wire [8:0]  rd_x,
    input  wire [7:0]  rd_y,
    output wire [8:0]  q
);

    wire [16:0] wr_addr;
    wire [16:0] rd_addr;

    fb_addr_gen wr_addr_gen (
        .x(wr_x),
        .y(wr_y),
        .addr(wr_addr)
    );

    fb_addr_gen rd_addr_gen (
        .x(rd_x),
        .y(rd_y),
        .addr(rd_addr)
    );

    framebuffer_ram framebuffer_ram_inst (
        .data      (wr_data),
        .wraddress (wr_addr),
        .wrclock   (clk_sys),
        .wren      (we),
        .rdaddress (rd_addr),
        .rdclock   (clk_pixel),
        .q         (q)
    );

endmodule