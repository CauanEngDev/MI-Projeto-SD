module rasterizador_quadrado (
    input  wire        clk,
    input  wire        reset,

    input  wire        start,
    input  wire [8:0]  v0x, v1x,
    input  wire [7:0]  v0y, v1y,
    input  wire [7:0]  color_index,  // índice de paleta (0-255), em vez de RGB direto
    input  wire        palette_sel,  // qual das 2 paletas usar

    output reg  [8:0]  palette_rd_addr,
    input  wire [8:0]  palette_rd_data,

    output reg          fb_we,
    output reg  [8:0]   fb_wr_x,
    output reg  [7:0]   fb_wr_y,
    output reg  [8:0]   fb_wr_data,

    output wire         busy,
    output reg          done
);

    localparam S_IDLE         = 3'd0,
               S_PALETTE_WAIT = 3'd1,
               S_SETUP        = 3'd2,
               S_FILL         = 3'd3,
               S_DONE         = 3'd4;

    reg [2:0] state;
    assign busy = (state != S_IDLE);

    reg [8:0] xL, xR, cur_x;
    reg [7:0] yMax, cur_y;
    reg [8:0] color_reg; // RGB resolvido, cacheado uma unica vez por comando

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
                    palette_rd_addr <= {palette_sel, color_index};
                    state <= S_PALETTE_WAIT;
                end

                S_PALETTE_WAIT: state <= S_SETUP; // aguarda 1 ciclo de latência da palette_ram

                S_SETUP: begin
                    color_reg <= palette_rd_data; // já válido aqui
                    xL    <= (v0x <= v1x) ? v0x : v1x;
                    xR    <= (v0x <= v1x) ? v1x : v0x;
                    cur_x <= (v0x <= v1x) ? v0x : v1x;
                    cur_y <= (v0y <= v1y) ? v0y : v1y;
                    yMax  <= (v0y >= v1y) ? v0y : v1y;
                    state <= S_FILL;
                end

                S_FILL: begin
                    fb_we      <= 1'b1;
                    fb_wr_x    <= cur_x;
                    fb_wr_y    <= cur_y;
                    fb_wr_data <= color_reg;
                    if (cur_x == xR) begin
                        cur_x <= xL;
                        if (cur_y == yMax) state <= S_DONE;
                        else cur_y <= cur_y + 8'd1;
                    end else cur_x <= cur_x + 9'd1;
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