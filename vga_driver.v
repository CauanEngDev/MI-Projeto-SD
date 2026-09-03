module vga_driver (
    input wire clock,      // Pixel clock (25 MHz para 640x480@60Hz)
    input wire reset,      // Reset síncrono, ativo alto
    input [8:0] color_in,  // Cor vinda do framebuffer (RRRGGGBBB, 1 ciclo de latência de leitura)

    output [9:0] next_x,   // Coordenada X (física, 0-639) a ser usada como endereço de leitura do framebuffer
    output [9:0] next_y,   // Coordenada Y (física, 0-479) a ser usada como endereço de leitura do framebuffer

    output wire hsync,     // HSYNC para o conector VGA
    output wire vsync,     // VSYNC para o conector VGA
    output [7:0] red,      // Canal vermelho (pro DAC resistivo do conector VGA)
    output [7:0] green,    // Canal verde
    output [7:0] blue,     // Canal azul
    output sync,           // SYNC (composto, não usado — fixo em 0)
    output clk,            // CLK repassado ao conector VGA
    output blank,          // BLANK — ativo quando fora da área ativa de exibição

    output wire vblank_tick // pulso de 1 ciclo no início do blanking vertical
);

    // ---------------------------------------------------------------
    // Parâmetros de timing horizontal (em ciclos de pixel clock)
    // ---------------------------------------------------------------
    parameter [9:0] H_ACTIVE = 10'd639; // 640 pixels ativos (0-639)
    parameter [9:0] H_FRONT  = 10'd15;  // front porch horizontal
    parameter [9:0] H_PULSE  = 10'd95;  // pulso de sincronismo horizontal
    parameter [9:0] H_BACK   = 10'd47;  // back porch horizontal

    // ---------------------------------------------------------------
    // Parâmetros de timing vertical (em linhas)
    // ---------------------------------------------------------------
    parameter [9:0] V_ACTIVE = 10'd479; // 480 linhas ativas (0-479)
    parameter [9:0] V_FRONT  = 10'd9;   // front porch vertical
    parameter [9:0] V_PULSE  = 10'd1;   // pulso de sincronismo vertical
    parameter [9:0] V_BACK   = 10'd32;  // back porch vertical

    // Constantes de legibilidade
    parameter LOW  = 1'b0;
    parameter HIGH = 1'b1;

    // Estados da FSM horizontal
    parameter [7:0] H_ACTIVE_STATE = 8'd0;
    parameter [7:0] H_FRONT_STATE  = 8'd1;
    parameter [7:0] H_PULSE_STATE  = 8'd2;
    parameter [7:0] H_BACK_STATE   = 8'd3;

    // Estados da FSM vertical
    parameter [7:0] V_ACTIVE_STATE = 8'd0;
    parameter [7:0] V_FRONT_STATE  = 8'd1;
    parameter [7:0] V_PULSE_STATE  = 8'd2;
    parameter [7:0] V_BACK_STATE   = 8'd3;

    // Registradores de saída (sync e cor final, já com o atraso extra aplicado)
    reg hysnc_reg, vsync_reg;
    reg [7:0] red_reg, green_reg, blue_reg;

    reg line_done; // pulso: fim de uma linha horizontal completa
    reg vblank_tick_reg; // pulso de início de blanking vertical

    // Contadores/estado "de posição" — não sofrem o atraso extra,
    // pois são justamente a base usada para gerar next_x/next_y
    reg [9:0] h_counter, v_counter;
    reg [7:0] h_state, v_state;

    // Estado atrasado em 1 ciclo extra: usado só para gatear a cor final,
    // para compensar a latência de leitura registrada do framebuffer
    reg [7:0] h_state_d1, v_state_d1;

    // Sync "pré-atraso": versão intermediária de hsync/vsync antes do
    // estágio extra de registro que as alinha com a cor atrasada
    reg hysnc_pre, vsync_pre;

    always@(posedge clock) begin
        if (reset) begin
            // Zera contadores e força as FSMs de volta ao estado ativo
            h_counter  <= 10'd0;
            v_counter  <= 10'd0;
            h_state    <= H_ACTIVE_STATE;
            v_state    <= V_ACTIVE_STATE;
            line_done  <= LOW;
            h_state_d1 <= H_ACTIVE_STATE;
            v_state_d1 <= V_ACTIVE_STATE;
            vblank_tick_reg <= LOW;
        end
        else begin
            //  default — só fica em HIGH no ciclo exato do pulso
            vblank_tick_reg <= LOW;

            //////////////////////////////////////////////////////////
            //////////////////// HORIZONTAL ////////////////////////////
            //////////////////////////////////////////////////////////
            if (h_state == H_ACTIVE_STATE) begin
                // Incrementa contador horizontal; volta a 0 no fim da região ativa
                h_counter <= (h_counter==H_ACTIVE) ? 10'd0 : (h_counter + 10'd1);
                // Fora do pulso de sync, hsync fica em nível alto
                hysnc_pre <= HIGH;
                line_done <= LOW;
                // Transição de estado ao fim da região ativa
                h_state   <= (h_counter==H_ACTIVE) ? H_FRONT_STATE : H_ACTIVE_STATE;
            end
            if (h_state == H_FRONT_STATE) begin
                h_counter <= (h_counter==H_FRONT) ? 10'd0 : (h_counter + 10'd1);
                hysnc_pre <= HIGH;
                h_state   <= (h_counter==H_FRONT) ? H_PULSE_STATE : H_FRONT_STATE;
            end
            if (h_state == H_PULSE_STATE) begin
                h_counter <= (h_counter==H_PULSE) ? 10'd0 : (h_counter + 10'd1);
                // Durante o pulso de sync, hsync vai a nível baixo
                hysnc_pre <= LOW;
                h_state   <= (h_counter==H_PULSE) ? H_BACK_STATE : H_PULSE_STATE;
            end
            if (h_state == H_BACK_STATE) begin
                h_counter <= (h_counter==H_BACK) ? 10'd0 : (h_counter + 10'd1);
                hysnc_pre <= HIGH;
                h_state   <= (h_counter==H_BACK) ? H_ACTIVE_STATE : H_BACK_STATE;
                // Sinaliza fim de linha um ciclo antes da transição de estado,
                // para compensar o atraso síncrono da própria FSM
                line_done <= (h_counter == (H_BACK-1)) ? HIGH : LOW;
            end

            //////////////////////////////////////////////////////////
            //////////////////// VERTICAL //////////////////////////////
            //////////////////////////////////////////////////////////
            if (v_state == V_ACTIVE_STATE) begin
                // Só avança o contador vertical quando uma linha termina
                v_counter <= (line_done==HIGH) ? ((v_counter==V_ACTIVE) ? 10'd0 : (v_counter+10'd1)) : v_counter;
                vsync_pre <= HIGH;
                v_state   <= (line_done==HIGH) ? ((v_counter==V_ACTIVE) ? V_FRONT_STATE : V_ACTIVE_STATE) : V_ACTIVE_STATE;
                // dispara o pulso exatamente quando a última linha ativa termina
                vblank_tick_reg <= (line_done==HIGH && v_counter==V_ACTIVE) ? HIGH : LOW;
            end
            if (v_state == V_FRONT_STATE) begin
                v_counter <= (line_done==HIGH) ? ((v_counter==V_FRONT) ? 10'd0 : (v_counter+10'd1)) : v_counter;
                vsync_pre <= HIGH;
                v_state   <= (line_done==HIGH) ? ((v_counter==V_FRONT) ? V_PULSE_STATE : V_FRONT_STATE) : V_FRONT_STATE;
            end
            if (v_state == V_PULSE_STATE) begin
                v_counter <= (line_done==HIGH) ? ((v_counter==V_PULSE) ? 10'd0 : (v_counter+10'd1)) : v_counter;
                // Durante o pulso de sync vertical, vsync vai a nível baixo
                vsync_pre <= LOW;
                v_state   <= (line_done==HIGH) ? ((v_counter==V_PULSE) ? V_BACK_STATE : V_PULSE_STATE) : V_PULSE_STATE;
            end
            if (v_state == V_BACK_STATE) begin
                v_counter <= (line_done==HIGH) ? ((v_counter==V_BACK) ? 10'd0 : (v_counter+10'd1)) : v_counter;
                vsync_pre <= HIGH;
                v_state   <= (line_done==HIGH) ? ((v_counter==V_BACK) ? V_ACTIVE_STATE : V_BACK_STATE) : V_BACK_STATE;
            end

            //////////////////////////////////////////////////////////
            //////// ESTÁGIO EXTRA DE ATRASO (correção de latência) ////
            //////////////////////////////////////////////////////////
            h_state_d1 <= h_state;       // versão atrasada do estado horizontal
            v_state_d1 <= v_state;       // versão atrasada do estado vertical
            hysnc_reg  <= hysnc_pre;     // hsync final, 1 ciclo depois do "pre"
            vsync_reg  <= vsync_pre;     // vsync final, 1 ciclo depois do "pre"

            red_reg   <= (h_state_d1==H_ACTIVE_STATE) ? ((v_state_d1==V_ACTIVE_STATE) ? {color_in[8:6],5'd0} : 8'd0) : 8'd0;
            green_reg <= (h_state_d1==H_ACTIVE_STATE) ? ((v_state_d1==V_ACTIVE_STATE) ? {color_in[5:3],5'd0} : 8'd0) : 8'd0;
            blue_reg  <= (h_state_d1==H_ACTIVE_STATE) ? ((v_state_d1==V_ACTIVE_STATE) ? {color_in[2:0],5'd0} : 8'd0) : 8'd0;
        end
    end

    // Saídas físicas para o conector VGA
    assign hsync = hysnc_reg;
    assign vsync = vsync_reg;
    assign red   = red_reg;
    assign green = green_reg;
    assign blue  = blue_reg;
    assign clk   = clock;
    assign sync  = 1'b0;               // sync composto não utilizado nesse DAC
    assign blank = hysnc_reg & vsync_reg;
    assign vblank_tick = vblank_tick_reg;

    assign next_x = (h_state==H_ACTIVE_STATE) ? h_counter : 10'd0;
    assign next_y = (v_state==V_ACTIVE_STATE) ? v_counter : 10'd0;

endmodule