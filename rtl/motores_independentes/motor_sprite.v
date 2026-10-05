module motor_sprite (
    input wire clk,
    input wire reset,

    // Leitura da sprite_attribute_ram (gerada via IP Catalog)
    output reg  [4:0]  attr_rd_addr,
    input  wire [31:0] attr_rd_data,

    // Leitura da sprite_pattern_ram (gerada via IP Catalog)
    output reg  [13:0] pattern_rd_addr,
    input  wire [7:0]  pattern_rd_data,   // agora 8 bits (256 cores)

    // Leitura da palette_ram (2 paletas x 256 cores)
    output reg  [8:0]  palette_rd_addr,   // {palette_sel, color_index[7:0]}
    input  wire [8:0]  palette_rd_data,

    // Interface de escrita no framebuffer
    output reg          fb_we,
    output reg  [8:0]   fb_wr_x,
    output reg  [7:0]   fb_wr_y,
    output reg  [8:0]   fb_wr_data,

    input  wire start,
    output wire busy,
    output reg  done
);

    reg [4:0] level_cnt5; // não usado -- placeholder removido abaixo
    reg [4:0] level_cnt;  // nível de prioridade (0-31)
    reg [4:0] sidx_cnt;   // índice do sprite (0-31)
    reg [3:0] ly_cnt, lx_cnt;

    // Campos extraídos do dado JÁ REGISTRADO vindo da RAM de atributos
    wire        cur_enable   = attr_rd_data[31];
    wire [4:0]  cur_priority = attr_rd_data[30:26];
    wire        cur_flip_v   = attr_rd_data[25];
    wire        cur_flip_h   = attr_rd_data[24];
    wire        cur_pal_sel  = attr_rd_data[23];
    wire [5:0]  cur_pattern  = attr_rd_data[22:17];
    wire [7:0]  cur_pos_y    = attr_rd_data[16:9];
    wire [8:0]  cur_pos_x    = attr_rd_data[8:0];

    wire sprite_matches = cur_enable && (cur_priority == level_cnt);

    wire [3:0] slx = cur_flip_h ? (4'd15 - lx_cnt) : lx_cnt;
    wire [3:0] sly = cur_flip_v ? (4'd15 - ly_cnt) : ly_cnt;
    wire [1:0] quadrant = {sly[3], slx[3]};
    wire [7:0] tile_id  = {cur_pattern, quadrant};
    wire [2:0] sub_x = slx[2:0];
    wire [2:0] sub_y = sly[2:0];

    wire [9:0] dest_x = cur_pos_x + lx_cnt;
    wire [8:0] dest_y = cur_pos_y + ly_cnt;
    wire       on_screen = (dest_x < 10'd320) && (dest_y < 9'd240);

    localparam S_IDLE       = 4'd0,
           S_ATTR_RD    = 4'd1,
           S_ATTR_WAIT  = 4'd2,
           S_CHECK_SPR  = 4'd3,
           S_PATTERN_RD = 4'd4,
           S_PALETTE_RD = 4'd5,
           S_WRITE_PX   = 4'd6,
           S_NEXT_PX    = 4'd7,
           S_NEXT_SPR   = 4'd8,
           S_NEXT_LVL   = 4'd9,
           S_DONE       = 4'd10;

    reg [3:0] state;
    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            fb_we <= 1'b0;
            done  <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            done  <= 1'b0;

            case (state)
                S_IDLE: if (start) begin
                    level_cnt    <= 5'd0;
                    sidx_cnt     <= 5'd0;
                    ly_cnt       <= 4'd0;
                    lx_cnt       <= 4'd0;
                    attr_rd_addr <= 5'd0;
                    state        <= S_ATTR_RD;
                end

                S_ATTR_RD: begin
							 state <= S_ATTR_WAIT;
						end

						S_ATTR_WAIT: begin
							 state <= S_CHECK_SPR;
						end

                S_CHECK_SPR: begin
                    if (sprite_matches) begin
                        pattern_rd_addr <= {tile_id, sub_y, sub_x};
                        state <= S_PATTERN_RD;
                    end else begin
                        state <= S_NEXT_SPR;
                    end
                end

                S_PATTERN_RD: state <= S_PALETTE_RD;

                S_PALETTE_RD: begin
                    if (pattern_rd_data == 8'd0) begin
                        state <= S_NEXT_PX; // índice 0 = transparente
                    end else begin
                        palette_rd_addr <= {cur_pal_sel, pattern_rd_data};
                        state <= S_WRITE_PX;
                    end
                end

                S_WRITE_PX: begin
                    if (on_screen) begin
                        fb_we      <= 1'b1;
                        fb_wr_x    <= dest_x[8:0];
                        fb_wr_y    <= dest_y[7:0];
                        fb_wr_data <= palette_rd_data;
                    end
                    state <= S_NEXT_PX;
                end

                S_NEXT_PX: begin
                    if (lx_cnt == 4'd15) begin
                        lx_cnt <= 4'd0;
                        if (ly_cnt == 4'd15) begin
                            ly_cnt <= 4'd0;
                            state  <= S_NEXT_SPR;
                        end else begin
                            ly_cnt <= ly_cnt + 4'd1;
                            state  <= S_CHECK_SPR; // atributo já está estável, não precisa reler
                        end
                    end else begin
                        lx_cnt <= lx_cnt + 4'd1;
                        state  <= S_CHECK_SPR;
                    end
                end

                S_NEXT_SPR: begin
                    ly_cnt <= 4'd0;
                    lx_cnt <= 4'd0;
                    if (sidx_cnt == 5'd31) begin
                        sidx_cnt     <= 5'd0;
                        attr_rd_addr <= 5'd0;
                        state        <= S_NEXT_LVL;
                    end else begin
                        sidx_cnt     <= sidx_cnt + 5'd1;
                        attr_rd_addr <= sidx_cnt + 5'd1;
                        state        <= S_ATTR_RD;
                    end
                end

                S_NEXT_LVL: begin
                    if (level_cnt == 5'd31) begin
                        state <= S_DONE;
                    end else begin
                        level_cnt <= level_cnt + 5'd1;
                        state     <= S_ATTR_RD; // relê sprite 0 pro novo nível
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

