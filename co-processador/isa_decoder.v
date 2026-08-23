module isa_decoder(
    input wire        clk,
    input wire        reset,
    input wire [31:0] cmd_data, // Instrução do usuário
    input wire        cmd_valid,

    // Interface com a Memória da paleta
    output reg        pal_we, // Write Enable, 0 = apenas leitura, 1 = escrita. Protege de corrupções quando fizer outras escritas.
    output reg [7:0]  pal_addr,
    output reg [15:0] pal_color,

    // Interface com o Motor do Background / TiledMap
    output reg        tiledmap_we,
    output reg [5:0]  tiledmap_x,
    output reg [4:0]  tiledmap_y,
    output reg [7:0]  tiledmap_tile_id,
    output reg [8:0]  bg_scroll_x,
    output reg [7:0]  bg_scroll_x,
    output reg        bg_scroll_update,

    // Interface com a Memória de Padrões de Tiles
    output reg         tile_data_we,
    output reg  [7:0]  tile_data_id,
    output reg  [5:0]  tile_data_pixel,
    output reg  [7:0]  tile_data_color,

    // Interface com o Motor de Sprites
    output reg         sprite_pos_we,
    output reg         sprite_attr_we,
    output reg  [4:0]  sprite_id,
    output reg  [7:0]  sprite_pos_x,
    output reg  [7:0]  sprite_pos_y,
    output reg  [7:0]  sprite_tile_id,
    output reg         sprite_flip_h,
    output reg         sprite_flip_v,
    output reg         sprite_en,
    output reg         sprite_prio,

    // Interface com o Rasterizador de Polígonos
    output reg         draw_rect_en,
    output reg  [7:0]  rect_x0,
    output reg  [7:0]  rect_y0,
    output reg  [7:0]  rect_size,
    output reg  [7:0]  rect_color,
    output reg         draw_tri_en,
    output reg  [27:0] tri_params
);

    // Definição dos Opcodes da ISA
    localparam OP_NOP              = 4'b0000;
    localparam OP_SET_PALETTE      = 4'b0001;
    localparam OP_SET_SPRITE_POS   = 4'b0010;
    localparam OP_SET_TILEMAP      = 4'b0011;
    localparam OP_SCROLL_BG        = 4'b0100;
    localparam OP_SET_SPRITE_ATTR  = 4'b0101;
    localparam OP_DRAW_RECT        = 4'b0110;
    localparam OP_DRAW_TRI         = 4'b0111;
    localparam OP_WRITE_TILE_DATA  = 4'b1000;
    localparam OP_SET_DRAW_COLOR   = 4'b1001;

    wire [3:0] opcode = cmd_data[31:28];
    reg [7:0] current_draw_color;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reseta pulsos de escrita e habilitação
            pal_we           <= 1'b0;
            tilemap_we       <= 1'b0;
            bg_scroll_update <= 1'b0;
            tile_data_we     <= 1'b0;
            sprite_pos_we    <= 1'b0;
            sprite_attr_we   <= 1'b0;
            draw_rect_en     <= 1'b0;
            draw_tri_en      <= 1'b0;

            // Valores padrão dos registradores internos
            pal_addr         <= 8'd0;
            pal_color        <= 16'd0;
            tilemap_x        <= 6'd0;
            tilemap_y        <= 5'd0;
            tilemap_tile_id  <= 8'd0;
            bg_scroll_x      <= 9'd0;
            bg_scroll_y      <= 8'd0;
            tile_data_id     <= 8'd0;
            tile_data_pixel  <= 6'd0;
            tile_data_color  <= 8'd0;
            sprite_id        <= 5'd0;
            sprite_pos_x     <= 8'd0;
            sprite_pos_y     <= 8'd0;
            sprite_tile_id   <= 8'd0;
            sprite_flip_h    <= 1'b0;
            sprite_flip_v    <= 1'b0;
            sprite_en        <= 1'b0;
            sprite_prio      <= 1'b0;
            rect_x0          <= 8'd0;
            rect_y0          <= 8'd0;
            rect_size        <= 8'd0;
            rect_color       <= 8'd0;
            tri_params       <= 28'd0;
        end else begin
            // Desativa os sinais de escrita de ciclo único por padrão
            pal_we           <= 1'b0;
            tilemap_we       <= 1'b0;
            bg_scroll_update <= 1'b0;
            tile_data_we     <= 1'b0;
            sprite_pos_we    <= 1'b0;
            sprite_attr_we   <= 1'b0;
            draw_rect_en     <= 1'b0;
            draw_tri_en      <= 1'b0;

            if (cmd_valid) begin
                case (opcode)

                    OP_SET_DRAW_COLOR: begin
                        current_draw_color <= cmd_data[7:0]; // Salva o índice de cor (0 a 255)
                    end

                    OP_SET_PALETTE: begin
                        pal_we    <= 1'b1;
                        pal_addr  <= cmd_data[23:16];
                        pal_color <= cmd_data[15:0];
                    end

                    OP_SET_SPRITE_POS: begin
                        sprite_pos_we <= 1'b1;
                        sprite_id     <= cmd_data[20:16];
                        sprite_pos_x  <= cmd_data[15:8];
                        sprite_pos_y  <= cmd_data[7:0];
                    end

                    OP_SET_TILEMAP: begin
                        tilemap_we      <= 1'b1;
                        tilemap_x       <= cmd_data[18:13];
                        tilemap_y       <= cmd_data[12:8];
                        tilemap_tile_id <= cmd_data[7:0];
                    end

                    OP_SCROLL_BG: begin
                        bg_scroll_update <= 1'b1;
                        bg_scroll_x      <= cmd_data[17:9];
                        bg_scroll_y      <= cmd_data[8:0];
                    end

                    OP_SET_SPRITE_ATTR: begin
                        sprite_attr_we <= 1'b1;
                        sprite_id      <= cmd_data[20:16];
                        sprite_tile_id <= cmd_data[15:8];
                        sprite_flip_h  <= cmd_data[3];
                        sprite_flip_v  <= cmd_data[2];
                        sprite_en      <= cmd_data[1];
                        sprite_prio    <= cmd_data[0];
                    end

                    OP_DRAW_RECT: begin
                        draw_rect_en <= 1'b1;
                        rect_x0      <= cmd_data[27:19];     // 9 bits (0 a 319)
                        rect_y0      <= cmd_data[18:11];     // 8 bits (0 a 239)
                        rect_width   <= cmd_data[10:6];      // 5 bits (largura)
                        rect_height  <= cmd_data[5:0];       // 6 bits (altura)
                        rect_color   <= current_draw_color;  // Usa a cor configurada pelo OP_SET_DRAW_COLOR
                    end

                    OP_DRAW_TRI: begin
                        draw_tri_en <= 1'b1;
                        // TODO: Definir como desenhar um triângulo
                    end

                    OP_WRITE_TILE_DATA: begin
                        tile_data_we    <= 1'b1;
                        tile_data_id    <= cmd_data[21:14];
                        tile_data_pixel <= cmd_data[13:8];
                        tile_data_color <= cmd_data[7:0];
                    end

                    default: begin
                        pal_we           <= pal_we;
                        tilemap_we       <= tilemap_we;
                        bg_scroll_update <= bg_scroll_update;
                        tile_data_we     <= tile_data_we;
                        sprite_pos_we    <= sprite_pos_we;
                        sprite_attr_we   <= sprite_attr_we;
                        draw_rect_en     <= draw_rect_en;
                        draw_tri_en      <= draw_tri_en;
                    end
                endcase
            end
        end
    end

endmodule