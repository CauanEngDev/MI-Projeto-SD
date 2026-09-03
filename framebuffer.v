module framebuffer (
    // Escrita - rasterizador/compositor, clock de sistema
    input  wire        clk_sys,
    input  wire        we,
    input  wire [8:0]  wr_x,
    input  wire [7:0]  wr_y,
    input  wire [8:0]  wr_data,
    input  wire        wr_buf_sel,   // NOVO: qual banco (0 ou 1) recebe a escrita agora

    // Leitura - VGA driver, pixel clock
    input  wire        clk_pixel,
    input  wire [8:0]  rd_x,
    input  wire [7:0]  rd_y,
    input  wire        rd_buf_sel,   // NOVO: qual banco (0 ou 1) está sendo exibido agora
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

    wire [8:0] q0, q1;

    // Banco 0
    framebuffer_ram framebuffer_ram_bank0 (
        .data      (wr_data),
        .wraddress (wr_addr),
        .wrclock   (clk_sys),
        .wren      (we && (wr_buf_sel == 1'b0)),
        .rdaddress (rd_addr),
        .rdclock   (clk_pixel),
        .q         (q0)
    );

    // Banco 1
    framebuffer_ram framebuffer_ram_bank1 (
        .data      (wr_data),
        .wraddress (wr_addr),
        .wrclock   (clk_sys),
        .wren      (we && (wr_buf_sel == 1'b1)),
        .rdaddress (rd_addr),
        .rdclock   (clk_pixel),
        .q         (q1)
    );

    // rd_buf_sel chega do domínio "clock" (sistema); resincroniza pro
    // domínio clk_pixel antes de usar no mux de leitura
    reg rd_buf_sel_sync;
    always @(posedge clk_pixel) rd_buf_sel_sync <= rd_buf_sel;

    assign q = rd_buf_sel_sync ? q1 : q0;

endmodule