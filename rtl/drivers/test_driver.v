module test_driver (
    input wire clk,
    input wire reset,
    input wire add_poly_en,     // NOVO: 1 = desenha os polígonos este frame, 0 = pula
    output reg  frame_start,
    input  wire poly_phase,
    input  wire frame_done,
    output reg          rast_start_square,
    output reg          rast_start_triangle,
    output reg  [8:0]   rast_v0x, rast_v1x, rast_v2x,
    output reg  [7:0]   rast_v0y, rast_v1y, rast_v2y,
    output reg  [7:0]   rast_color_index,
    output reg          rast_palette_sel,
    input  wire         rast_done,
    output reg  poly_layer_done
);
    localparam T_IDLE           = 4'd0,
               T_FRAME_START    = 4'd1,
               T_WAIT_POLY      = 4'd2,
               T_CHECK_EN       = 4'd3,   // NOVO: decide se desenha ou pula
               T_DRAW_SQUARE    = 4'd4,
               T_WAIT_SQUARE    = 4'd5,
               T_DRAW_TRIANGLE  = 4'd6,
               T_WAIT_TRIANGLE  = 4'd7,
               T_SIGNAL_DONE    = 4'd8,
               T_WAIT_FRAME     = 4'd9;
    reg [3:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state            <= T_IDLE;
            frame_start      <= 1'b0;
            rast_start_square   <= 1'b0;
            rast_start_triangle <= 1'b0;
            poly_layer_done  <= 1'b0;
        end else begin
            frame_start         <= 1'b0;
            rast_start_square   <= 1'b0;
            rast_start_triangle <= 1'b0;
            poly_layer_done     <= 1'b0;
            case (state)
                T_IDLE: begin
                    frame_start <= 1'b1;
                    state <= T_WAIT_POLY;
                end
                T_WAIT_POLY: if (poly_phase) state <= T_CHECK_EN;

                // NOVO: se o switch estiver desligado, pula direto pra sinalizar
                // fim da fase de polígono, sem desenhar quadrado nem triângulo
                T_CHECK_EN: state <= add_poly_en ? T_DRAW_SQUARE : T_SIGNAL_DONE;

                T_DRAW_SQUARE: begin
                    // Quadrado de teste, canto superior esquerdo
                    rast_v0x <= 9'd20;  rast_v0y <= 8'd20;
                    rast_v1x <= 9'd60;  rast_v1y <= 8'd60;
                    rast_color_index <= 8'd1;
                    rast_palette_sel <= 1'b0;
                    rast_start_square <= 1'b1;
                    state <= T_WAIT_SQUARE;
                end
                T_WAIT_SQUARE: if (rast_done) state <= T_DRAW_TRIANGLE;
                T_DRAW_TRIANGLE: begin
						 // Triangulo de teste, deslocado +20 pixels no eixo X
						 rast_v0x <= 9'd70;  rast_v0y <= 8'd100;
						 rast_v1x <= 9'd40;  rast_v1y <= 8'd160;
						 rast_v2x <= 9'd100; rast_v2y <= 8'd160;

					 	 // Vermelho comunista: RRRGGGBBB
						 // 111_000_000 = vermelho máximo
						 rast_color_index <= 8'd13;
						 rast_palette_sel <= 1'b0;

						 rast_start_triangle <= 1'b1;
						 state <= T_WAIT_TRIANGLE;
					end
                T_WAIT_TRIANGLE: if (rast_done) state <= T_SIGNAL_DONE;
                T_SIGNAL_DONE: begin
                    poly_layer_done <= 1'b1;
                    state <= T_WAIT_FRAME;
                end
                T_WAIT_FRAME: if (frame_done) state <= T_IDLE; // repete pra sempre
                default: state <= T_IDLE;
            endcase
        end
    end
endmodule