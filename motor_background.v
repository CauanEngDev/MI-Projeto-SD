module motor_background (
    input wire clk,
    input wire reset,

    input wire        scroll_wr_en,
    input wire        scroll_sel,
    input wire [8:0]  scroll_wr_data,

    output reg  [10:0] tile_rd_addr,
    input  wire [7:0]  tile_rd_data,

    output reg  [13:0] pattern_rd_addr,
    input  wire [7:0]  pattern_rd_data,

    output reg  [8:0]  palette_rd_addr,
    input  wire [8:0]  palette_rd_data,

    output reg          fb_we,
    output reg  [8:0]   fb_wr_x,
    output reg  [7:0]   fb_wr_y,
    output reg  [8:0]   fb_wr_data,

    input  wire start,
    output wire busy,
    output reg  done
);

    // ---------------- Registradores de scroll ----------------
    reg [8:0] scroll_x;
    reg [7:0] scroll_y;

    always @(posedge clk) begin
        if (reset) begin
            scroll_x <= 9'd0;
            scroll_y <= 8'd0;
        end else if (scroll_wr_en) begin
            if (scroll_sel) scroll_y <= scroll_wr_data[7:0];
            else            scroll_x <= scroll_wr_data;
        end
    end

    // ---------------- Contador de varredura ----------------
    reg [8:0] screen_x;
    reg [7:0] screen_y;

    // ---------------- Wraparound (scroll circular) ----------------
    wire [9:0] sum_x = {1'b0, screen_x} + {1'b0, scroll_x};
    wire [8:0] wrapped_x = (sum_x >= 10'd320) ? (sum_x - 10'd320) : sum_x[8:0];
    wire [8:0] sum_y = {1'b0, screen_y} + {1'b0, scroll_y};
    wire [7:0] wrapped_y = (sum_y >= 9'd240) ? (sum_y - 9'd240) : sum_y[7:0];

    wire [5:0] tile_col = wrapped_x[8:3]; // 0-39
    wire [2:0] sub_x    = wrapped_x[2:0];
    wire [4:0] tile_row = wrapped_y[7:3]; // 0-29
    wire [2:0] sub_y    = wrapped_y[2:0];

    // ---------------- Cache de uma linha inteira de tiles ----------------
    reg [7:0] row_cache [0:39];
    reg [4:0] cached_tile_row;
    reg       cache_valid;
    reg [5:0] prefetch_idx;

    wire row_needs_refresh = (!cache_valid) || (tile_row != cached_tile_row);

    localparam S_IDLE          = 4'd0,
               S_ROW_CHECK     = 4'd1,
               S_PREFETCH_SET  = 4'd2,
               S_PREFETCH_WAIT = 4'd3,
               S_PREFETCH_STORE= 4'd4,
               S_PATTERN_SET   = 4'd5,
               S_PATTERN_WAIT  = 4'd6,
               S_PALETTE_SET   = 4'd7,
               S_PALETTE_WAIT  = 4'd8,
               S_WRITE         = 4'd9,
               S_DONE          = 4'd10;

    reg [3:0] state;
    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state       <= S_IDLE;
            fb_we       <= 1'b0;
            done        <= 1'b0;
            cache_valid <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            done  <= 1'b0;

            case (state)
                S_IDLE: if (start) begin
                    screen_x <= 9'd0;
                    screen_y <= 8'd0;
                    state    <= S_ROW_CHECK;
                end

                // Decide, com screen_y JÁ estável, se a linha de tiles atual
                // precisa ser recarregada no cache
                S_ROW_CHECK: begin
                    if (row_needs_refresh) begin
                        prefetch_idx <= 6'd0;
                        state        <= S_PREFETCH_SET;
                    end else begin
                        state <= S_PATTERN_SET;
                    end
                end

                // ---------------- Pré-busca de até 40 tiles ----------------
                S_PREFETCH_SET: begin
                    tile_rd_addr <= (tile_row << 5) + (tile_row << 3) + prefetch_idx; // tile_row*40+idx
                    state <= S_PREFETCH_WAIT;
                end

                S_PREFETCH_WAIT: state <= S_PREFETCH_STORE;

                S_PREFETCH_STORE: begin
                    row_cache[prefetch_idx] <= tile_rd_data;
                    if (prefetch_idx == 6'd39) begin
                        cached_tile_row <= tile_row;
                        cache_valid     <= 1'b1;
                        state           <= S_PATTERN_SET;
                    end else begin
                        prefetch_idx <= prefetch_idx + 6'd1;
                        state        <= S_PREFETCH_SET;
                    end
                end

                // ---------------- Desenho do pixel, usando o cache ----------------
                S_PATTERN_SET: begin
                    pattern_rd_addr <= {row_cache[tile_col], sub_y, sub_x};
                    state <= S_PATTERN_WAIT;
                end

                S_PATTERN_WAIT: state <= S_PALETTE_SET;

                S_PALETTE_SET: begin
                    palette_rd_addr <= {1'b0, pattern_rd_data};
                    state <= S_PALETTE_WAIT;
                end

                S_PALETTE_WAIT: state <= S_WRITE;

                S_WRITE: begin
                    fb_we      <= 1'b1;
                    fb_wr_x    <= screen_x;
                    fb_wr_y    <= screen_y;
                    fb_wr_data <= palette_rd_data;

                    if (screen_x == 9'd319) begin
                        screen_x <= 9'd0;
                        if (screen_y == 8'd239) begin
                            state <= S_DONE;
                        end else begin
                            screen_y <= screen_y + 8'd1;
                            state    <= S_ROW_CHECK; // pode mudar de linha de tiles
                        end
                    end else begin
                        screen_x <= screen_x + 9'd1;
                        state    <= S_PATTERN_SET; // mesma linha de tiles, cache já válido
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