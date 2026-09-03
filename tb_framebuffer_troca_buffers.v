`timescale 1ns/1ps

module tb_framebuffer_troca_buffers;

    // ============================================================
    // CLOCKS
    // ============================================================

    reg clk_sys;
    reg clk_pixel;

    // ============================================================
    // INTERFACE DO FRAMEBUFFER
    // ============================================================

    reg        we;
    reg  [8:0] wr_x;
    reg  [7:0] wr_y;
    reg  [8:0] wr_data;
    reg        wr_buf_sel;

    reg  [8:0] rd_x;
    reg  [7:0] rd_y;
    reg        rd_buf_sel;

    wire [8:0] q;

    // ============================================================
    // MEMÓRIAS COMPORTAMENTAIS
    //
    // Elas substituem os framebuffer_ram do IP Catalog.
    // ============================================================

    reg [8:0] buffer0 [0:76799];
    reg [8:0] buffer1 [0:76799];

    // Endereços
    wire [16:0] wr_addr;
    wire [16:0] rd_addr;

    // ============================================================
    // RESOLUÇÃO DO ENDEREÇO
    // ============================================================

    assign wr_addr = (wr_y << 8) + (wr_y << 6) + wr_x;
    assign rd_addr = (rd_y << 8) + (rd_y << 6) + rd_x;

    // ============================================================
    // SIMULAÇÃO DO FRAMEBUFFER
    // ============================================================

    reg [8:0] q0;
    reg [8:0] q1;

    reg rd_buf_sel_sync;

    // ------------------------------------------------------------
    // Escrita
    // ------------------------------------------------------------

    always @(posedge clk_sys) begin

        if (we) begin

            if (wr_buf_sel == 1'b0)
                buffer0[wr_addr] <= wr_data;
            else
                buffer1[wr_addr] <= wr_data;

        end

    end

    // ------------------------------------------------------------
    // Leitura das RAMs
    //
    // Simula a leitura síncrona do framebuffer_ram.
    // ------------------------------------------------------------

    always @(posedge clk_pixel) begin

        q0 <= buffer0[rd_addr];
        q1 <= buffer1[rd_addr];

        rd_buf_sel_sync <= rd_buf_sel;

    end

    // ------------------------------------------------------------
    // MUX de saída
    //
    // Igual ao framebuffer original.
    // ------------------------------------------------------------

    assign q = rd_buf_sel_sync ? q1 : q0;

    // ============================================================
    // VARIÁVEIS DO TESTE
    // ============================================================

    integer i;
    integer errors;

    localparam RED  = 9'b111_000_000;
    localparam BLUE = 9'b000_000_111;

    // ============================================================
    // CLOCK DO SISTEMA
    // ============================================================

    initial begin

        clk_sys = 1'b0;

        forever #5 clk_sys = ~clk_sys;

    end

    // ============================================================
    // CLOCK DO PIXEL
    // ============================================================

    initial begin

        clk_pixel = 1'b0;

        forever #10 clk_pixel = ~clk_pixel;

    end

    // ============================================================
    // PROCEDIMENTO DE ESCRITA
    // ============================================================

    task write_pixel;

        input       buffer;
        input [8:0] x;
        input [7:0] y;
        input [8:0] data;

        begin

            @(negedge clk_sys);

            wr_buf_sel = buffer;
            wr_x       = x;
            wr_y       = y;
            wr_data    = data;
            we         = 1'b1;

            @(negedge clk_sys);

            we = 1'b0;

        end

    endtask

    // ============================================================
    // PROCEDIMENTO DE LEITURA
    // ============================================================

    task select_buffer;

        input buffer;

        begin

            rd_buf_sel = buffer;

            // Espera o sinal atravessar o sincronizador.
            @(posedge clk_pixel);
            @(posedge clk_pixel);

            // Tempo para a RAM síncrona atualizar q0/q1.
            @(posedge clk_pixel);

            #1;

        end

    endtask

    // ============================================================
    // TESTE PRINCIPAL
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Inicialização
        // --------------------------------------------------------

        we         = 1'b0;
        wr_buf_sel = 1'b0;
        wr_x       = 0;
        wr_y       = 0;
        wr_data    = 0;

        rd_x       = 9'd100;
        rd_y       = 8'd100;
        rd_buf_sel = 1'b0;

        errors = 0;

        // --------------------------------------------------------
        // Inicializa os buffers
        // --------------------------------------------------------

        for (i = 0; i < 76800; i = i + 1) begin

            buffer0[i] = 9'd0;
            buffer1[i] = 9'd0;

        end

        // ========================================================
        // CABEÇALHO
        // ========================================================

        $display("");
        $display("====================================================");
        $display("TESTE: TROCA DE BUFFERS");
        $display("====================================================");

        $display("");
        $display("Posicao utilizada:");
        $display("  X = 100");
        $display("  Y = 100");
        $display("");

        $display("BUFFER 0 -> VERMELHO");
        $display("BUFFER 1 -> AZUL");
        $display("");

        // ========================================================
        // PASSO 1
        // Escreve RED no BUFFER 0
        // ========================================================

        $display("----------------------------------------------------");
        $display("PASSO 1: escrevendo RED no BUFFER 0");
        $display("----------------------------------------------------");

        write_pixel(
            1'b0,
            9'd100,
            8'd100,
            RED
        );

        #10;

        if (buffer0[100*320 + 100] !== RED) begin

            $display("ERRO: BUFFER 0 nao recebeu RED.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: BUFFER 0 recebeu RED.");

        end

        // ========================================================
        // PASSO 2
        // Escreve BLUE no BUFFER 1
        // ========================================================

        $display("");
        $display("----------------------------------------------------");
        $display("PASSO 2: escrevendo BLUE no BUFFER 1");
        $display("----------------------------------------------------");

        write_pixel(
            1'b1,
            9'd100,
            8'd100,
            BLUE
        );

        #10;

        if (buffer1[100*320 + 100] !== BLUE) begin

            $display("ERRO: BUFFER 1 nao recebeu BLUE.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: BUFFER 1 recebeu BLUE.");

        end

        // ========================================================
        // PASSO 3
        // Seleciona BUFFER 0 para exibicao
        // ========================================================

        $display("");
        $display("----------------------------------------------------");
        $display("PASSO 3: selecionando BUFFER 0");
        $display("----------------------------------------------------");

        select_buffer(1'b0);

        if (q !== RED) begin

            $display(
                "ERRO: leitura do BUFFER 0 = %09b, esperado RED",
                q
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASSOU: BUFFER 0 esta sendo exibido. q = %09b",
                q
            );

        end

        // ========================================================
        // PASSO 4
        // TROCA PARA BUFFER 1
        // ========================================================

        $display("");
        $display("----------------------------------------------------");
        $display("PASSO 4: realizando troca para BUFFER 1");
        $display("----------------------------------------------------");

        select_buffer(1'b1);

        if (q !== BLUE) begin

            $display(
                "ERRO: leitura do BUFFER 1 = %09b, esperado BLUE",
                q
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASSOU: BUFFER 1 esta sendo exibido. q = %09b",
                q
            );

        end

        // ========================================================
        // PASSO 5
        // Volta para BUFFER 0
        // ========================================================

        $display("");
        $display("----------------------------------------------------");
        $display("PASSO 5: retornando para BUFFER 0");
        $display("----------------------------------------------------");

        select_buffer(1'b0);

        if (q !== RED) begin

            $display(
                "ERRO: leitura do BUFFER 0 = %09b, esperado RED",
                q
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASSOU: BUFFER 0 voltou a ser exibido. q = %09b",
                q
            );

        end

        // ========================================================
        // PASSO 6
        //
        // Verifica que os buffers continuam independentes.
        // ========================================================

        $display("");
        $display("----------------------------------------------------");
        $display("PASSO 6: verificando independencia dos buffers");
        $display("----------------------------------------------------");

        if (buffer0[100*320 + 100] !== RED) begin

            $display("ERRO: BUFFER 0 perdeu seu conteudo.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: BUFFER 0 continua com RED.");

        end

        if (buffer1[100*320 + 100] !== BLUE) begin

            $display("ERRO: BUFFER 1 perdeu seu conteudo.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: BUFFER 1 continua com BLUE.");

        end

        // ========================================================
        // RESULTADO FINAL
        // ========================================================

        $display("");
        $display("====================================================");

        if (errors == 0) begin

            $display(">>> TESTE DE TROCA DE BUFFERS: PASSOU <<<");

        end
        else begin

            $display(">>> TESTE DE TROCA DE BUFFERS: FALHOU <<<");
            $display("Quantidade de erros: %0d", errors);

        end

        $display("====================================================");

        #50;

        $stop;

    end

endmodule