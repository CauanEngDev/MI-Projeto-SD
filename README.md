# CoProcessador Grafico em FPGA - Sistema Digital 2026.2

## Sumário

* [1. Visão Geral do Projeto](#1-visão-geral-do-projeto)

  * [1.1 Conceito Geral](#11-conceito-geral)
  * [1.2 Da Descricao da Cena ao Pixel](#12-da-descricao-da-cena-ao-pixel)
  * [1.3 Resolucao e Representacao da Imagem](#13-resolucao-e-representacao-da-imagem)
  * [1.4 Arquitetura Grafica em Hardware](#14-arquitetura-grafica-em-hardware)
  * [1.5 Composicao e Memoria de Video](#15-composicao-e-memoria-de-video)
  * [1.6 Double Buffering](#16-double-buffering)
  * [1.7 Organizacao Modular](#17-organizacao-modular)
  * [1.8 Estrutura Principal do Projeto](#18-estrutura-principal-do-projeto)

* [2. Levantamento de Requisitos](#2-levantamento-de-requisitos)

  * [2.1 Requisitos Funcionais](#21-requisitos-funcionais)
  * [2.2 Requisitos de Memória](#22-requisitos-de-memória)

* [3. Fundamentação Teórica](#3-fundamentação-teórica)

  * [3.1 Representação Gráfica Indexada](#31-representação-gráfica-indexada)
  * [3.2 Background Baseado em Tiles](#32-background-baseado-em-tiles)
  * [3.3 Scroll e Wraparound](#33-scroll-e-wraparound)
  * [3.4 Sprites](#34-sprites)
  * [3.5 Espelhamento](#35-espelhamento)
  * [3.6 Rasterização](#36-rasterização)
  * [3.7 Double Buffering](#37-double-buffering)
  * [3.8 VGA](#38-vga)

* [4. Arquitetura do Sistema](#4-arquitetura-do-sistema)

  * [4.1 Fluxo de Composição](#41-fluxo-de-composição)
  * [4.2 Principais Módulos](#42-principais-módulos)
  * [4.3 Memórias do Sistema](#43-memórias-do-sistema)

    * [4.3.1 `bg_tile_ram` — 1200 × 8 bits](#431-bg_tile_ram--1200--8-bits)
    * [4.3.2 `bg_tile_pattern_ram` — 16384 × 8 bits](#432-bg_tile_pattern_ram--16384--8-bits)
    * [4.3.3 `sprite_attribute_ram` — 32 × 32 bits](#433-sprite_attribute_ram--32--32-bits)
    * [4.3.4 `sprite_pattern_ram` — 16384 × 8 bits](#434-sprite_pattern_ram--16384--8-bits)
    * [4.3.5 `palette_ram` — 512 × 9 bits](#435-palette_ram--512--9-bits)
    * [4.3.6 `framebuffer_ram` — 2 bancos de 76800 × 9 bits](#436-framebuffer_ram--2-bancos-de-76800--9-bits)
  * [4.4 Organização do Armazenamento](#44-organização-do-armazenamento)

* [5. Especificação de Hardware e Software](#5-especificação-de-hardware-e-software)

* [6. Processo de Desenvolvimento](#6-processo-de-desenvolvimento)

* [7. Instalação e Configuração](#7-instalação-e-configuração)

* [8. Testes e Erros](#8-testes-e-erros)
    * [8.0.1 Simulação](#801-simulacao)
  * [8.1 Testes do Rasterizador de Quadrados](#81-testes-do-rasterizador-de-quadrados)
  * [8.2 Testes do Motor de Background](#82-testes-do-motor-de-background)
  * [8.3 Teste de Transparência das Sprites](#83-teste-de-transparência-das-sprites)
  * [8.4 Teste de Espelhamento](#84-teste-de-espelhamento)
  * [8.5 Teste de Sobreposição](#85-teste-de-sobreposição)
  * [8.6 Teste de Prioridade das Sprites](#86-teste-de-prioridade-das-sprites)
  * [8.7 Teste de Troca de Buffers](#87-teste-de-troca-de-buffers)
  * [8.8 Testes de Integração](#88-testes-de-integração)
  * [8.9 Erros, Limitações e Decisões de Projeto](#89-erros-limitações-e-decisões-de-projeto)

    * [8.9.1 Módulos Auxiliares para Demonstração](#891-módulos-auxiliares-para-demonstração)
    * [8.9.2 Problema Identificado na Demonstração](#892-problema-identificado-na-demonstração)
    * [8.9.3 Comandos Inválidos](#893-comandos-inválidos)

* [9. Análise do Resultado](#9-análise-do-resultado)

  * [9.1 Resultados de Simulação](#91-resultados-de-simulação)
  * [9.2 Resultados da Demonstração em Hardware](#92-resultados-da-demonstração-em-hardware)
  * [9.3 Atendimento aos Requisitos](#93-atendimento-aos-requisitos)
  * [9.4 Recursos, Timing e Desempenho](#94-recursos-timing-e-desempenho)
  * [9.5 Gargalos e Limitações](#95-gargalos-e-limitações)
  * [9.6 Melhorias Possíveis](#96-melhorias-possíveis)
  * [9.7 Funcionalidades Não Atendidas](#97-funcionalidades-não-atendidas)

* [10. Controles da Demonstração na FPGA](#10-controles-da-demonstração-na-fpga)

* [11. Equipe do Desenvolvimento](#12-equipe-do-desenvolvimento)

* [12. Referências](#13-referências)

Projeto desenvolvido para o Problema #1 - 2026.2 / Sistema Digital, com o objetivo de implementar, em FPGA, um nucleo de coprocessamento grafico inspirado na arquitetura de consoles de 16 bits. A solucao implementa geracao de background por tiles, sprites com atributos e prioridade, rasterizacao de poligonos, framebuffer com double buffering e saida VGA.

Estado atual do projeto:
Esta versao implementa o nucleo grafico em FPGA e sua demonstracao diretamente na placa DE1-SoC. A integracao posterior com Linux, driver em ARM Assembly e jogo em C faz parte da continuidade proposta para o sistema, mas nao esta presente nesta versao do repositorio.


# 1. VISAO GERAL DO PROJETO

Este projeto consiste no desenvolvimento de um sistema grafico dedicado implementado em FPGA, capaz de receber parametros de objetos graficos, processa-los em hardware e construir uma imagem destinada a exibicao em um monitor VGA.

A ideia central do projeto e explorar como funcionalidades normalmente associadas a um sistema grafico podem ser implementadas diretamente em hardware digital reconfiguravel, utilizando modulos especializados para executar diferentes etapas do processo de renderizacao.

Em vez de utilizar o processador principal para determinar e escrever individualmente cada pixel da imagem, o sistema trabalha com elementos graficos e seus respectivos parametros, permitindo que a FPGA execute as operacoes necessarias para gerar, rasterizar, compor e armazenar os pixels da cena.

Dessa forma, o projeto pode ser entendido como uma pequena pipeline grafica em hardware, na qual diferentes componentes cooperam para transformar informacoes abstratas sobre a cena em uma imagem efetivamente exibida no monitor.

## 1.1 Conceito Geral

A arquitetura foi organizada com base na separacao entre controle, processamento grafico, armazenamento e saida de video.

O processador e os modulos de controle fornecem informacoes como posicoes, dimensoes, padroes graficos, cores, prioridades e demais parametros necessarios para a construcao da cena.

A partir dessas informacoes, unidades especializadas da FPGA realizam o processamento correspondente a cada tipo de elemento grafico.

Entre os principais recursos implementados estao:

- Background baseado em tiles, utilizado para a construcao do cenario;
- Primitivas geometricas rasterizadas, atualmente com suporte a retangulos e triangulos preenchidos;
- Sprites, com parametros de posicao, padrao grafico, prioridade, paleta e espelhamento;
- Composicao grafica, responsavel por combinar os diferentes elementos da cena;
- Framebuffer, utilizado para armazenar os pixels do quadro produzido;
- Double buffering, permitindo a construcao de um quadro enquanto outro e exibido;
- Controlador VGA, responsavel pela leitura do framebuffer e geracao dos sinais necessarios para a exibicao.

A organizacao desses componentes permite que cada etapa possua uma responsabilidade especifica, formando uma arquitetura modular e extensivel.

## 1.2 Da Descricao da Cena ao Pixel

Um dos principais objetivos do projeto e demonstrar a transformacao de uma descricao relativamente abstrata da cena em uma sequencia de pixels.

De forma simplificada, o processo pode ser representado como:

    PARAMETROS DA CENA
            |
            v
    +---------------------+
    |    MOTORES GRAFICOS |
    +---------------------+
       |       |       |
       v       v       v
    BACKGROUND POLIGONOS SPRITES
       |       |       |
       +-------+-------+
               |
               v
          COMPOSICAO
               |
               v
          FRAMEBUFFER
               |
               v
         CONTROLADOR VGA
               |
               v
            MONITOR

Cada motor grafico interpreta seus respectivos parametros e produz os elementos necessarios para a construcao do quadro.

Esses elementos sao posteriormente submetidos a logica de composicao, que determina como eles devem coexistir na imagem final, considerando aspectos como sobreposicao e prioridade grafica.

O resultado e entao armazenado no framebuffer e disponibilizado ao controlador VGA.

## 1.3 Resolucao e Representacao da Imagem

A imagem e construida internamente em uma resolucao logica de 320 x 240 pixels.

Essa resolucao foi adotada como representacao interna da cena, reduzindo a quantidade de pixels que precisam ser processados e armazenados pelos circuitos graficos.

Para a saida VGA em 640 x 480 pixels, cada pixel logico e representado por um bloco de 2 x 2 pixels fisicos:

    Pixel logico
    +---+---+
    |   |   |
    +---+---+
    |   |   |
    +---+---+

     2 x 2

Assim, o sistema mantem uma representacao grafica mais compacta internamente, enquanto produz uma imagem compativel com o modo VGA utilizado pelo projeto.

## 1.4 Arquitetura Grafica em Hardware

Um dos aspectos centrais do projeto e a implementacao das operacoes graficas diretamente na logica programavel da FPGA.

Em uma abordagem convencional, o processador poderia ser responsavel por calcular as posicoes, determinar os pixels pertencentes a cada objeto e realizar sucessivas escritas na memoria de video.

Neste projeto, parte significativa desse trabalho e transferida para modulos de hardware especializados.

Essa abordagem permite explorar caracteristicas proprias de uma FPGA, como:

- Processamento dedicado;
- Paralelismo entre diferentes blocos de hardware;
- Maquinas de estados para controle de operacoes;
- Acesso estruturado as memorias graficas;
- Processamento orientado a pixels;
- Modularizacao dos componentes de renderizacao.

O resultado e uma arquitetura na qual software e hardware possuem responsabilidades distintas: o software pode definir o que deve ser desenhado, enquanto o hardware executa como esse desenho sera convertido em pixels.

## 1.5 Composicao e Memoria de Video

Depois que os diferentes elementos graficos sao gerados, eles precisam ser combinados para formar um unico quadro.

Essa etapa e realizada pela logica de composicao, que organiza os elementos provenientes dos diferentes motores graficos e determina o conteudo final de cada posicao da imagem.

O resultado da composicao e armazenado em um framebuffer, que funciona como a representacao em memoria do quadro que sera exibido.

O framebuffer estabelece, portanto, a interface entre o processamento grafico e a saida de video:

    Motores graficos
           |
           v
       Compositor
           |
           v
      Framebuffer
           |
           v
     Controlador VGA
           |
           v
        Monitor

Essa separacao permite que a geracao da imagem e sua exibicao ocorram de maneira organizada e sincronizada.

## 1.6 Double Buffering

Para evitar que o quadro exibido seja alterado enquanto ainda esta sendo lido pelo controlador VGA, o sistema utiliza double buffering.

Sao mantidos dois buffers de imagem:

    +------------------+
    |    BUFFER A      |
    |                  |
    |     EXIBICAO     |
    +------------------+

    +------------------+
    |    BUFFER B      |
    |                  |
    |    RENDERIZACAO  |
    +------------------+

Enquanto um buffer fornece os dados para a saida VGA, o outro pode ser atualizado pelos motores graficos.

Quando um novo quadro esta pronto, os buffers sao alternados de forma sincronizada com o sinal de video, utilizando o periodo de vertical blanking como momento adequado para a troca.

Esse mecanismo reduz artefatos visuais decorrentes da leitura de uma imagem enquanto ela ainda esta sendo modificada.

## 1.7 Organizacao Modular

A implementacao foi estruturada de maneira modular, permitindo separar as diferentes responsabilidades do sistema grafico.

Em uma visao macro, a arquitetura pode ser organizada da seguinte forma:

                    SISTEMA DE VIDEO
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
     BACKGROUND        POLIGONOS         SPRITES
       ENGINE            ENGINE           ENGINE
          |                |                |
          +----------------+----------------+
                           |
                           v
                      COMPOSITOR
                           |
                           v
                     FRAMEBUFFER
                           |
                           v
                  DOUBLE BUFFERING
                           |
                           v
                    CONTROLADOR VGA
                           |
                           v
                        MONITOR

Essa modularizacao facilita a implementacao, os testes individuais, a depuracao e a expansao da arquitetura, permitindo que novos recursos graficos possam ser incorporados sem a necessidade de reestruturar completamente o sistema.

## 1.8 Estrutura Principal do Projeto

O modulo de nivel superior utilizado na integracao com a plataforma e:

DE1_SOC_golden_top.v

A integracao principal do sistema grafico e realizada em:

top_video.v

A partir desses modulos sao conectados os diferentes componentes responsaveis pelo processamento grafico, armazenamento e geracao da saida de video.

As proximas secoes apresentam cada uma dessas partes em maior profundidade, detalhando o funcionamento dos motores graficos, organizacao da memoria, rasterizacao, sprites, composicao, framebuffer, double buffering e controlador VGA.



## 2. Levantamento de Requisitos

A partir da análise do enunciado do Problema #1 e das especificações para a plataforma Intel/Altera **DE1-SoC**, os requisitos do sistema foram estruturados entre **Requisitos Funcionais (RF)**, **Requisitos Não Funcionais (RNF)** e um **Mapeamento Detalhado da Organização de Memória**.

---

## 2.1 Requisitos Funcionais

| ID | Requisito | Detalhamento Técnico | Status |
| :--- | :--- | :--- | :--- |
| **RF01** | **Resolução Lógica** | Processamento interno da cena em $320 \times 240$ pixels. | **IMPLEMENTADO** |
| **RF02** | **Saída de Vídeo VGA** | Sinalização física padrão VGA $640 \times 480 @ 60\text{Hz}$ ($25.175\text{ MHz}$ pixel clock). | **IMPLEMENTADO** |
| **RF03** | **Pixel Scaling ($2 \times 2$)** | Duplicação do tamanho do pixel lógico no motor VGA (mapeamento $1\text{ pixel lógico} \to 4\text{ pixels físicos}$). | **IMPLEMENTADO** |
| **RF04** | **Tilemap de Background** | Grade de $40 \times 30$ tiles cobrindo a resolução de $320 \times 240$ | **IMPLEMENTADO** |
| **RF05** | **Tiles de $8 \times 8$ Pixels** | Dimensão fixa dos blocos gráficos da camada de background. | **IMPLEMENTADO** |
| **RF06** | **Scrolling Horizontal e Vertical** | Deslocamento contínuo em X e Y com lógica de *wraparound* (repetição das bordas da matriz). | **IMPLEMENTADO** |
| **RF07** | **Banco de Padrões de Background** | Suporte de memória interna para armazenar até 256 tiles gráficos únicos ($8 \times 8$). | **IMPLEMENTADO** |
| **RF08** | **Engine de Sprites** | Unidade dedicada para renderização de no mínimo 32 sprites independentes. | **IMPLEMENTADO** |
| **RF09** | **Dimensão dos Sprites ($16 \times 16$)** | Sprites compostos por arranjos de $2 \times 2$ tiles de $8 \times 8$ pixels. | **IMPLEMENTADO** |
| **RF10** | **Atributos de Sprites** | Posição X ($9\text{ bits}$), Y ($8\text{ bits}$), Enable ($1\text{ bit}$), Flip H/V ($2\text{ bits}$), Prioridade e Seleção de Paleta. | **IMPLEMENTADO** |
| **RF11** | **Transparência por Cor Nula** | Índice de cor `0x00` tratado como transparente na sobreposição de camadas (Sprites e Polígonos). | **IMPLEMENTADO** |
| **RF12** | **Rasterização de Retângulos** | Unidade aritmética para preenchimento de retângulos parametrizados por $(X_0, Y_0, \text{Largura}, \text{Altura}, \text{Cor})$. | **IMPLEMENTADO** |
| **RF13** | **Rasterização de Triângulos** | Algoritmo de renderização baseado em lógica inteira (varredura por *scanline*). | **IMPLEMENTADO** |
| **RF14** | **Paleta de Cores Programável** | Look-Up Table (LUT) de 256 entradas convertendo índices de 8 bits em saídas RGB (3 bits por canal / $9\text{ bits}$ total). | **IMPLEMENTADO** |
| **RF15** | **Double Buffering** | Implementação de dois bancos de memória (*Front* e *Back Buffer*) para renderização sem *screen tearing*. | **IMPLEMENTADO** |
| **RF16** | **Troca de Buffer em VBlank** | *Swap* dos ponteiros de exibição travado estritamente durante o intervalo de sincronismo vertical (VBlank). | **IMPLEMENTADO** |
| **RF17** | **Testes de Módulos e Integração** | Testbenches unitários para os motores gráficos/rasterizadores e testbench top-level cobrindo cenários de borda. | **IMPLEMENTADO** |
| **RF18** | **Driver Linux (Assembly ARM)** | Driver por acesso de memória mapeada (MMIO). | **NÃO IMPLEMENTADO** *(Etapa posterior)* |
| **RF19** | **Aplicação/Jogo Final em C** | Lógica de jogo integrando os controles e acelerômetro. | **NÃO IMPLEMENTADO** *(Etapa posterior)* |

---

## 2.2 Requisitos Não Funcionais

1. **Plataforma e Hardware Alvo:**
  - FPGA Altera/Intel **Cyclone V SE (5CSEMA5F31C6)** contida na placa **DE1-SoC**.
2. **Frequências de Clock e Domínios de Sincronismo:**
  - **System Clock ($50\text{ MHz}$):** Utilizado pelo núcleo de processamento do co-processador, rasterizador de polígonos e interface de comandos.
  - **VGA Pixel Clock ($25.175\text{ MHz}$):** Gerado via **PLL (Phase-Locked Loop)** interno da FPGA para sincronização rigorosa do gerador de sinais VGA ($640 \times 480 @ 60\text{Hz}$).
3. **Linguagem de Descrição de Hardware:**
  - Todo o coprocessador sintetizável é codificado estritamente em **Verilog HDL (IEEE 1364-2001)**.
4. **Interface de Controle (Protocolo de Comandos):**
  - Receptor de instruções com palavras de **32 bits**, estruturado para permitir integração direta a um barramento de periféricos no modelo MMIO.
5. **Estabilidade Visual e Ausência de Glitches:**
  - O sinal VGA opera sem perda de sincronismo (*glitch* no *H-Sync*/*V-Sync*) durante operações de escrita simultânea do rasterizador nas memórias internas.
6. **Otimização de Recursos Internos (M10K Blocks):**
  - Utilização otimizada dos blocos de RAM embutida (Block RAM / M10K) da Cyclone V para garantir que o *Double Buffering* e os bancos de padrões caibam dentro dos limites físicos do chip.

---

## 2.3 Requisitos de Memória e Organização Interna

A arquitetura utiliza memórias estáticas organizadas internamente na FPGA para atender às exigências do pipeline gráfico em tempo real a $60\text{ fps}$.

### Detalhamento dos Blocos de Memória

* **Tilemap do Background:**
  * **Dimensões:** Grade de $40 \times 30$ posições ($1.200$ palavras).
  * **Largura da Palavra:** $8\text{ bits}$ (endereça até 256 padrões de tiles gráficos).
  * **Capacidade Total:** $1.200\text{ Bytes} \approx 1,17\text{ KiB}$.

* **Memória de Padrões do Background (Pattern RAM):**
  * **Capacidade:** 256 tiles únicos de $8 \times 8$ pixels ($16.384$ pixels armazenados).
  * **Profundidade de Cor:** $8\text{ bits/pixel}$ (índice da paleta).
  * **Capacidade Total:** $16.384\text{ Bytes} = 16\text{ KiB}$.

* **Tabela de Atributos de Sprites (OAM - Object Attribute Memory):**
  * **Quantidade de Sprites:** 32 objetos.
  * **Tamanho por Registro:** $32\text{ bits}$.
  * **Capacidade Total:** $32 \times 32\text{ bits} = 128\text{ Bytes}$.
  * **Mapeamento de Bitfields ($32\text{ bits}$):**
    * `[8:0]` — Posição X ($9\text{ bits}$, intervalo $0$ a $319$).
    * `[16:9]` — Posição Y ($8\text{ bits}$, intervalo $0$ a $239$).
    * `[24:17]` — Índice do Padrão/Tile Inicial ($8\text{ bits}$, intervalo $0$ a $255$).
    * `[25]` — Bit de Habilitação (*Sprite Enable*).
    * `[26]` — Flip Horizontal (*H-Flip*).
    * `[27]` — Flip Vertical (*V-Flip*).
    * `[29:28]` — Seleção de Prioridade de Camada ($2\text{ bits}$).
    * `[31:30]` — Seleção de Sub-paleta / Reservado.

* **Memória de Padrões de Sprites (Sprite Pattern RAM):**
  * **Capacidade:** Suporte a 64 sprites únicos de $16 \times 16$ pixels ($16.384$ pixels armazenados).
  * **Profundidade de Cor:** $8\text{ bits/pixel}$.
  * **Capacidade Total:** $16.384\text{ Bytes} = 16\text{ KiB}$.

* **Paleta de Cores (Color LUT):**
  * **Entradas:** 256 posições de cor.
  * **Largura do Pixel:** $9\text{ bits}$ ($3\text{ bits Red}$, $3\text{ bits Green}$, $3\text{ bits Blue}$) adaptados ao DAC da placa DE1-SoC.
  * **Capacidade Total:** $256 \times 9\text{ bits} = 2.304\text{ bits} = 288\text{ Bytes}$.

* **Framebuffer Integrado (Double Buffering):**
  * **Resolução Lógica:** $320 \times 240\text{ pixels}$ ($76.800\text{ pixels/frame}$).
  * **Tamanho do Pixel no Banco:** $8\text{ bits}$ (Índice de Cor) $+ 1\text{ bit}$ (Controle/Prioridade) = $9\text{ bits}$.
  * **Capacidade por Banco:** $76.800 \times 9\text{ bits} = 691.200\text{ bits} \approx 84,37\text{ KiB}$ por banco.
  * **Capacidade Total ($2 \times\text{Bancos - Front/Back}$):** $153.600\text{ palavras} = 1.382.400\text{ bits} \approx 168,75\text{ KiB}$.

---

### Consumo Teórico Estimado de RAM Interna

$$\text{Total RAM} = \text{Tilemap} + \text{Patterns (BG + Sprite)} + \text{OAM} + \text{Paleta} + \text{Framebuffer (2x)}$$

$$\text{Total RAM} \approx 1,17\text{ KiB} + 32\text{ KiB} + 0,125\text{ KiB} + 0,28\text{ KiB} + 168,75\text{ KiB} \approx \mathbf{202,32\text{ KiB}}$$

> **Nota:** A FPGA Cyclone V (5CSEMA5F31C6) possui aproximadamente **$4.450\text{ KiB}$** de memória M10K disponível. A arquitetura projetada consome menos de **$5\%$** do total de memória RAM interna, permitindo alocação eficiente de recursos e sintetizabilidade sem gargalos de hardware.



# 3. FUNDAMENTACAO TEORICA

A fundamentacao teorica deste projeto apresenta os principais conceitos de computacao grafica utilizados na construcao do sistema de video implementado em FPGA.

A arquitetura combina diferentes tecnicas de representacao, armazenamento e processamento de imagens, permitindo que elementos graficos sejam gerados diretamente em hardware e posteriormente combinados em um quadro destinado a exibicao em um monitor VGA.

Os principais conceitos abordados sao a representacao grafica indexada, o uso de tiles para construcao do background, scroll e wraparound, sprites, espelhamento, rasterizacao de primitivas geometricas, double buffering e a geracao da saida VGA.

A utilizacao desses conceitos permite organizar o processamento grafico em modulos especializados, reduzindo a dependencia do processador para a geracao individual dos pixels e explorando caracteristicas proprias da implementacao em FPGA, como processamento dedicado, paralelismo e acesso estruturado a memorias.


## 3.1 Representacao Grafica Indexada

A representacao grafica indexada e uma tecnica na qual os pixels de uma imagem nao armazenam diretamente todos os componentes de sua cor. Em vez disso, cada pixel armazena um indice que referencia uma entrada de uma paleta de cores.

No projeto, os padroes utilizados por tiles e sprites sao armazenados utilizando indices de 8 bits. Dessa forma, cada pixel do padrao representa uma posicao dentro da paleta, e nao diretamente os valores de vermelho, verde e azul.

O processo pode ser representado de forma simplificada por:

    INDICE DO PIXEL
           |
           v
    +----------------+
    |     PALETA     |
    +----------------+
           |
           v
      COR RGB DE 9 BITS

A cor utilizada pelo sistema possui 9 bits, organizados no formato:

RRR GGG BBB

Sao utilizados 3 bits para cada componente de cor, permitindo representar oito niveis de intensidade para vermelho, verde e azul. Dessa combinacao resultam ate 512 possibilidades de cor.

A principal vantagem dessa abordagem esta na separacao entre o padrao grafico e a sua representacao de cor. Em vez de armazenar uma palavra completa de cor para cada pixel, a memoria de padroes armazena apenas o indice correspondente.

Isso reduz a quantidade de memoria necessaria para armazenar os recursos graficos e tambem permite que diferentes elementos compartilhem os mesmos padroes.

Outra vantagem e a possibilidade de modificar a aparencia de um recurso por meio da alteracao da paleta, sem que seja necessario modificar todos os pixels armazenados na memoria de padroes.

No contexto deste projeto, essa organizacao e utilizada tanto pelo motor de background quanto pelo motor de sprites, estabelecendo uma interface comum entre os padroes graficos armazenados e as cores efetivamente utilizadas na imagem final.


## 3.2 Background Baseado em Tiles

O background baseado em tiles e uma tecnica de construcao de imagens na qual um cenario e formado pela repeticao e combinacao de pequenos blocos graficos.

Em vez de armazenar cada pixel de um cenario completo de forma independente, o sistema armazena um conjunto de padroes de tiles e utiliza uma estrutura de referencias, denominada tilemap, para determinar qual padrao deve aparecer em cada posicao.

No projeto, cada tile possui dimensao:

8 x 8 pixels

Considerando a resolucao logica utilizada pelo sistema:

320 x 240 pixels

a tela pode ser dividida em:

320 / 8 = 40 tiles na horizontal

240 / 8 = 30 tiles na vertical

Portanto, uma tela logica completa e composta por:

40 x 30 = 1200 posicoes de tiles.

O tilemap armazena uma referencia para o padrao grafico que deve ser utilizado em cada uma dessas posicoes. Os padroes dos tiles, por sua vez, ficam armazenados em uma memoria especifica.

A determinacao de um pixel do background pode ser entendida como uma decomposicao da coordenada da tela.

Primeiramente, a coordenada do pixel e combinada com os valores de scroll. A coordenada resultante identifica a posicao correspondente no cenario.

Em seguida, essa coordenada e dividida conceitualmente em duas partes:

- Coordenada do tile: identifica qual entrada do tilemap deve ser acessada;
- Coordenada local: identifica qual pixel deve ser lido dentro do tile.

Como cada tile possui 8 x 8 pixels, existem 64 posicoes possiveis dentro de cada padrao.

O processo pode ser representado por:

    COORDENADA DO PIXEL
            |
            v
    +-------------------+
    |  SCROLL / OFFSET  |
    +-------------------+
            |
            v
    COORDENADA DO CENARIO
            |
            +----------------+
            |                |
            v                v
       TILEMAP          COORDENADA
                        LOCAL DO TILE
            |                |
            v                v
       PADRAO DO TILE ---> PIXEL
                             |
                             v
                            COR

A principal vantagem dessa tecnica e a reutilizacao dos padroes. Um mesmo tile pode aparecer diversas vezes no cenario sem que seja necessario armazenar varias copias de seus pixels.

Essa organizacao reduz o consumo de memoria e permite representar cenarios maiores e mais variados a partir de uma quantidade relativamente pequena de padroes graficos.


## 3.3 Scroll e Wraparound

O scroll e uma tecnica utilizada para produzir o deslocamento visual de um cenario. Em uma arquitetura baseada em tiles, esse deslocamento pode ser realizado alterando as coordenadas utilizadas para consultar o cenario, sem que seja necessario mover fisicamente os dados armazenados no tilemap.

No projeto, sao utilizados deslocamentos nos eixos horizontal e vertical, permitindo modificar a regiao do cenario que esta sendo apresentada na tela.

De forma conceitual:

    COORDENADA DA TELA
            +
    OFFSET DE SCROLL
            |
            v
    COORDENADA DO CENARIO
            |
            v
    CONSULTA AO TILEMAP

Assim, quando o valor de scroll e alterado, uma mesma posicao da tela pode passar a representar outra regiao do cenario.

Essa estrategia evita a necessidade de deslocar fisicamente os dados armazenados na memoria. O tilemap e os padroes graficos permanecem em suas respectivas memorias, enquanto a coordenada utilizada durante a consulta e modificada de acordo com o deslocamento desejado.

O wraparound complementa esse mecanismo ao permitir que o deslocamento seja tratado de forma ciclica. Quando uma coordenada utilizada para acessar o cenario ultrapassa os limites definidos, ela pode retornar ao inicio da regiao correspondente.

Esse comportamento pode ser representado de forma simplificada por:

    +-----------------------------+
    |          CENARIO            |
    |                             |
    |  INICIO ------------ FIM    |
    |    ^                 |      |
    |    |_________________|      |
    |         WRAPAROUND          |
    +-----------------------------+

Dessa maneira, o final do cenario pode ser conectado ao seu inicio, permitindo que o deslocamento continue sem a necessidade de interromper o movimento ou reconstruir o tilemap.

A combinacao entre scroll e wraparound permite produzir movimento continuo do background, mantendo os dados graficos armazenados de forma organizada e evitando operacoes desnecessarias de movimentacao da imagem.


## 3.4 Sprites

Sprites sao elementos graficos independentes do background, utilizados para representar objetos que possuem posicao e atributos proprios dentro da cena.

Enquanto o background e organizado a partir de uma estrutura de tiles, os sprites sao armazenados e processados individualmente pelo motor de sprites. Cada sprite possui uma entrada de atributos armazenada em uma memoria dedicada.

No projeto, cada entrada da memoria de atributos possui:

32 bits

A memoria de atributos utiliza um endereco de 5 bits, permitindo armazenar:

2^5 = 32 entradas de sprites.

A interface utilizada pelo sistema pode ser representada por:

    +--------------------------+
    | MEMORIA DE ATRIBUTOS     |
    |                          |
    | 32 entradas              |
    | 32 bits por entrada     |
    +--------------------------+
                |
                v
         ATRIBUTOS DO SPRITE
                |
                v
          MOTOR DE SPRITES

A palavra de atributos de 32 bits e utilizada para armazenar as informacoes necessarias para configurar cada sprite. Essas informacoes sao produzidas pelos modulos de controle de sprites e posteriormente armazenadas na memoria de atributos.

O sistema possui, por exemplo, modulos responsaveis pelo controle de movimento e espelhamento de um sprite e pela criacao de novos sprites. Esses modulos geram os dados de atributos que sao escritos na memoria dedicada. :contentReference[oaicite:0]{index=0}

Durante a renderizacao, o motor de sprites realiza a leitura dessas entradas por meio do endereco do atributo e utiliza os dados obtidos juntamente com a memoria de padroes e a paleta de cores para determinar os pixels que devem ser escritos no framebuffer. A interface do motor recebe a palavra de atributos de 32 bits, o padrao grafico e os dados da paleta. :contentReference[oaicite:1]{index=1} :contentReference[oaicite:2]{index=2}

Os padroes graficos dos sprites sao armazenados separadamente da memoria de atributos. Cada dado lido da memoria de padroes possui 8 bits, correspondendo ao indice de cor utilizado pelo pixel do padrao.

Essa separacao entre atributos, padroes graficos e paleta permite organizar o processamento dos sprites em diferentes memorias e modulos especializados:

    ATRIBUTOS
        |
        v
    +--------------------+
    | MEMORIA DE         |
    | ATRIBUTOS          |
    +--------------------+
        |
        v
    MOTOR DE SPRITES
        |
        +--------------------+
        |                    |
        v                    v
    PADRAO GRAFICO        PALETA
        |                    |
        +---------+----------+
                  |
                  v
             PIXEL RGB
                  |
                  v
             FRAMEBUFFER

Dessa forma, o sprite pode ser entendido como a combinacao entre seus atributos de configuracao, seu padrao grafico e as cores definidas pela paleta. O motor de sprites utiliza essas informacoes para determinar como o objeto deve ser representado na imagem final.


## 3.5 Espelhamento

O espelhamento e uma tecnica utilizada para alterar a orientacao de um recurso grafico sem a necessidade de armazenar uma segunda versao do mesmo padrao.

No projeto sao utilizados dois tipos de espelhamento:

- Flip horizontal;
- Flip vertical.

O principio consiste em alterar a ordem das coordenadas locais utilizadas para acessar os pixels do padrao grafico.

Para um sprite de 16 x 16 pixels, no espelhamento horizontal a coordenada horizontal e acessada em ordem inversa. De forma conceitual:

COORDENADA ORIGINAL:

    0, 1, 2, 3, ..., 13, 14, 15

COORDENADA ESPELHADA:

    15, 14, 13, ..., 2, 1, 0

De maneira equivalente, o espelhamento vertical inverte a ordem das coordenadas no eixo vertical.

O processo pode ser representado por:

               SPRITE
                  |
          +-------+-------+
          |               |
          v               v
     FLIP HORIZONTAL   FLIP VERTICAL
          |               |
          v               v
     INVERTE X         INVERTE Y
          |               |
          +-------+-------+
                  |
                  v
          PADRAO GRAFICO
                  |
                  v
                PIXEL

Assim, o mesmo padrao armazenado na memoria pode ser apresentado em diferentes orientacoes.

Essa tecnica e importante principalmente pela reutilizacao dos recursos graficos. Em vez de armazenar diferentes imagens para cada orientacao de um objeto, o sistema pode utilizar o mesmo padrao e modificar a forma como seus pixels sao acessados.

No projeto, o controle dessas orientacoes esta associado ao processamento dos atributos dos sprites, permitindo que um mesmo recurso grafico possa ser apresentado com diferentes orientacoes durante a renderizacao.

Dessa forma, o espelhamento contribui para a economia de memoria e aumenta a reutilizacao dos padroes graficos armazenados.


## 3.6 Rasterizacao

Rasterizacao e o processo de transformar uma descricao geometrica em uma representacao discreta formada por pixels.

Uma primitiva geometrica pode ser descrita por coordenadas, vertices e relacoes entre pontos. Entretanto, a imagem armazenada no framebuffer e composta por uma quantidade finita de pixels.

A rasterizacao realiza justamente essa conversao entre a representacao geometrica e a representacao discreta da imagem.

No projeto sao implementadas duas primitivas geometricas:

- Retangulos preenchidos;
- Triangulos preenchidos.

Para os retangulos, o rasterizador utiliza as coordenadas fornecidas para determinar a regiao ocupada pela primitiva. A partir dos limites horizontais e verticais, os pixels pertencentes a essa regiao sao percorridos e enviados para o framebuffer.

O processo pode ser representado por:
    
    COORDENADAS DA PRIMITIVA
              |
              v
    +----------------------+
    | DETERMINACAO DOS     |
    | LIMITES DA REGIAO    |
    +----------------------+
              |
              v
    +----------------------+
    | PERCURSO DOS PIXELS  |
    +----------------------+
              |
              v
          FRAMEBUFFER

No caso dos triangulos, a rasterizacao utiliza os tres vertices fornecidos para determinar a regiao ocupada pela primitiva.

O preenchimento pode ser realizado linha por linha, determinando para cada coordenada vertical o intervalo horizontal correspondente ao interior do triangulo.

De forma simplificada:

         /\
        /  \
       /    \
      /------\
     /        \
    /----------\

Cada linha possui um intervalo de pixels que pertence ao interior da primitiva. Esses pixels sao posteriormente utilizados para construir a imagem no framebuffer.

A implementacao em hardware utiliza operacoes aritmeticas adequadas a logica digital, incluindo representacoes inteiras e de ponto fixo. Essa abordagem permite realizar os calculos necessarios sem depender de operacoes de ponto flutuante.

Algumas operacoes aritmeticas utilizadas durante o processo podem ser realizadas por circuitos dedicados e distribuidas em diferentes ciclos de clock. Essa estrategia permite controlar o processamento por meio de maquinas de estados e adequar a rasterizacao ao funcionamento sequencial da FPGA.

De forma geral, o processo de rasterizacao pode ser resumido por:

    DESCRICAO GEOMETRICA
              |
              v
    +----------------------+
    | RASTERIZADOR         |
    |                      |
    | Retangulos           |
    | Triangulos           |
    +----------------------+
              |
              v
        PIXELS GERADOS
              |
              v
          COMPOSITOR
              |
              v
          FRAMEBUFFER

A rasterizacao constitui, portanto, uma das principais etapas responsaveis por transformar informacoes geometricas em pixels que posteriormente participarao da composicao da imagem final.


## 3.7 Double Buffering

O double buffering e uma tecnica utilizada para separar o buffer que esta sendo exibido daquele que esta sendo utilizado para construir o proximo quadro.

Quando um unico framebuffer e utilizado simultaneamente para leitura pelo controlador VGA e escrita pelos motores graficos, o conteudo da imagem pode ser modificado enquanto ainda esta sendo transmitido para o monitor.

Isso pode fazer com que diferentes partes da tela correspondam a estados diferentes da cena, produzindo artefatos visuais.

Para evitar esse problema, o sistema utiliza dois buffers:

    +------------------+
    |    BUFFER A      |
    |                  |
    |    EXIBICAO      |
    +------------------+

    +------------------+
    |    BUFFER B      |
    |                  |
    |   RENDERIZACAO   |
    +------------------+

Enquanto o controlador VGA realiza a leitura do Buffer A, os motores graficos podem construir o proximo quadro no Buffer B.

Quando o novo quadro esta pronto, os papeis dos buffers sao invertidos:

    BUFFER A -> RENDERIZACAO
    BUFFER B -> EXIBICAO

A troca dos buffers e sincronizada com o sinal de video e ocorre durante o periodo de vertical blanking, conhecido como VBlank.

O VBlank corresponde ao intervalo entre o final de um quadro e o inicio da apresentacao do proximo quadro. Realizar a troca nesse momento evita, ou reduz significativamente, a possibilidade de alterar o buffer utilizado para exibicao no meio da varredura da imagem.

Dessa forma, o double buffering cria uma separacao entre a etapa de renderizacao e a etapa de exibicao.

O mecanismo pode ser resumido como:

     RENDERIZACAO
         |
         v
    BUFFER DE ESCRITA
         |
         | quadro pronto
         v
       VBLANK
         |
         v
    TROCA DOS BUFFERS
         |
         v
    BUFFER DE EXIBICAO
         |
         v
        VGA


## 3.8 VGA

VGA (Video Graphics Array) e uma interface tradicional de video utilizada para transmitir uma imagem para um monitor por meio de sinais de sincronizacao e dados de cor.

No projeto, o controlador VGA representa a etapa final do processamento grafico. Ele realiza a leitura dos dados armazenados no framebuffer e gera os sinais necessarios para a apresentacao da imagem.

O clock principal utilizado pela plataforma e:

50 MHz

A partir desse sinal, um PLL gera um clock de aproximadamente:

25 MHz

utilizado pelo controlador VGA para realizar a varredura da imagem.

A saida fisica utilizada pelo projeto possui resolucao:

640 x 480 pixels

Entretanto, a representacao interna da imagem utiliza uma resolucao logica de:

320 x 240 pixels

Para compatibilizar essas duas resolucoes, cada pixel logico e representado por uma area de 2 x 2 pixels fisicos.

A relacao pode ser representada por:

    PIXEL LOGICO
    
    +-----+-----+
    |     |     |
    |  P  |  P  |
    +-----+-----+
    |     |     |
    |  P  |  P  |
    +-----+-----+

Cada pixel logico, portanto, corresponde a quatro pixels fisicos na saida VGA.

Considerando uma coordenada logica (x, y), a regiao correspondente na tela fisica possui aproximadamente o dobro das dimensoes:

(x, y) -> (2x, 2y)

Essa estrategia permite que os motores graficos trabalhem com uma quantidade menor de pixels, reduzindo a quantidade de memoria necessaria para o framebuffer e simplificando o processamento interno.

O controlador VGA realiza a varredura sequencial da imagem fisica e utiliza as coordenadas produzidas pelo contador de video para determinar qual regiao do framebuffer deve ser apresentada.

Assim, a etapa final do fluxo grafico pode ser resumida como:

    FRAMEBUFFER
         |
         v
    COORDENADA FISICA VGA
         |
         v
    MAPEAMENTO 640 x 480
         |
         v
    MAPEAMENTO 320 x 240
         |
         v
    DADOS DE COR
         |
         v
    MONITOR VGA

A saida VGA estabelece, portanto, a interface entre a imagem produzida pelos motores graficos e o dispositivo fisico de exibicao.



# 4. Arquitetura do Sistema

A arquitetura do sistema gráfico foi organizada de forma modular, separando as etapas de armazenamento de dados, geração dos elementos gráficos, composição das camadas e apresentação do resultado por meio da interface VGA. O módulo `top_video.v` atua como elemento central de integração do subsistema de vídeo, conectando as memórias utilizadas pelos motores de renderização, o rasterizador, o compositor, o framebuffer e o controlador VGA. A comunicação com o restante do sistema ocorre por meio de interfaces destinadas à escrita de dados de background, padrões de sprites, atributos de sprites, paleta de cores, parâmetros de scroll e comandos de rasterização. Dessa forma, o `top_video` concentra a infraestrutura necessária para que os diferentes elementos gráficos possam ser processados e armazenados antes de serem apresentados no monitor.

Internamente, o sistema trabalha com uma resolução lógica de 320×240 pixels, enquanto a saída VGA utiliza resolução de 640×480 pixels. Essa diferença é tratada pelo controlador VGA, que fornece as coordenadas do pixel físico e permite que o framebuffer seja acessado utilizando as coordenadas lógicas obtidas por meio dos deslocamentos de um bit das coordenadas VGA. Assim, `fb_rd_x` é obtido a partir de `next_x[9:1]` e `fb_rd_y` a partir de `next_y[9:1]`, fazendo com que cada pixel lógico corresponda a uma região de 2×2 pixels na saída VGA.

A geração do clock utilizado pelo subsistema VGA também está integrada ao `top_video`. O clock principal de 50 MHz é fornecido ao PLL `pll01`, que gera o clock de pixel de 25 MHz utilizado pelo controlador VGA. O sinal `pll_locked` é utilizado para garantir que o controlador VGA somente opere normalmente após o PLL estar estabilizado.

A organização da arquitetura pode ser representada pelo seguinte fluxo:

```text
                                  frame_start
                                       |
                                       v
                              +----------------+
                              |   COMPOSITOR   |
                              |                |
                              | FSM de         |
                              | composição     |
                              +-------+--------+
                                      |
                       controla      |      controla
                      start/done     |      arbitragem
                                      |
                +---------------------+---------------------+
                |                     |                     |
                v                     v                     v
         +-------------+       +-------------+       +-------------+
         |  Background |       |Rasterizador |       |   Sprites   |
         |    Motor    |       |             |       |    Motor    |
         +------+------+       +------+------+       +------+------+
                |                     |                     |
                +---------------------+---------------------+
                                      |
                               requisições de
                             palette / framebuffer
                                      |
                                      v
                              +---------------+
                              |   COMPOSITOR  |
                              |   Arbitragem   |
                              +-------+-------+
                                      |
                                      v
                              +---------------+
                              |   Framebuffer |
                              | Double Buffer |
                              +-------+-------+
                                      |
                                      v
                                 VGA Driver
                                      |
                                      v
                                     VGA
```

O processo de composição é controlado pelo módulo `compositor.v`, que determina a ordem de execução dos três motores gráficos. Ao receber `frame_start`, o compositor inicia inicialmente o motor de background. Após a conclusão dessa etapa, inicia o processamento da camada de polígonos e, posteriormente, o motor de sprites. Dessa maneira, os elementos são incorporados ao framebuffer de forma sequencial, estabelecendo uma ordem de sobreposição determinística. No `top_video`, essa sequência é explicitamente conectada aos sinais `bg_start`, `poly_start` e `spr_start`, enquanto os sinais de conclusão dos respectivos motores são utilizados pelo compositor para determinar as transições entre as etapas.

A arquitetura utiliza ainda recursos de memória compartilhados entre os diferentes motores. A palette RAM possui uma única interface física de leitura conectada ao compositor. Cada motor fornece seu próprio endereço de leitura, e o compositor seleciona o endereço correspondente ao motor que está em execução. Como os motores são ativados sequencialmente, não há necessidade de realizar arbitração complexa entre requisições simultâneas. O mesmo princípio é aplicado à porta de escrita do framebuffer, permitindo que background, polígonos e sprites utilizem uma única interface física de escrita.

Essa organização reduz a quantidade de interfaces físicas necessárias e mantém a responsabilidade de gerenciamento dos recursos compartilhados concentrada em um único módulo. O compositor, portanto, exerce duas funções complementares: controlar a sequência de composição e realizar a seleção das requisições de memória provenientes dos motores ativos.

## 4.1 Fluxo de Composição

A construção de cada frame ocorre em etapas sequenciais controladas por uma máquina de estados finitos implementada no `compositor.v`. O módulo possui os estados `S_IDLE`, `S_BG`, `S_POLY`, `S_SPR` e `S_DONE`, correspondentes, respectivamente, à espera de uma solicitação de composição, processamento do background, processamento dos polígonos, processamento dos sprites e finalização do frame. O sinal `busy` permanece ativo enquanto o compositor não está no estado `S_IDLE`, permitindo que o restante do sistema identifique quando uma composição está em andamento.

Quando `start` é acionado no estado `S_IDLE`, o compositor gera um pulso em `bg_start` e passa para o estado `S_BG`. O motor de background passa então a gerar as escritas correspondentes ao plano de fundo. A conclusão dessa etapa é indicada por `bg_done`. Quando esse sinal é detectado, o compositor gera `poly_start` e passa para `S_POLY`, iniciando o processamento da camada de polígonos.

A etapa de polígonos possui uma característica específica: sua conclusão é indicada pelo sinal `poly_layer_done`, e não simplesmente pelo sinal geral `rast_done`. Isso permite que o controle da composição utilize uma indicação específica de término da camada de polígonos. Após essa indicação, o compositor gera `spr_start` e passa para o estado `S_SPR`, permitindo que os sprites sejam desenhados sobre o conteúdo previamente produzido pelas etapas anteriores. O processamento de sprites termina quando `spr_done` é acionado. Em seguida, o compositor entra em `S_DONE`, produzindo `done` e retornando posteriormente ao estado de espera.

A ordem de composição estabelecida é, portanto:

```text
Background
     ↓
Polígonos
     ↓
Sprites
```

Essa ordem possui uma consequência importante sobre a construção da imagem. Como cada etapa escreve sobre o framebuffer utilizado para a renderização, os elementos processados posteriormente podem substituir pixels previamente escritos. O background constitui a base da imagem, os polígonos são adicionados posteriormente e os sprites são processados por último. No caso dos sprites, pixels transparentes não geram escritas no framebuffer, permitindo preservar o conteúdo produzido pelas camadas anteriores.

O compositor também garante que as requisições de memória sejam associadas à etapa correta da composição. Para a palette RAM, o endereço de leitura é selecionado de acordo com o motor que está ocupado. Para o framebuffer, os sinais `fb_we`, `fb_wr_x`, `fb_wr_y` e `fb_wr_data` são selecionados da mesma maneira. Como a sequência de composição impede que os motores sejam executados simultaneamente dentro do fluxo normal, essa estrutura funciona como uma arbitração simples baseada no estado atual da composição.

O resultado dessa estratégia é uma arquitetura em que os motores de renderização não precisam disputar diretamente os recursos compartilhados. Cada motor possui suas próprias interfaces lógicas para palette e framebuffer, enquanto o compositor converte essas interfaces em uma única interface física para cada recurso. Essa separação simplifica a implementação e torna explícita a ordem de composição.

Depois que o compositor termina, o frame ainda não é imediatamente apresentado pelo VGA. O `top_video` mantém uma separação entre o término da renderização e o momento de troca dos buffers. O sinal `compositor_done` é utilizado para indicar que o frame foi completamente produzido, enquanto o sinal `vblank_event`, derivado do `vblank_tick` gerado pelo controlador VGA, indica um período seguro para modificar o banco que está sendo exibido.

Essa separação permite que a renderização seja concluída antes do período de atualização da imagem. Quando o compositor termina, o `top_video` registra essa condição por meio de `frame_render_done`. Quando posteriormente ocorre um evento de VBlank com `frame_render_done` ativo, os bancos de leitura e escrita são trocados. O banco que estava sendo utilizado para renderização passa a ser exibido, enquanto o banco anteriormente exibido passa a receber o próximo frame. Depois da troca, `frame_done` é acionado para indicar que um novo frame foi efetivamente apresentado.

Esse mecanismo caracteriza a utilização de **double buffering**. Inicialmente, `rd_buf_sel` é configurado para o banco 0 e `wr_buf_sel` para o banco 1. Assim, o VGA pode continuar lendo um frame enquanto o outro banco é atualizado pelos motores de renderização. A troca somente ocorre durante o VBlank, reduzindo o risco de que o VGA leia simultaneamente uma imagem que ainda esteja sendo modificada.

## 4.2 Principais Módulos

O módulo `DE1_SOC_golden_top.v` constitui o nível superior da aplicação na placa DE1-SoC, realizando a conexão entre os recursos externos da placa e o subsistema de vídeo. A partir desse nível são fornecidos sinais de clock, reset e controles utilizados pela demonstração, além das interfaces necessárias para comandar os elementos gráficos. O `top_video.v` é instanciado nesse nível e concentra a implementação específica do sistema gráfico.

O `top_video.v` é responsável pela integração dos principais componentes da arquitetura. Além das interfaces de saída VGA, ele possui entradas para escrita nas memórias de background, sprites e palette, parâmetros de scroll e comandos destinados ao rasterizador. Também recebe `frame_start` para iniciar uma nova composição e fornece sinais relacionados ao estado do rasterizador e à fase de processamento dos polígonos.

O `motor_background.v` é responsável pela geração da camada de fundo. Ele utiliza a memória de tilemap, a memória de padrões dos tiles e a palette para determinar a cor de cada pixel do background. O `top_video` conecta o motor às memórias `bg_tile_ram` e `bg_tile_pattern_ram`, além de disponibilizar os sinais de controle de scroll horizontal e vertical.

A organização do background é baseada na separação entre os dados que identificam os tiles e os dados que representam seus padrões gráficos. A `bg_tile_ram` armazena os identificadores dos tiles utilizados pelo mapa, enquanto a `bg_tile_pattern_ram` fornece os dados dos pixels associados aos padrões. O motor utiliza essas informações para produzir os pixels da camada de fundo e enviá-los para o framebuffer.

O sistema de background também possui mecanismos de controle de scroll. O `top_video` fornece ao motor sinais para escrita explícita dos parâmetros de scroll e sinais associados ao modo de scroll automático, incluindo eixo, direção e passo.

O subsistema de sprites é dividido entre armazenamento dos atributos, armazenamento dos padrões e processamento propriamente dito. A `sprite_attribute_ram` armazena os atributos dos sprites, enquanto a `sprite_pattern_ram` armazena seus padrões gráficos. O `motor_sprite.v` utiliza essas informações para produzir os pixels dos sprites, realizando as consultas necessárias à palette e gerando as escritas no framebuffer.

Essa divisão permite separar os dados estáticos ou configuráveis dos sprites do mecanismo responsável pela renderização. Os atributos podem ser fornecidos externamente ao subsistema por meio das interfaces de escrita presentes no `top_video`, enquanto o motor realiza as leituras durante a composição.

O `rasterizador_top.v` funciona como interface superior do rasterizador. O `top_video` fornece ao módulo os comandos para iniciar a rasterização de quadrados ou triângulos, as coordenadas dos vértices, o índice de cor e a seleção da palette. O rasterizador fornece, por sua vez, sinais de `busy`, `done` e `invalid_cmd`, além das interfaces de leitura da palette e escrita no framebuffer.

O rasterizador é responsável pela geração dos pixels dos elementos geométricos. Para retângulos preenchidos, o processamento consiste em determinar os limites das coordenadas e gerar os pixels pertencentes à área definida. Para triângulos preenchidos, o algoritmo utiliza a abordagem de varredura por linhas, determinando os limites horizontais de cada linha do triângulo e produzindo os pixels correspondentes. A interface superior permite que ambos os tipos de primitivas compartilhem a infraestrutura de palette e framebuffer utilizada pelos demais motores.

A `palette_ram` constitui a memória compartilhada responsável por armazenar as cores utilizadas durante a composição. O `top_video` fornece a interface de escrita para atualização da palette e conecta sua porta de leitura ao compositor. Durante a execução de um motor, seu endereço de palette é encaminhado pelo compositor para a memória, e o dado retornado é disponibilizado ao motor correspondente.

O `framebuffer.v` constitui o estágio de armazenamento dos pixels produzidos durante a composição. O módulo recebe uma única interface de escrita proveniente do compositor, juntamente com o banco selecionado por `wr_buf_sel`, e possui uma interface de leitura associada ao domínio de clock do VGA. Dessa maneira, o framebuffer atua como uma fronteira entre a etapa de renderização e a etapa de apresentação.

A seleção dos bancos é controlada diretamente pelo `top_video`. O sinal `rd_buf_sel` identifica o banco atualmente utilizado pelo VGA, enquanto `wr_buf_sel` identifica o banco que recebe as escritas durante a renderização. Após a conclusão de um frame e a ocorrência do VBlank, esses sinais são trocados, fazendo com que o frame recém-renderizado passe a ser apresentado.

O `vga_driver.v` é responsável pela geração dos sinais de temporização da interface VGA e pelo fornecimento das coordenadas do pixel que está sendo apresentado. O módulo recebe `fb_color_out` como entrada de cor e gera os sinais `hsync`, `vsync`, `red`, `green`, `blue`, `sync`, `clk` e `blank`. Também produz o sinal `vblank_tick`, utilizado pelo `top_video` para sincronizar a troca dos bancos do framebuffer com o período de apagamento vertical.

Por fim, o `fb_addr_gen.v` é responsável pela transformação das coordenadas bidimensionais do framebuffer em um endereço linear de memória. Considerando a resolução lógica de 320×240 pixels, o endereço é obtido pela relação `address = y × 320 + x`. Essa transformação permite que os pixels sejam armazenados de forma sequencial na memória, mantendo uma representação linear da imagem bidimensional.

A arquitetura resultante separa claramente as responsabilidades entre **geração dos elementos gráficos, armazenamento, composição e apresentação**. Os motores produzem os pixels de suas respectivas camadas, o compositor controla a ordem de execução e arbitra os recursos compartilhados, o framebuffer mantém os frames em buffers separados e o controlador VGA realiza a apresentação do conteúdo armazenado. Essa organização permite que novos motores ou primitivas gráficas sejam incorporados posteriormente sem modificar diretamente a lógica responsável pela saída VGA, mantendo a estrutura modular do subsistema gráfico.

### 4.3 Memórias do Sistema

O projeto utiliza **seis memórias principais**, todas implementadas como RAMs de porta dupla simples (*simple dual-port RAM*), geradas por meio do **IP Catalog do Quartus** utilizando a megafunction `altsyncram`. Nesse modo de operação, a **porta A é utilizada exclusivamente para escrita**, enquanto a **porta B é utilizada exclusivamente para leitura**.

Cinco das memórias utilizam um único domínio de clock, compartilhado pela CPU e pelos motores gráficos. A exceção é o **framebuffer**, que utiliza dois domínios de clock, pois sua escrita ocorre no clock de sistema de 50 MHz, enquanto sua leitura ocorre no domínio do *pixel clock* de 25 MHz utilizado pelo controlador VGA.

A organização das memórias é apresentada a seguir.

#### 4.3.1 `bg_tile_ram` — 1200 × 8 bits

A memória `bg_tile_ram` armazena o **tilemap do background**. A tela lógica possui resolução de 320×240 pixels e é dividida em tiles de 8×8 pixels, resultando em uma organização de 40×30 tiles, ou seja, **1200 posições de memória**.

Cada posição armazena um `pattern_id` de 8 bits, permitindo selecionar um dos **256 padrões gráficos disponíveis**. Essa memória não armazena diretamente a cor dos pixels, mas apenas indica qual padrão deve ser utilizado em cada posição do tilemap.

Como o tilemap possui exatamente 40×30 tiles, correspondendo à área total da tela lógica, o deslocamento (*scroll*) do background é realizado por **enrolamento (*wraparound*)**. Dessa forma, quando uma região deixa a tela por uma das bordas, ela pode reaparecer pela borda oposta.

#### 4.3.2 `bg_tile_pattern_ram` — 16384 × 8 bits

A `bg_tile_pattern_ram` armazena os **padrões gráficos utilizados pelo background**. Sua capacidade de 16384 posições corresponde a:

**256 padrões × 64 pixels por padrão = 16384 posições.**

Cada padrão possui dimensões de 8×8 pixels. Para cada pixel é armazenado um **índice de cor de 8 bits**, em vez da cor RGB diretamente.

Assim, existe uma separação entre a seleção do padrão e a definição da cor:

* `bg_tile_ram` determina **qual padrão** deve ser utilizado;
* `bg_tile_pattern_ram` determina **qual índice de cor** cada pixel desse padrão possui;
* `palette_ram` converte o índice de cor na representação RGB utilizada pelo framebuffer.

#### 4.3.3 `sprite_attribute_ram` — 32 × 32 bits

A `sprite_attribute_ram` armazena os atributos dos **32 sprites disponíveis** no sistema. Cada sprite possui uma entrada de 32 bits contendo todas as informações necessárias para sua composição.

| Campo           | Bits | Função                              |
| --------------- | ---: | ----------------------------------- |
| `enable`        |    1 | Habilita ou desabilita o sprite     |
| `priority`      |    5 | Define a prioridade de sobreposição |
| `flip_v`        |    1 | Espelhamento vertical               |
| `flip_h`        |    1 | Espelhamento horizontal             |
| `palette_sel`   |    1 | Seleciona uma das duas paletas      |
| `pattern_index` |    6 | Seleciona o padrão 16×16            |
| `pos_y`         |    8 | Posição vertical                    |
| `pos_x`         |    9 | Posição horizontal                  |

A memória funciona, portanto, como uma tabela de atributos, permitindo que o motor de sprites obtenha as informações necessárias para determinar **onde**, **como** e **com qual padrão** cada sprite deve ser desenhado.

#### 4.3.4 `sprite_pattern_ram` — 16384 × 8 bits

A `sprite_pattern_ram` armazena os padrões gráficos utilizados pelos sprites. Assim como no background, os padrões são organizados em tiles de **8×8 pixels**.

Sua capacidade permite armazenar **256 tiles**, totalizando:

**256 tiles × 64 pixels = 16384 posições.**

Esses tiles são utilizados para formar os padrões de sprites de 16×16 pixels. Dessa forma, cada sprite pode ser composto por quatro tiles de 8×8 pixels.

Cada posição armazena um índice de cor de 8 bits. Nesse caso, o **índice 0 é reservado para transparência**. Quando o motor de sprites encontra esse índice, o pixel não é escrito no framebuffer, permitindo que o conteúdo das camadas inferiores permaneça visível.

#### 4.3.5 `palette_ram` — 512 × 9 bits

A `palette_ram` armazena as cores utilizadas pelo sistema gráfico. Ela possui **512 entradas de 9 bits**, organizadas como duas paletas independentes de 256 cores.

O endereço da memória é formado pela concatenação de `palette_sel` com `color_index`:

```text
{palette_sel, color_index}
```

Dessa forma, o bit `palette_sel` seleciona uma das duas paletas, enquanto os oito bits restantes selecionam uma das 256 cores daquela paleta.

Cada entrada armazena diretamente a cor no formato RGB de 9 bits:

```text
RRR GGG BBB
```

O índice 0 de cada paleta é reservado como marcador associado à transparência. Durante a depuração, esse índice recebe a cor magenta, permitindo identificar visualmente situações em que um pixel transparente tenha sido tratado incorretamente como uma cor válida.

#### 4.3.6 `framebuffer_ram` — 2 bancos de 76800 × 9 bits

O `framebuffer_ram` armazena o resultado final da composição gráfica. Cada posição contém diretamente uma cor RGB de **9 bits**, não sendo necessário realizar uma nova consulta à paleta durante a leitura para o vídeo.

Cada banco possui:

**320 × 240 = 76800 pixels**

e cada pixel utiliza 9 bits.

O sistema utiliza **dois bancos de framebuffer**, implementando a técnica de **double buffering**. Enquanto um banco é utilizado pelos motores gráficos para construir o próximo frame, o outro é utilizado pelo controlador VGA para exibir o frame atualmente pronto.

Ao final da composição, a troca entre os bancos ocorre durante o período de **VBlank**, evitando que a mudança aconteça no meio da atualização da imagem e reduzindo o risco de *tearing*.

O framebuffer é também a única memória do projeto que opera em **dois domínios de clock**:

* **50 MHz:** escrita realizada pelos motores gráficos;
* **25 MHz:** leitura realizada pelo controlador de vídeo VGA.

### 4.4 Organização do Armazenamento

As seis memórias possuem funções distintas dentro do pipeline gráfico:

```text
                 BACKGROUND
                     │
          ┌──────────┴──────────┐
          │                     │
   bg_tile_ram        bg_tile_pattern_ram
   tilemap             pixels do tile
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
                 índice de cor
                     │
                     ▼
              ┌─────────────┐
              │ palette_ram │
              └──────┬──────┘
                     │
                     ▼
               cor RGB (9 bits)


                  SPRITES
                     │
          ┌──────────┴──────────┐
          │                     │
 sprite_attribute_ram   sprite_pattern_ram
  atributos             pixels dos padrões
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
                 índice de cor
                     │
                     ▼
              ┌─────────────┐
              │ palette_ram │
              └──────┬──────┘
                     │
                     ▼
               cor RGB (9 bits)


       BACKGROUND ─┐
       POLÍGONOS  ─┼──► COMPOSITOR ───► FRAMEBUFFER
       SPRITES    ─┘                         │
                                             │
                                  ┌──────────┴──────────┐
                                  │                     │
                              Banco 0               Banco 1
                                  │                     │
                                  └──── Double Buffer ──┘
                                             │
                                             ▼
                                        Controlador
                                           VGA
```

Essa organização mantém separadas as informações de **descrição da cena**, **dados gráficos**, **cores** e **imagem final**, permitindo que cada motor gráfico acesse somente as memórias necessárias para executar sua função. O `framebuffer_ram` funciona como ponto de convergência das diferentes camadas, armazenando o resultado produzido pelo compositor antes de sua leitura pelo sistema de vídeo.


# 5. ESPECIFICACAO DE HARDWARE E SOFTWARE

Esta secao apresenta os principais recursos de hardware, software e arquivos de inicializacao utilizados no desenvolvimento e na execucao do sistema grafico implementado em FPGA.

## 5.1 Hardware

A plataforma utilizada no projeto e a Terasic DE1-SoC, equipada com um dispositivo Intel/Altera Cyclone V SoC. A FPGA concentra a implementacao dos modulos responsaveis pelo processamento grafico, controle e armazenamento dos dados utilizados durante a geracao da imagem.

As principais especificacoes de hardware utilizadas sao:

- Plataforma: Terasic DE1-SoC
- FPGA: Intel/Altera Cyclone V SoC
- Dispositivo utilizado na sintese: `5CSEMA5F31C6`
- Clock principal: 50 MHz
- Clock VGA: aproximadamente 25 MHz
- Saida de video: VGA
- Resolucao fisica: 640 x 480 pixels
- Resolucao logica: 320 x 240 pixels
- Controles de demonstracao: `KEY`, `SW` e sinais da placa

A imagem e processada internamente na resolucao logica de 320 x 240 pixels. Para a exibicao em VGA, essa imagem e apresentada na resolucao fisica de 640 x 480 pixels, com cada pixel logico correspondendo a um bloco de 2 x 2 pixels fisicos.

De forma simplificada, o fluxo de processamento implementado em hardware pode ser representado por:

```text
PARAMETROS DA CENA
        |
        v
+---------------------+
| MOTORES GRAFICOS    |
|                     |
| Background          |
| Poligonos           |
| Sprites             |
+----------+----------+
           |
           v
+---------------------+
| COMPOSITOR          |
+----------+----------+
           |
           v
+---------------------+
| FRAMEBUFFER         |
+----------+----------+
           |
           v
+---------------------+
| DOUBLE BUFFERING    |
+----------+----------+
           |
           v
+---------------------+
| CONTROLADOR VGA     |
+----------+----------+
           |
           v
        MONITOR
```

## 5.2 Software

O desenvolvimento do projeto utiliza ferramentas destinadas a compilacao, sintese e simulacao dos circuitos implementados em HDL.

Os relatorios presentes no projeto indicam a utilizacao do:

- Intel Quartus Prime Lite Edition 20.1.1

O repositorio tambem contem arquivos e scripts relacionados ao fluxo de simulacao ModelSim/Questa, utilizados durante o desenvolvimento do sistema.

Tambem estao presentes arquivos `.qip` relacionados a componentes e memorias gerados como IPs. Alguns desses arquivos apresentam metadados associados a diferentes versoes do Quartus. Dessa forma, ao reconstruir o projeto em outra instalacao ou versao da ferramenta, determinados IPs podem exigir regeneracao ou atualizacao.

## 5.3 Arquivos de Inicializacao

O projeto utiliza arquivos no formato `.mif` (Memory Initialization File) para inicializar as memorias que armazenam dados utilizados pelos recursos graficos.

Entre os principais arquivos de inicializacao presentes no projeto estao:

- `bg_tile_pattern_praia.mif`
- `bg_tile_ram.mif`
- `palette_default.mif`
- `sprite_attribute_ram.mif`
- `sprite_pattern_ram_pikachu_charmander.mif`

Esses arquivos estao associados aos diferentes recursos utilizados pelo sistema:

- `bg_tile_pattern_praia.mif`: padroes graficos dos tiles utilizados pelo background.
- `bg_tile_ram.mif`: dados referentes a organizacao do mapa de tiles.
- `palette_default.mif`: dados iniciais utilizados pela paleta de cores.
- `sprite_attribute_ram.mif`: atributos iniciais dos sprites.
- `sprite_pattern_ram_pikachu_charmander.mif`: padroes graficos utilizados pelos sprites.

A organizacao das memorias acompanha a propria arquitetura grafica do projeto. O motor de background acessa as memorias de tile, padrao grafico e paleta para gerar os pixels do cenario, enquanto o motor de sprites utiliza as memorias de atributos e padroes dos sprites. Esses elementos sao posteriormente encaminhados ao compositor e ao framebuffer.

Assim, os arquivos de inicializacao constituem os dados graficos utilizados pelas memorias do sistema, enquanto os modulos HDL implementam a logica responsavel pelo processamento desses dados e pela construcao da imagem.

De forma simplificada:

```text
+-----------------------------+
|       ARQUIVOS .MIF         |
|                             |
| Background | Paleta | Sprite|
+-------------+---------------+
              |
              v
+-----------------------------+
|          MEMORIAS           |
|                             |
| Tilemap | Patterns | Atrib. |
+-------------+---------------+
              |
              v
+-----------------------------+
|       MOTORES GRAFICOS      |
+-------------+---------------+
              |
              v
+-----------------------------+
|          COMPOSITOR         |
+-------------+---------------+
              |
              v
          FRAMEBUFFER
```


# 6. Processo de Desenvolvimento

O processo de projeto e implementação do co-processador gráfico seguiu uma abordagem ascendente (*bottom-up*), iniciando nos módulos de menor nível (sinalização física de vídeo) até a composição final do pipeline gráfico e integração no *top-level* da FPGA DE1-SoC.

---

## 6.1 Sistema VGA e Escalonamento Espacial

A primeira etapa do desenvolvimento concentrou-se no estabelecimento da sinalização física e no gerenciamento das frequências de *clock*:

* **Geração do Pixel Clock ($25.175\text{ MHz}$):** Utilização da PLL nativa da Cyclone V para derivar a frequência de amostragem do sinal VGA a partir do clock principal da placa ($50\text{ MHz}$).
* **Sincronismo Vertical e Horizontal ($640 \times 480 @ 60\text{Hz}$):** Implementação dos contadores de tempo para geração dos pulsos de sincronismo horizontal (`H-Sync`) e vertical (`V-Sync`), respeitando as janelas de *Front Porch*, *Back Porch* e área visível.
* **Mapeamento e Pixel Scaling ($2 \times 2$):** Implementação do gerador de coordenadas onde cada pixel lógico ($320 \times 240$) é expandido para $2 \times 2$ pixels físicos no sinal VGA final por meio de divisão inteira (deslocamento de bit) dos contadores de varredura.
* **Gerador de Endereço de Leitura:** Módulo responsável por converter as coordenadas lógicas correntes $(X_{log}, Y_{log})$ no endereço linear correspondente da memória de vídeo:
  $$\text{Endereço} = Y_{log} \times 320 + X_{log}$$

---

## 6.2 Framebuffer e Sincronismo de Exibição

Com a sinalização de vídeo validada, o armazenamento estático das imagens foi integrado para dar suporte à renderização contínua:

* **Arquitetura de Memória M10K:** Alocação de dois bancos idênticos de memória RAM interna (*Front Buffer* e *Back Buffer*), permitindo que a escrita de novos quadros pelo rasterizador ocorra de forma independente da leitura contínua feita pelo controlador VGA.
* **Mecanismo de Double Buffering:** Separação do acesso à memória em dois ponteiros distintos (Ponteiro de Exibição e Ponteiro de Desenho), eliminando o efeito de *screen tearing* (rasgo de tela).
* **Sincronização em VBlank:** A alternância entre os bancos (*Buffer Swap*) foi travada para ocorrer exclusivamente no intervalo de supressão vertical (`VBlank`). Quando um comando de troca é recebido, a troca do ponteiro aguarda o início do ciclo de sincronismo vertical seguinte antes de se tornar efetiva.

---

## 6.3 Engine de Background (Tilemap e Scrolling)

A construção da camada de plano de fundo seguiu a arquitetura tradicional de consoles de 16 bits:

* **Mapeamento de Coordenadas:** Divisão da tela em uma grade de $40 \times 30$ posições de tiles ($8 \times 8$ pixels). Para cada pixel lógico, o sistema calcula a posição do tile no mapa e o deslocamento local dentro da matriz $8 \times 8$:
  $$\text{Tile}_{X} = X \gg 3, \quad \text{Tile}_{Y} = Y \gg 3$$
  $$\text{Pixel Local}_{X} = X \ \& \ 7, \quad \text{Pixel Local}_{Y} = Y \ \& \ 7$$
* **Lógica de Scroll e Wraparound:** Aplicação de *offsets* de registradores $(Scroll_X, Scroll_Y)$ somados às coordenadas de varredura antes do cálculo de endereço, permitindo movimentação contínua da cena com aritmética modular para garantir a repetição das bordas (*wraparound*).
* **Pipeline de Leitura:** Integração da leitura em dois estágios: busca do índice do tile no **Tilemap** seguida do acesso à **Pattern RAM** para obter o índice de cor final de 8 bits.
* **Inicialização por Arquivos `.mif`:** Utilização de arquivos *Memory Initialization File* para pré-carregar cenários gráficos de teste nas memórias internas durante a síntese na FPGA.

---

## 6.4 Engine de Sprites e Matriz de Atributos (OAM)

Desenvolvimento do subsistema de objetos móveis e gerenciamento dinâmico de sobreposição:

* **Memória OAM (Object Attribute Memory):** Registro interno estruturado para armazenar as propriedades de até 32 sprites em palavras de 32 bits.
* **Estágios do Pipeline de Sprites:**
  1. **Busca de Atributos (*Attribute Fetch*):** Avaliação dinâmica dos 32 registradores para verificar a intersecção do sprite com a varredura atual.
  2. **Seleção de Quadrante:** Resolução da imagem de $16 \times 16$ pixels a partir de 4 sub-tiles de $8 \times 8$ da memória de padrões.
  3. **Transformações Métricas:** Aplicação de lógica de inversão dos índices de varredura interna para suporte a espelhamento horizontal (*H-Flip*) e vertical (*V-Flip*).
* **Arbitragem e Transparência:** Tratamento do índice de cor `0x00` como nulo/transparente e avaliação das regras de prioridade entre sprites que ocupam o mesmo pixel na tela.
* **Módulos de Demonstração em Hardware:** Criação de geradores autonômicos de teste para movimentação em tempo real de objetos sem dependência de comandos externos.

---

## 6.5 Rasterizador de Polígonos

Desenvolvimento da unidade lógica e aritmética (ALU) voltada para o preenchimento de primitivas geométricas diretamente no *Back Buffer*:

* **Rasterizador de Retângulos:** Módulo de varredura por loops encadeados utilizando os parâmetros de origem $(X_0, Y_0)$, largura, altura e cor.
* **Rasterizador de Triângulos:** Unidade baseada na técnica de varredura por *scanlines*, utilizando interpolação linear dos vértices fornecidos.
* **Divisor Inteiro e Aritmética:** Implementação de divisor interno em hardware para o cálculo de inclinação das arestas sem utilização de operações em ponto flutuante.
* **Máquina de Estados e Proteção de Fronteira (*Clipping*):** Unidade de controle superior encarregada de coordenar a execução das primitivas e aplicar verificações de segurança que abortam a renderização de primitivas com coordenadas fora dos limites lógicos de $320 \times 240$.

---

## 6.6 Compositor de Vídeo e Paleta de Cores

Integração final dos motores gráficos em uma única cadeia de saída antes da conversão para o DAC da placa:

* **Mux de Camadas e Prioridade:** O compositor combina pixel a pixel a saída dos subsistemas respeitando a hierarquia rígida definida para o projeto:
  $$\mathbf{Background} \longrightarrow \mathbf{Polígonos} \longrightarrow \mathbf{Sprites}$$
* **Tratamento de Transparências:** Se a camada de maior prioridade produzir o índice de cor `0x00`, o compositor repassa o pixel válido da camada imediatamente inferior.
* **Mapeamento de Paleta (Color LUT):** Os índices de 8 bits resultantes da composição são passados pela Lookup Table de $256 \times 9\text{ bits}$, mapeando a informação para os canais físicos Red ($3\text{ bits}$), Green ($3\text{ bits}$) e Blue ($3\text{ bits}$).

---

## 6.7 Integração no Top-Level e Validação Física

Finalização da descrição em Verilog e teste direto na plataforma de prototipagem:

* **Interconexão de Módulos:** Conexão de todas as unidades internas ao módulo *top-level* do projeto no Quartus Prime.
* **Interface Hardware de Validação:** Mapeamento temporário de sinais de controle nas chaves (*SW*), botões (*KEY*) e LEDs da placa **DE1-SoC**, permitindo a alternância de *buffers*, scroll manual de background, disparo de comandos do rasterizador e controle de visibilidade de sprites diretamente no monitor VGA durante a apresentação do protótipo.



# 7. Instalação e Configuração

Esta seção descreve as ferramentas, os pré-requisitos e o procedimento passo a passo para compilação, simulação e programação do co-processador gráfico na placa **DE1-SoC**.

---

## 7.1 Pré-requisitos de Software e Hardware

Para reproduzir a síntese e os testes do sistema, são necessárias as seguintes ferramentas e componentes:

* **Software de Desenvolvimento:**
  * **Intel Quartus Prime (Lite ou Standard Edition)** — Versão 18.1 ou superior, contendo o pacote de suporte para a família **Cyclone V**.
  * **ModelSim / Questa Intel FPGA Edition** — Utilizado para execução dos testbenches unitários e de integração.
* **Hardware Requerido:**
  * **Placa de Desenvolvimento:** Terasic DE1-SoC.
  * **Dispositivo FPGA Altera/Intel:** `5CSEMA5F31C6`.
  * **Exibição:** Monitor CRT ou LCD com suporte à resolução VGA padrão ($640 \times 480 @ 60\text{Hz}$) e cabo VGA de 15 pinos.
  * **Interface de Gravação:** Cabo USB Type-A/Mini-B (conexão On-Board USB-Blaster II).

---

## 7.2 Estrutura do Repositório

O repositório do projeto está organizado conforme a estrutura abaixo:

```text
.
├── memory_files/       # Arquivos de inicialização de memória (.mif)
├── output_files/       # Arquivos de síntese, relatórios e binários (.sof)
├── tb/                 # Testbenches para simulação (ModelSim / Questa)
├── DE1_SOC_golden_top.v # Módulo Top-Level integrado com os pinos da placa
├── *.v                 # Arquivos fonte em Verilog HDL (Módulos RTL e IPs)
└── README.md           # Documentação técnica do projeto
```

---

# 8. Testes e Erros

Os testes do coprocessador foram realizados inicialmente por meio de testbenches desenvolvidos em Verilog, utilizando o ModelSim para simulação dos módulos individualmente. Os testes utilizaram memórias comportamentais como modelos das RAMs presentes no projeto, permitindo verificar os sinais de leitura, escrita no framebuffer, seleção de paletas e funcionamento dos motores de renderização.

A estratégia adotada foi validar inicialmente os módulos de forma isolada e, posteriormente, verificar o comportamento conjunto das diferentes camadas de renderização. Dessa forma, foi possível identificar erros de funcionamento antes da integração completa com o sistema de vídeo.

### 8.0.1 Simulação

Para executar os *testbenches* do projeto, é necessário primeiro **compilar o projeto** no Quartus. Em seguida, deve-se configurar a ferramenta de simulação em **Assignments → Settings**, selecionando o **ModelSim-Altera** como ferramenta de simulação.

Após essa configuração, o processo de execução de um *testbench* é:

1. Acesse **Tools → Run Simulation Tool → Compile**.
2. Selecione o arquivo do *testbench* que deseja testar.
3. Clique em **Compile** e, após a compilação, em **Done**.
4. Na página do ModelSim, localize a região **Library** e abra a biblioteca **work**.
5. Localize o *testbench* desejado e dê **duplo clique** sobre ele para iniciar a simulação.
6. Na janela da simulação, clique com o botão direito e selecione **Add → Wave** para adicionar os sinais à visualização de ondas.
7. No terminal do ModelSim, execute:

```text
run -all
```

Esse comando executa a simulação até que o *testbench* seja finalizado, permitindo analisar os sinais e verificar o comportamento do módulo testado. Todos os arquivos que correspondem a um *testbench* se iniciam com as letar *tb*.

## 8.1 Testes do Rasterizador de Quadrados

O rasterizador de quadrados foi testado considerando diferentes posições e dimensões dos retângulos, além de diferentes configurações de paleta.

O primeiro teste utilizou um quadrado pequeno entre as coordenadas `(10,10)` e `(15,15)`, verificando se todos os pixels da região eram preenchidos com a cor esperada. Também foi realizada uma verificação dos pixels imediatamente externos à região, garantindo que não houvesse escrita fora dos limites especificados.

Em seguida, foi testada a utilização dos vértices em ordem invertida. Nesse caso, as coordenadas foram fornecidas como `(50,40)` e `(45,35)`, verificando se o módulo realizava corretamente a normalização dos limites do quadrado.

Também foi considerado o caso extremo em que os dois vértices são iguais, formando um quadrado de apenas um pixel. Por fim, foi realizado um teste com uma região maior, próxima ao canto superior esquerdo da tela, e outro utilizando o mesmo índice de cor em uma segunda paleta.

Os testes verificaram tanto a quantidade de pixels escritos quanto a posição e a cor dos pixels armazenados no framebuffer de teste.

## 8.2 Testes do Motor de Background

O motor de background foi testado utilizando modelos comportamentais das memórias de tiles, padrões e paleta. O teste também avaliou o mecanismo de scroll automático.

Foi configurado um scroll horizontal, com deslocamento de um pixel por frame. Foram executados cinco frames consecutivos e, ao final de cada processamento, foram observados os valores de `scroll_x` e `frame_scroll_x`.

O objetivo foi verificar se o deslocamento era atualizado corretamente entre os frames e se o valor utilizado durante a renderização permanecia consistente com o frame em processamento.

Além do controle de scroll, as escritas realizadas pelo motor no framebuffer foram monitoradas durante a simulação para confirmar que o background estava efetivamente produzindo pixels.

## 8.3 Teste de Transparência das Sprites

O teste de transparência verificou o comportamento do motor de sprites quando o índice de cor armazenado no pattern representa um pixel transparente.

Foi configurada uma sprite de 16×16 pixels na posição `(50,50)`, com todos os pixels do pattern configurados com índice de cor `0`. O resultado esperado era que nenhum desses pixels produzisse uma escrita no framebuffer.

Durante a simulação, todas as escritas do sinal `fb_we` foram contabilizadas. Caso alguma escrita fosse detectada, o testbench registrava um erro, pois pixels transparentes não devem alterar o conteúdo existente no framebuffer.

O teste foi utilizado para validar que a transparência ocorre antes da escrita do pixel, evitando que regiões transparentes da sprite sobrescrevam as camadas inferiores.

## 8.4 Teste de Espelhamento

O comportamento de espelhamento foi testado considerando as quatro possíveis configurações dos bits de flip da sprite:

* Sem espelhamento;
* Espelhamento horizontal (`flip_h`);
* Espelhamento vertical (`flip_v`);
* Espelhamento horizontal e vertical simultaneamente (`flip_h + flip_v`).

Para tornar o efeito do espelhamento verificável, foi utilizado um padrão assimétrico de 16×16 pixels. Dessa forma, uma simples mudança na posição dos pixels permite identificar se a transformação foi realizada corretamente.

No teste combinado de `flip_h + flip_v`, por exemplo, a barra vertical originalmente posicionada à esquerda deveria aparecer à direita, enquanto a barra horizontal originalmente posicionada na parte inferior deveria aparecer na parte superior. O testbench verifica também a quantidade de pixels escritos e as posições esperadas no framebuffer.

Ao final da execução, o testbench contabiliza as falhas encontradas e informa se o teste completo de espelhamento foi aprovado.

## 8.5 Teste de Sobreposição

O teste de sobreposição foi utilizado para verificar o comportamento do pipeline quando diferentes elementos de renderização ocupam a mesma região da tela.

Nesse cenário, background, polígono e sprite são configurados de forma que suas áreas de escrita coincidam. Cada camada utiliza uma cor diferente, permitindo observar qual camada permanece no framebuffer após a composição.

O testbench verifica individualmente a quantidade de pixels escritos por cada componente. Em um dos cenários utilizados, background, polígono e sprite realizam 256 escritas cada, totalizando 768 escritas. Ao final, os pixels da região de sobreposição são verificados e devem apresentar a cor correspondente à última camada renderizada.

Esse teste também permite verificar, de forma indireta, a sequência de composição utilizada pelo sistema, garantindo que as camadas sejam processadas na ordem estabelecida pela arquitetura.

## 8.6 Teste de Prioridade das Sprites

O sistema possui um mecanismo de prioridade para determinar qual sprite deve permanecer visível quando duas ou mais sprites ocupam a mesma região.

Para validar esse mecanismo, foram configuradas duas sprites de 16×16 pixels na posição `(50,50)`. A primeira sprite possui prioridade `0` e utiliza a cor vermelha, enquanto a segunda possui prioridade `1` e utiliza a cor azul.

Como ambas ocupam os mesmos 256 pixels, o resultado esperado é que cada sprite produza 256 escritas, totalizando 512 escritas. Após a composição, entretanto, todos os pixels da região devem apresentar a cor da sprite de maior prioridade.

O testbench verifica tanto os contadores individuais quanto o conteúdo final do framebuffer. A aprovação ocorre somente quando são detectadas 512 escritas, sendo 256 provenientes de cada sprite, e todos os pixels da região `(50,50)` até `(65,65)` apresentam a cor azul.

## 8.7 Teste de Troca de Buffers

A troca de buffers foi testada utilizando dois framebuffers independentes, denominados `BUFFER 0` e `BUFFER 1`. Cada buffer foi associado a uma cor diferente para facilitar a identificação durante a simulação.

Inicialmente, foi escrita a cor vermelha na posição `(100,100)` do `BUFFER 0` e a cor azul na mesma posição do `BUFFER 1`. Em seguida, o teste selecionou o `BUFFER 0` para leitura e verificou a presença da cor vermelha. Posteriormente, a seleção foi alterada para o `BUFFER 1`, que deveria apresentar a cor azul.

Por fim, o teste retornou ao `BUFFER 0` e verificou novamente seu conteúdo. Também foi verificado que os dois buffers mantiveram seus conteúdos independentes após as trocas.

Esse teste valida o princípio utilizado pelo sistema de double buffering: enquanto um buffer pode ser utilizado para exibição, o outro pode receber os dados referentes ao próximo frame, permitindo realizar a troca posteriormente sem destruir o conteúdo do frame atualmente exibido.

## 8.8 Testes de Integração

Após a validação individual dos motores, foram realizados testes de integração para verificar a comunicação entre os componentes responsáveis pela composição da imagem.

O compositor é responsável por controlar a sequência de processamento entre background, polígonos e sprites, enquanto realiza a arbitragem dos recursos compartilhados. Na arquitetura integrada, os três motores possuem suas próprias interfaces de escrita e o compositor seleciona qual delas será conectada à porta física de escrita do framebuffer. Da mesma forma, as solicitações de leitura da paleta são arbitradas pelo compositor.

A sequência utilizada durante a composição é:

```text
START
  |
  v
BACKGROUND
  |
  v
POLÍGONOS
  |
  v
SPRITES
  |
  v
DONE
```

Dessa maneira, os testes de integração verificam não somente a geração dos pixels, mas também o correto sequenciamento dos motores e a composição das diferentes camadas no framebuffer.

## 8.9 Erros, Limitações e Decisões de Projeto

Durante o desenvolvimento dos testbenches foram identificados problemas relacionados principalmente à sincronização das memórias e ao controle da sequência de renderização.

Como as memórias utilizadas no hardware possuem comportamento síncrono, seus dados não ficam disponíveis imediatamente após a aplicação do endereço. Por esse motivo, os testbenches dos motores de background e do framebuffer utilizam modelos de memória com latência de leitura, permitindo reproduzir mais fielmente o comportamento esperado no hardware.

Outro ponto importante foi a necessidade de considerar a latência durante a leitura da paleta. O testbench do rasterizador de quadrados utiliza uma memória de paleta com saída registrada e uma latência de um ciclo, reproduzindo o comportamento esperado pelo módulo.

Também foram necessários testes específicos para verificar condições que poderiam provocar escrita incorreta no framebuffer, como pixels transparentes, coordenadas invertidas, sobreposição de elementos e seleção incorreta dos bancos de memória.

### 8.9.1 Módulos auxiliares para demonstração

Como a unidade de controle do coprocessador foi definida como parte do desenvolvimento da **Fase 2**, foi necessário utilizar uma solução temporária para permitir a demonstração das funcionalidades implementadas nesta etapa.

Para isso, foram desenvolvidos módulos auxiliares responsáveis por gerar comandos de teste e modificar os atributos das sprites. Entre eles estão o `test_driver` e o `sprite_mover_flip`.

O módulo `test_driver` atua como um controlador simplificado da demonstração. Ele gera o início de cada frame e, durante a fase de polígonos, pode comandar a execução de um quadrado e de um triângulo com parâmetros previamente definidos. Também permite habilitar ou desabilitar a renderização dos polígonos por meio de uma entrada externa.

Já o módulo `sprite_mover_flip` foi desenvolvido para permitir a movimentação de uma sprite e o acionamento dos comandos de espelhamento horizontal e vertical. O módulo mantém a posição da sprite e os estados dos bits `flip_h` e `flip_v`, atualizando a memória de atributos da sprite quando ocorre uma movimentação ou alteração de espelhamento.

Esses módulos não substituem a unidade de controle definitiva do coprocessador. Eles foram utilizados especificamente como uma solução auxiliar para conectar e demonstrar, em hardware, os módulos de renderização desenvolvidos na fase atual.

### 8.9.2 Problema identificado na demonstração

A execução da demonstração em hardware foi importante para complementar os testes realizados no ModelSim. Durante essa etapa foi identificado um problema no funcionamento do **espelhamento horizontal das sprites**.

Embora os testbenches utilizados durante a validação dos módulos tenham sido capazes de verificar as diferentes configurações de `flip_h` e `flip_v`, a execução integrada na FPGA revelou que o espelhamento horizontal não apresentava o comportamento esperado na demonstração.

Esse resultado evidenciou uma diferença entre a validação individual realizada em simulação e o comportamento observado no sistema integrado em hardware. O problema foi identificado especificamente durante a utilização do módulo auxiliar `sprite_mover_flip`, que permitia acionar o espelhamento por meio de pulsos externos.

A identificação desse erro também demonstrou a importância da etapa de demonstração em hardware como complemento aos testes de simulação. Enquanto os testbenches permitem verificar o comportamento lógico de módulos específicos em condições controladas, a execução na FPGA possibilita observar a interação entre os módulos e as condições reais de operação do sistema.

O problema do espelhamento horizontal permanece, portanto, como uma pendência identificada nesta fase e deverá ser investigado e corrigido durante a continuidade do desenvolvimento.

### 8.9.3 Comandos Inválidos

Apesar de o rasterizador possuir o sinal `invalid_cmd`, não foi desenvolvido um testbench específico para validação de comandos inválidos nesta fase do projeto.

Essa funcionalidade está relacionada ao tratamento dos comandos recebidos pelo coprocessador e depende de uma unidade de controle responsável pela interpretação e gerenciamento desses comandos. Foi tomada a decisão de direcionar o desenvolvimento dessa unidade de controle para a **Fase 2 do projeto**.

Dessa forma, os testes realizados nesta etapa foram concentrados na validação dos módulos de renderização e de sua integração, incluindo rasterização, background, sprites, composição, transparência, espelhamento, prioridade e troca de buffers.

A ausência desse teste nesta fase representa, portanto, uma limitação de escopo do desenvolvimento atual, e não uma indicação de que o comportamento de comandos inválidos tenha sido validado.



# 9. Análise do Resultado

Os resultados obtidos durante o desenvolvimento indicam que a maior parte dos requisitos funcionais e arquiteturais estabelecidos para o coprocessador gráfico foi atendida. A validação foi realizada em duas etapas principais: inicialmente por meio de simulações no ModelSim, utilizando testbenches específicos para os módulos, e posteriormente por meio da demonstração do sistema implementado na FPGA DE1-SoC.

A combinação dessas duas etapas permitiu verificar tanto o comportamento lógico dos módulos individualmente quanto a integração entre os diferentes componentes responsáveis pela geração e composição da imagem.

## 9.1 Resultados de Simulação

Os testes realizados no ModelSim demonstraram o funcionamento dos principais módulos de renderização.

O rasterizador foi validado para a geração de retângulos preenchidos, incluindo diferentes posições, dimensões, coordenadas invertidas, o caso de um único pixel e diferentes índices de cor e paletas. Os testes também verificaram a quantidade de pixels escritos e a ausência de escritas fora da região especificada.

O motor de background apresentou o comportamento esperado para a geração da camada baseada em tiles e para o deslocamento horizontal. O mecanismo de scroll foi testado durante múltiplos frames, verificando a atualização progressiva da posição de deslocamento e a geração de escritas no framebuffer.

Para as sprites, foram realizados testes de transparência, espelhamento, prioridade e posicionamento. A transparência foi verificada utilizando pixels com índice transparente, garantindo que esses pixels não provocassem alterações no framebuffer. O espelhamento horizontal e vertical também foi testado utilizando padrões assimétricos, permitindo identificar alterações nas posições dos pixels após as transformações.

Os testes de integração verificaram a composição das diferentes camadas. Background, polígonos e sprites foram posicionados sobre uma mesma região, permitindo verificar a sequência de composição e o resultado final armazenado no framebuffer.

Também foi validada a troca entre os dois buffers de vídeo. Os testes demonstraram que os conteúdos dos buffers permanecem independentes e que a seleção do buffer altera corretamente a imagem utilizada para leitura.

De maneira geral, os resultados de simulação indicaram comportamento consistente dos módulos implementados e permitiram validar as principais funcionalidades de renderização antes da execução em hardware.

## 9.2 Resultados da Demonstração em Hardware

Após a validação por simulação, o projeto foi implementado na FPGA DE1-SoC para realização da demonstração.

A demonstração permitiu verificar o funcionamento integrado do pipeline de vídeo, incluindo a geração do background, a renderização de polígonos, a utilização de sprites, a composição das camadas e a saída através da interface VGA.

A utilização de uma resolução lógica de `320 × 240` com duplicação dos pixels permitiu gerar a saída em `640 × 480`, mantendo uma arquitetura de renderização mais simples e compatível com os recursos utilizados no projeto.

A demonstração também foi importante para identificar um problema que não havia sido evidenciado durante os testes individuais de simulação. Ao utilizar os controles desenvolvidos especificamente para a apresentação, foi observado que o **espelhamento horizontal das sprites não apresentava o comportamento esperado**.

Esse resultado demonstra a importância da validação em hardware como complemento aos testbenches. A simulação permite verificar condições específicas de maneira controlada, enquanto a execução na FPGA permite observar o comportamento do sistema integrado em condições mais próximas da utilização real.

Apesar desse problema específico, as demais funcionalidades demonstradas apresentaram o comportamento esperado, indicando que a arquitetura desenvolvida é funcional em hardware.

## 9.3 Atendimento aos Requisitos

A análise dos resultados mostra que a maior parte dos requisitos estabelecidos para o projeto foi atendida.

### Entrada e saída

A saída de vídeo foi implementada utilizando a interface VGA da DE1-SoC, com resolução física de `640 × 480` pixels. A renderização utiliza uma resolução lógica de `320 × 240` pixels, com duplicação dos pixels na saída.

Os controles físicos da placa foram utilizados apenas como mecanismo auxiliar para a demonstração das funcionalidades implementadas, não sendo tratados como substitutos da futura interface MMIO.

### Núcleo do coprocessador

O núcleo gráfico foi desenvolvido em Verilog e organizado de forma modular, separando os módulos de memória, motores gráficos, compositor, framebuffer e saída VGA.

Também foram utilizadas estratégias de inicialização e reset nos módulos necessários para estabelecer estados iniciais conhecidos durante a execução.

A arquitetura modular permitiu desenvolver e testar os diferentes componentes individualmente antes da integração.

### Motor de background

O motor de background implementa uma camada baseada em tilemap de `40 × 30` entradas, utilizando tiles de `8 × 8` pixels. Os padrões e informações de tiles são armazenados em memórias internas e o mecanismo de scroll foi validado por simulação.

O motor também realiza a geração dos pixels da camada e sua escrita no framebuffer durante o processo de composição.

### Motor de sprites

O sistema possui memória de atributos para múltiplas sprites e suporta sprites de `16 × 16` pixels, além de atributos como posição, padrão gráfico, habilitação, prioridade, seleção de paleta e espelhamento horizontal e vertical.

Os testes de transparência e prioridade apresentaram os resultados esperados. Entretanto, foi identificado um problema especificamente no **espelhamento horizontal**, observado durante a demonstração em hardware.

Portanto, esse requisito foi considerado **parcialmente atendido**, permanecendo o comportamento do `flip_h` como uma funcionalidade a ser corrigida.

### Rasterizador de polígonos

O rasterizador implementa a geração de primitivas preenchidas utilizando aritmética inteira. Os testes realizados validaram a geração de quadrados e a integração com a camada de polígonos.

O projeto também possui suporte à rasterização de triângulos, utilizado durante a composição e demonstração do sistema.

### Compositor, paleta e saída VGA

O compositor realiza o sequenciamento das camadas de background, polígonos e sprites e controla o acesso aos recursos compartilhados, como framebuffer e paleta.

A composição segue uma ordem definida, permitindo que as camadas superiores sobrescrevam as inferiores quando não há transparência. Os testes de sobreposição e prioridade confirmaram o comportamento esperado dessa organização.

A paleta permite associar índices de cor às cores RGB utilizadas na saída, enquanto o framebuffer armazena os pixels resultantes da composição.

## 9.4 Recursos, Timing e Desempenho

A síntese do projeto foi realizada no Quartus para avaliar a utilização dos recursos disponíveis na FPGA e verificar a viabilidade da implementação da arquitetura proposta.

Em relação aos recursos de memória, o projeto utiliza **1.659.776 bits** dos **4.065.280 bits** disponíveis na FPGA, correspondendo a aproximadamente **40,9% da capacidade total de memória**. Essa utilização está relacionada principalmente às memórias utilizadas pelo framebuffer, padrões gráficos, atributos das sprites, tiles do background e paleta.

Quanto aos elementos sequenciais, foram utilizados **996 registradores**. Já a implementação da lógica combinacional e sequencial ocupa **709 ALMs (Adaptive Logic Modules)**.

Os principais resultados de utilização podem ser resumidos da seguinte forma:

| Recurso       |     Utilização | Total disponível | Utilização percentual |
| ------------- | -------------: | ---------------: | --------------------: |
| Memória       | 1.659.776 bits |   4.065.280 bits |               ≈ 40,9% |
| Registradores |            996 |                — |                     — |
| ALMs          |            709 |                — |                     — |

Os resultados indicam que o projeto utiliza uma parcela significativa, porém ainda disponível, dos recursos de memória da FPGA. Isso é particularmente relevante para a arquitetura gráfica, uma vez que o framebuffer e as demais memórias de recursos gráficos representam uma parcela importante do armazenamento utilizado.

A utilização de **709 ALMs** e **996 registradores** também demonstra que a implementação dos motores gráficos, compositor, controle das memórias e lógica de vídeo foi realizada com uma ocupação relativamente moderada dos recursos lógicos, deixando margem para futuras extensões da arquitetura.

Em relação ao desempenho, a implementação deve ser analisada em conjunto com os resultados do relatório de timing gerado pelo Quartus. A frequência máxima de operação e os valores de slack permitem determinar se os caminhos críticos do circuito atendem às restrições temporais estabelecidas para o sistema.

Outro fator que influencia o desempenho é o processamento sequencial das camadas. O compositor executa as etapas de background, polígonos e sprites de forma ordenada, garantindo uma composição determinística, mas reduzindo o paralelismo entre os motores. Assim, o tempo necessário para produzir um frame depende da quantidade de ciclos consumidos por cada etapa de renderização.

Dessa forma, a análise dos recursos demonstra que a implementação atual ainda possui espaço para expansão, enquanto a análise de timing permite identificar se a frequência de operação utilizada é adequada e quais caminhos podem exigir otimização em versões futuras.


## 9.5 Gargalos e Limitações

Um dos principais pontos de atenção da arquitetura é o acesso aos recursos compartilhados durante a composição. O framebuffer e a paleta são utilizados por diferentes motores, sendo necessário que o compositor controle o acesso a esses recursos.

A composição sequencial das camadas simplifica a arbitragem e torna o comportamento determinístico, porém limita o grau de paralelismo entre os motores. Background, polígonos e sprites não são processados simultaneamente; cada etapa precisa concluir antes que a próxima seja iniciada.

Outro ponto de atenção é o processamento das sprites. Como múltiplas sprites podem ocupar regiões sobrepostas, o mecanismo de prioridade e transparência precisa ser executado de maneira consistente para determinar o pixel final.

Também foi identificada a limitação relacionada ao espelhamento horizontal das sprites, descoberta durante a demonstração em hardware.

Por fim, a unidade de controle definitiva e a futura interface de comandos/MMIO não fazem parte do escopo concluído nesta fase, tendo seu desenvolvimento direcionado para a Fase 2.

## 9.6 Melhorias Possíveis

Entre as principais melhorias previstas para a continuidade do projeto estão:

* corrigir o funcionamento do espelhamento horizontal das sprites;
* implementar a unidade de controle definitiva do coprocessador;
* desenvolver a interface MMIO para comunicação com o processador;
* desenvolver e executar testes específicos para comandos inválidos após a implementação da unidade de controle;
* aumentar o grau de paralelismo entre os motores de renderização, caso os recursos da FPGA permitam;
* otimizar os caminhos críticos identificados na análise de timing;
* avaliar formas de reduzir o número de ciclos necessários para a composição dos pixels;
* ampliar a quantidade e a complexidade das primitivas gráficas suportadas;
* realizar testes adicionais diretamente no hardware para complementar a validação realizada no ModelSim.

## 9.7 Funcionalidades Não Atendidas

Embora a maior parte dos requisitos tenha sido atendida, algumas funcionalidades não foram completamente concluídas nesta fase.

A principal funcionalidade parcialmente atendida é o **espelhamento horizontal das sprites (`flip_h`)**, que apresentou comportamento incorreto durante a demonstração em hardware e deverá ser corrigido.

Além disso, o **tratamento de comandos inválidos** não foi validado por testbench, pois a unidade de controle responsável pela interpretação desses comandos foi deliberadamente deixada para a Fase 2 do desenvolvimento.

Da mesma forma, a interface de controle definitiva baseada em comandos e MMIO ainda não representa o estágio final do coprocessador, sendo os controles físicos utilizados nesta fase exclusivamente para viabilizar a demonstração das funcionalidades implementadas.

Assim, considerando o escopo definido para esta etapa, o projeto apresenta um grau elevado de atendimento aos requisitos funcionais de renderização, com as principais pendências concentradas no controle do coprocessador e na correção do espelhamento horizontal das sprites.


# 10. Controles DA DEMONSTRACAO NA FPGA

Na versao atual do top-level foram identificados os seguintes controles:

KEY[0]
Reset

SW[0]
Habilita scroll automatico

SW[1]
Seleciona eixo do scroll

SW[2]
Seleciona direcao do scroll

SW[4:3]
Direcao de movimento do sprite

KEY[1]
Movimento do sprite

SW[5]
Seleciona flip horizontal ou vertical

KEY[2]
Executa flip

SW[8:0]
Define posicao X para criacao de sprite

KEY[3]
Cria novo sprite

SW[9]
Habilita demonstracao de poligonos

Esses controles servem apenas como interface de demonstracao da etapa FPGA e nao substituem a interface por software prevista para a evolucao do projeto.

# 11. Equipe DO DESENVOLVIMENTO

### Integrantes oficiais do grupo:

- Cauan Dos Reis Almeida
- Diego Dos Santos Barros Santana
- Heitor Abdalla Mascarenhas


### Instituicao:
- Universidade Estadual de Feira de Santana - UEFS

### Disciplina:
- Sistema Digital

### Periodo:
- 2026.2



# 12. Referências

- **INTEL CORPORATION.** *Cyclone V Device Overview*. Santa Clara: Intel Corporation. Disponível em: <https://www.intel.com/content/www/us/en/products/details/fpga/cyclone/v.html>.
- **INTEL CORPORATION.** *Cyclone V Hard Processor System Technical Reference Manual*. Santa Clara: Intel Corporation.
- **INTEL CORPORATION.** *Quartus Prime Standard Edition User Guide*. Santa Clara: Intel Corporation.
- **TERASIC TECHNOLOGIES.** *DE1-SoC Development and Education Board User Manual*. Hsinchu: Terasic Inc. Disponível em: <https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=836>.
- **UNIVERSIDADE ESTADUAL DE FEIRA DE SANTANA (UEFS).** *Problema #1 - Desenho do Núcleo de um Co-processador Gráfico em FPGA*. Disciplina de MI - Sistemas Digitais (2026.2), Departamento de Tecnologia, Feira de Santana, 2026.
- **SIEMENS EDA.** *Questa / ModelSim FPGA Edition Simulation User Guide*. Siemens Industry Software Inc.



