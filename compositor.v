module compositor (
    input wire clk,
    input wire reset,

    input  wire start,
    output wire busy,
    output reg  done,

    // Controle dos três motores
    output reg  bg_start,   input wire bg_busy,   input wire bg_done,
    output reg  poly_start, input wire poly_busy, input wire poly_layer_done,
    output reg  spr_start,  input wire spr_busy,  input wire spr_done,

    // Porta física única da palette_ram
    output wire [8:0] palette_rd_addr,
    input  wire [8:0] palette_rd_data,

    // Pedidos dos três motores (nunca simultâneos, graças ao sequenciamento)
    input  wire [8:0] bg_palette_rd_addr,   output wire [8:0] bg_palette_rd_data,
    input  wire [8:0] poly_palette_rd_addr, output wire [8:0] poly_palette_rd_data,
    input  wire [8:0] spr_palette_rd_addr,  output wire [8:0] spr_palette_rd_data,

    // Arbitração da porta de escrita ÚNICA do framebuffer
    output wire         fb_we,
    output wire [8:0]   fb_wr_x,
    output wire [7:0]   fb_wr_y,
    output wire [8:0]   fb_wr_data,
	 
	 output wire poly_phase,

    input wire         bg_fb_we,   input wire [8:0] bg_fb_wr_x,   input wire [7:0] bg_fb_wr_y,   input wire [8:0] bg_fb_wr_data,
    input wire         poly_fb_we, input wire [8:0] poly_fb_wr_x, input wire [7:0] poly_fb_wr_y, input wire [8:0] poly_fb_wr_data,
    input wire         spr_fb_we,  input wire [8:0] spr_fb_wr_x,  input wire [7:0] spr_fb_wr_y,  input wire [8:0] spr_fb_wr_data
);

    localparam S_IDLE = 3'd0, S_BG = 3'd1, S_POLY = 3'd2, S_SPR = 3'd3, S_DONE = 3'd4;
    reg [2:0] state;
    assign busy = (state != S_IDLE);

    // ---------------- Árbitro de paleta ----------------
    // Só um motor está "busy" por vez -- mux simples por prioridade de sequenciamento
    assign palette_rd_addr = bg_busy   ? bg_palette_rd_addr   :
                             poly_busy ? poly_palette_rd_addr :
                             spr_busy  ? spr_palette_rd_addr  : 9'd0;
    assign bg_palette_rd_data   = palette_rd_data;
    assign poly_palette_rd_data = palette_rd_data;
    assign spr_palette_rd_data  = palette_rd_data;

    // ---------------- Árbitro de escrita no framebuffer ----------------
    assign fb_we      = bg_busy ? bg_fb_we : poly_busy ? poly_fb_we : spr_busy ? spr_fb_we : 1'b0;
    assign fb_wr_x     = bg_busy ? bg_fb_wr_x : poly_busy ? poly_fb_wr_x : spr_fb_wr_x;
    assign fb_wr_y     = bg_busy ? bg_fb_wr_y : poly_busy ? poly_fb_wr_y : spr_fb_wr_y;
    assign fb_wr_data  = bg_busy ? bg_fb_wr_data : poly_busy ? poly_fb_wr_data : spr_fb_wr_data;

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            bg_start <= 1'b0; poly_start <= 1'b0; spr_start <= 1'b0;
            done <= 1'b0;
        end else begin
            bg_start <= 1'b0; poly_start <= 1'b0; spr_start <= 1'b0;
            done <= 1'b0;

            case (state)
                S_IDLE: if (start) begin bg_start <= 1'b1; state <= S_BG; end

                // Prioridade 0: background
                S_BG: if (bg_done) begin poly_start <= 1'b1; state <= S_POLY; end

                // Prioridade 1: polígonos
                S_POLY: if (poly_layer_done) begin spr_start <= 1'b1; state <= S_SPR; end

                // Prioridade 2: sprites (mais à frente)
                S_SPR: if (spr_done) state <= S_DONE;

                S_DONE: begin done <= 1'b1; state <= S_IDLE; end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule