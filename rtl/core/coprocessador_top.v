// ============================================================================
// MODULO DE TOPO - COPROCESSADOR GRAFICO (DE1-SoC)
// ----------------------------------------------------------------------------
// Fluxo: a unidade de busca apresenta a instrucao corrente; a unidade de
// controle a decodifica e (a) aciona a ULA e o banco de registradores,
// (b) escreve nas memorias de conteudo, (c) dispara os motores de desenho.
// Os motores escrevem no framebuffer (double buffer), lido pelo vga_driver.
//
//   unidade_de_busca_de_instrucoes --> unidade_de_controle --> alu / banco
//                                              |
//                    memorias (paleta, tilemap, padroes)   motores --> engine_mux
//                                                                          |
//                                              framebuffer (2 bancos) --> vga_driver
//
// Este topo substitui o top_video anterior: as RAMs, os motores e a sequencia
// de desenho agora vem da unidade de controle (sem compositor). Do top_video
// foram mantidos o PLL (50 -> 25 MHz), o vga_driver, o framebuffer com double
// buffer e a sincronizacao do vblank.
//
// Double buffer: o HALT marca o fim do frame; quando o vblank chega, a unidade
// de busca emite frame_swap, os bancos sao trocados e o programa reinicia
// desenhando no banco que acabou de sair da tela. Como o banco de tras guarda
// o quadro de dois frames atras, o programa deve redesenhar a tela inteira
// (comece por DRAW_BG).
//
// Clocks: toda a logica em 50 MHz; clk_pixel (25 MHz, PLL) so no vga_driver e
// na leitura do framebuffer.
//
// Controles da placa: KEY[0] = reset, KEY[1] = reinicia o programa (sem
// debounce). LEDR[0] = programa rodando, LEDR[1] = aguardando motor/vblank,
// LEDR[2] = erro (opcode reservado ou comando rejeitado), com trava,
// LEDR[3] = PLL travado.
// ============================================================================

module coprocessador_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,            // botoes, ativos em 0
    output wire [9:0]  LEDR,

    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N
);

    wire clk = CLOCK_50;

    // ------------------------------------------------------------------------
    // Reset e botao de reinicio, sincronizados ao clock
    // ------------------------------------------------------------------------
    reg [1:0] rst_sync  = 2'b11;
    reg [2:0] key1_sync = 3'b111;

    always @(posedge clk) begin
        rst_sync  <= {rst_sync[0], ~KEY[0]};
        key1_sync <= {key1_sync[1:0], KEY[1]};
    end

    wire reset       = rst_sync[1];
    wire start_pulse = key1_sync[2] & ~key1_sync[1];   // borda de descida de KEY[1]

    // ------------------------------------------------------------------------
    // Sinais internos
    // ------------------------------------------------------------------------
    // Busca
    wire [15:0] pc;
    wire [31:0] instruction;
    wire        execute;
    wire        running, waiting, invalid_opcode;
    wire        engine_done;
    wire        frame_swap;

    // Banco de registradores e ULA
    wire [31:0]  reg_a, reg_b;
    wire [31:0]  alu_rd;
    wire         alu_valid, alu_done, alu_busy, alu_z, alu_n;
    wire [2:0]   alu_op;
    wire [31:0]  alu_b;
    wire [4:0]   alu_shamt;
    wire         rf_write_enable, flags_we;

    // Escritas nas memorias de conteudo
    wire         pal_we, tile_we, tpat_we, spat_we;
    wire [8:0]   pal_wr_addr,  pal_wr_data;
    wire [10:0]  tile_wr_addr;
    wire [7:0]   tile_wr_data;
    wire [13:0]  tpat_wr_addr, spat_wr_addr;
    wire [7:0]   tpat_wr_data, spat_wr_data;

    // Atributos de sprite (direto no motor_sprite)
    wire         spos_we, sattr_we;
    wire [4:0]   spos_wr_addr, sattr_wr_addr;
    wire [16:0]  spos_wr_data;
    wire [14:0]  sattr_wr_data;

    // Scroll do background
    wire         scroll_wr_en, scroll_sel;
    wire [8:0]   scroll_wr_data;
    wire         scroll_auto_en, scroll_auto_axis, scroll_auto_dir;
    wire [7:0]   scroll_auto_step;

    // Disparo e conclusao dos motores
    wire         start_bg, start_sprite, start_square, start_triangle;
    wire         done_bg, done_sprite, done_raster, raster_invalid;
    wire [1:0]   engine_sel;
    wire         cmd_error;

    // Parametros do rasterizador
    wire [8:0]   rast_v0x, rast_v1x, rast_v2x;
    wire [7:0]   rast_v0y, rast_v1y, rast_v2y;
    wire [7:0]   rast_color;
    wire         rast_palette;

    // Leituras das memorias pelos motores
    wire [10:0]  bg_tile_addr;
    wire [7:0]   bg_tile_data;
    wire [13:0]  bg_pat_addr,  spr_pat_addr;
    wire [7:0]   bg_pat_data,  spr_pat_data;
    wire [8:0]   bg_pal_addr,  spr_pal_addr,  ras_pal_addr;
    wire [8:0]   pal_rd_addr;
    wire [8:0]   pal_rd_data;

    // Escrita no framebuffer de cada motor e saida do mux
    wire         bg_fb_we,  spr_fb_we,  ras_fb_we;
    wire [8:0]   bg_fb_x,   spr_fb_x,   ras_fb_x;
    wire [7:0]   bg_fb_y,   spr_fb_y,   ras_fb_y;
    wire [8:0]   bg_fb_d,   spr_fb_d,   ras_fb_d;
    wire         fb_we;
    wire [8:0]   fb_wr_x;
    wire [7:0]   fb_wr_y;
    wire [8:0]   fb_wr_data;

    // ------------------------------------------------------------------------
    // Video: PLL, vga_driver e framebuffer com double buffer
    // ------------------------------------------------------------------------
    wire        clk_pixel;
    wire        pll_locked;
    wire [9:0]  next_x, next_y;
    wire [8:0]  fb_color_out;
    wire        vblank_tick;

    pll01 u_pll (
        .refclk   (clk),
        .rst      (reset),
        .outclk_0 (clk_pixel),
        .locked   (pll_locked)
    );

    // O framebuffer tem 320x240 e e ampliado 2x: usa metade das coordenadas
    wire [8:0] fb_rd_x = next_x[9:1];
    wire [7:0] fb_rd_y = next_y[9:1];

    vga_driver u_vga (
        .clock       (clk_pixel),
        .reset       (reset | ~pll_locked),
        .color_in    (fb_color_out),
        .next_x      (next_x),
        .next_y      (next_y),
        .hsync       (VGA_HS),
        .vsync       (VGA_VS),
        .red         (VGA_R),
        .green       (VGA_G),
        .blue        (VGA_B),
        .sync        (VGA_SYNC_N),
        .clk         (VGA_CLK),
        .blank       (VGA_BLANK_N),
        .vblank_tick (vblank_tick)
    );

    // vblank_tick esta no dominio clk_pixel: sincroniza ao clock de 50 MHz.
    // vblank_sync1 e o nivel usado pela busca (ela detecta a borda sozinha).
    reg vblank_sync0 = 1'b0;
    reg vblank_sync1 = 1'b0;

    always @(posedge clk) begin
        if (reset) begin
            vblank_sync0 <= 1'b0;
            vblank_sync1 <= 1'b0;
        end
        else begin
            vblank_sync0 <= vblank_tick;
            vblank_sync1 <= vblank_sync0;
        end
    end

    wire vblank = vblank_sync1;

    // Double buffer: rd = banco exibido, wr = banco onde os motores desenham.
    // A troca acontece quando a busca sinaliza frame_swap (HALT + vblank).
    reg rd_buf_sel = 1'b0;
    reg wr_buf_sel = 1'b1;

    always @(posedge clk) begin
        if (reset) begin
            rd_buf_sel <= 1'b0;
            wr_buf_sel <= 1'b1;
        end
        else if (frame_swap) begin
            rd_buf_sel <= wr_buf_sel;
            wr_buf_sel <= rd_buf_sel;
        end
    end

    framebuffer u_framebuffer (
        .clk_sys    (clk),
        .we         (fb_we),
        .wr_x       (fb_wr_x),
        .wr_y       (fb_wr_y),
        .wr_data    (fb_wr_data),
        .wr_buf_sel (wr_buf_sel),

        .clk_pixel  (clk_pixel),
        .rd_x       (fb_rd_x),
        .rd_y       (fb_rd_y),
        .rd_buf_sel (rd_buf_sel),

        .q          (fb_color_out)
    );

    // ------------------------------------------------------------------------
    // Unidade de busca de instrucoes (PC, Adder e instruction_memory internos)
    // ------------------------------------------------------------------------
    unidade_de_busca_de_instrucoes #(
        .LAT_MEM     (2),   // instruction_memory com saida q registrada
        .INICIAR_AUTO(1),   // executa logo apos o reset
        .LOOP_AUTO   (1)    // apos o HALT, troca os buffers e reinicia no vblank
    ) u_busca (
        .clk           (clk),
        .reset         (reset),
        .start         (start_pulse),
        .engine_done   (engine_done),
        .vblank        (vblank),
        .pc            (pc),
        .instruction   (instruction),
        .execute       (execute),
        .frame_swap    (frame_swap),
        .running       (running),
        .waiting       (waiting),
        .invalid_opcode(invalid_opcode)
    );

    // ------------------------------------------------------------------------
    // Unidade de controle (decodificador, escritas, disparos)
    // ------------------------------------------------------------------------
    unidade_de_controle u_controle (
        .instruction     (instruction),
        .execute         (execute),
        .reg_a           (reg_a),
        .reg_b           (reg_b),

        .alu_valid       (alu_valid),
        .alu_op          (alu_op),
        .alu_b           (alu_b),
        .alu_shamt       (alu_shamt),
        .alu_done        (alu_done),
        .rf_write_enable (rf_write_enable),
        .flags_we        (flags_we),

        .pal_we          (pal_we),
        .pal_wr_addr     (pal_wr_addr),
        .pal_wr_data     (pal_wr_data),
        .tile_we         (tile_we),
        .tile_wr_addr    (tile_wr_addr),
        .tile_wr_data    (tile_wr_data),
        .tpat_we         (tpat_we),
        .tpat_wr_addr    (tpat_wr_addr),
        .tpat_wr_data    (tpat_wr_data),
        .spat_we         (spat_we),
        .spat_wr_addr    (spat_wr_addr),
        .spat_wr_data    (spat_wr_data),
        .spos_we         (spos_we),
        .spos_wr_addr    (spos_wr_addr),
        .spos_wr_data    (spos_wr_data),
        .sattr_we        (sattr_we),
        .sattr_wr_addr   (sattr_wr_addr),
        .sattr_wr_data   (sattr_wr_data),

        .scroll_wr_en    (scroll_wr_en),
        .scroll_sel      (scroll_sel),
        .scroll_wr_data  (scroll_wr_data),
        .scroll_auto_en  (scroll_auto_en),
        .scroll_auto_axis(scroll_auto_axis),
        .scroll_auto_dir (scroll_auto_dir),
        .scroll_auto_step(scroll_auto_step),

        .start_bg        (start_bg),
        .start_sprite    (start_sprite),
        .start_square    (start_square),
        .start_triangle  (start_triangle),


        .done_bg         (done_bg),
        .done_sprite     (done_sprite),
        .done_raster     (done_raster),
        .raster_invalid  (raster_invalid),

        .engine_sel      (engine_sel),
        .engine_done     (engine_done),
        .cmd_error       (cmd_error)
    );

    // ------------------------------------------------------------------------
    // Banco de registradores (2 leituras, escrita pelo write-back da ULA)
    // Registradores 37-43: vertices e cor do rasterizador (saidas dedicadas).
    // ------------------------------------------------------------------------
    banco_registradores u_banco (
        .clk          (clk),
        .reset        (reset),
        .instrucao    (instruction),
        .write_enable (rf_write_enable),
        .write_data   (alu_rd),
        .read_data_a  (reg_a),
        .read_data_b  (reg_b),

        // Vertices e cor do rasterizador (registradores 37-43)
        .v0x          (rast_v0x),
        .v0y          (rast_v0y),
        .v1x          (rast_v1x),
        .v1y          (rast_v1y),
        .v2x          (rast_v2x),
        .v2y          (rast_v2y),
        .color_index  (rast_color),
        .palette_sel  (rast_palette),

        .status_in    ({29'b0, vblank, waiting, running}),

        .flags_we     (flags_we),
        .flag_z       (alu_z),
        .flag_n       (alu_n),

        .flags        ()
    );

    // ------------------------------------------------------------------------
    // ULA
    // ------------------------------------------------------------------------
    alu u_alu (
        .op    (alu_op),
        .rd    (alu_rd),
        .rn    (reg_a),
        .b     (alu_b),
        .shamt (alu_shamt),
        .valid (alu_valid),
        .z     (alu_z),
        .n     (alu_n),
        .busy  (alu_busy),
        .done  (alu_done)
    );

    // ------------------------------------------------------------------------
    // Memorias de conteudo (escritas pela unidade de controle)
    // ------------------------------------------------------------------------
    bg_tile_ram u_bg_tile_ram (
        .clock     (clk),
        .data      (tile_wr_data),
        .wraddress (tile_wr_addr),
        .wren      (tile_we),
        .rdaddress (bg_tile_addr),
        .q         (bg_tile_data)
    );

    bg_tile_pattern_ram u_bg_tile_pattern_ram (
        .clock     (clk),
        .data      (tpat_wr_data),
        .wraddress (tpat_wr_addr),
        .wren      (tpat_we),
        .rdaddress (bg_pat_addr),
        .q         (bg_pat_data)
    );

    sprite_pattern_ram u_sprite_pattern_ram (
        .clock     (clk),
        .data      (spat_wr_data),
        .wraddress (spat_wr_addr),
        .wren      (spat_we),
        .rdaddress (spr_pat_addr),
        .q         (spr_pat_data)
    );

    // A leitura da paleta e compartilhada: o engine_mux escolhe o endereco do
    // motor ativo e o dado vai a todos os motores.
    palette_ram u_palette_ram (
        .clock     (clk),
        .data      (pal_wr_data),
        .wraddress (pal_wr_addr),
        .wren      (pal_we),
        .rdaddress (pal_rd_addr),
        .q         (pal_rd_data)
    );

    // ------------------------------------------------------------------------
    // Motores de desenho
    // ------------------------------------------------------------------------
    motor_background u_motor_bg (
        .clk              (clk),
        .reset            (reset),

        .scroll_wr_en     (scroll_wr_en),
        .scroll_sel       (scroll_sel),
        .scroll_wr_data   (scroll_wr_data),
        .scroll_auto_en   (scroll_auto_en),
        .scroll_auto_axis (scroll_auto_axis),
        .scroll_auto_dir  (scroll_auto_dir),
        .scroll_auto_step (scroll_auto_step),

        .tile_rd_addr     (bg_tile_addr),
        .tile_rd_data     (bg_tile_data),
        .pattern_rd_addr  (bg_pat_addr),
        .pattern_rd_data  (bg_pat_data),
        .palette_rd_addr  (bg_pal_addr),
        .palette_rd_data  (pal_rd_data),

        .fb_we            (bg_fb_we),
        .fb_wr_x          (bg_fb_x),
        .fb_wr_y          (bg_fb_y),
        .fb_wr_data       (bg_fb_d),

        .start            (start_bg),
        .busy             (),
        .done             (done_bg)
    );

    motor_sprite u_motor_sprite (
        .clk             (clk),
        .reset           (reset),

        .spos_we         (spos_we),
        .spos_wr_addr    (spos_wr_addr),
        .spos_wr_data    (spos_wr_data),
        .sattr_we        (sattr_we),
        .sattr_wr_addr   (sattr_wr_addr),
        .sattr_wr_data   (sattr_wr_data),

        .pattern_rd_addr (spr_pat_addr),
        .pattern_rd_data (spr_pat_data),
        .palette_rd_addr (spr_pal_addr),
        .palette_rd_data (pal_rd_data),

        .fb_we           (spr_fb_we),
        .fb_wr_x         (spr_fb_x),
        .fb_wr_y         (spr_fb_y),
        .fb_wr_data      (spr_fb_d),

        .start           (start_sprite),
        .busy            (),
        .done            (done_sprite)
    );

    rasterizador_top u_rasterizador (
        .clk             (clk),
        .reset           (reset),

        .start_square    (start_square),
        .start_triangle  (start_triangle),
        .v0x             (rast_v0x),
        .v1x             (rast_v1x),
        .v2x             (rast_v2x),
        .v0y             (rast_v0y),
        .v1y             (rast_v1y),
        .v2y             (rast_v2y),
        .color_index     (rast_color),
        .palette_sel     (rast_palette),

        .palette_rd_addr (ras_pal_addr),
        .palette_rd_data (pal_rd_data),

        .fb_we           (ras_fb_we),
        .fb_wr_x         (ras_fb_x),
        .fb_wr_y         (ras_fb_y),
        .fb_wr_data      (ras_fb_d),

        .busy            (),
        .done            (done_raster),
        .invalid_cmd     (raster_invalid)
    );

    // ------------------------------------------------------------------------
    // Mux dos recursos compartilhados: leitura da paleta e escrita no
    // framebuffer, conforme o motor ativo (engine_sel)
    // ------------------------------------------------------------------------
    engine_mux u_mux (
        .engine_sel   (engine_sel),

        .bg_pal_addr  (bg_pal_addr),
        .bg_fb_we     (bg_fb_we),
        .bg_fb_x      (bg_fb_x),
        .bg_fb_y      (bg_fb_y),
        .bg_fb_data   (bg_fb_d),

        .spr_pal_addr (spr_pal_addr),
        .spr_fb_we    (spr_fb_we),
        .spr_fb_x     (spr_fb_x),
        .spr_fb_y     (spr_fb_y),
        .spr_fb_data  (spr_fb_d),

        .ras_pal_addr (ras_pal_addr),
        .ras_fb_we    (ras_fb_we),
        .ras_fb_x     (ras_fb_x),
        .ras_fb_y     (ras_fb_y),
        .ras_fb_data  (ras_fb_d),

        .pal_rd_addr  (pal_rd_addr),
        .fb_we        (fb_we),
        .fb_wr_x      (fb_wr_x),
        .fb_wr_y      (fb_wr_y),
        .fb_wr_data   (fb_wr_data)
    );

    // ------------------------------------------------------------------------
    // Indicadores nos LEDs
    // ------------------------------------------------------------------------
    reg err_latch = 1'b0;
    always @(posedge clk) begin
        if (reset)
            err_latch <= 1'b0;
        else if (invalid_opcode | cmd_error)
            err_latch <= 1'b1;
    end

    assign LEDR = {6'b0, pll_locked, err_latch, waiting, running};

endmodule