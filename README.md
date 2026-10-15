# CoProcessador Grafico em FPGA - Sistema Digital 2026.2

## Sumário

* [1. Visão Geral do Projeto](#1-visão-geral-do-projeto)

  * [1.1 Conceito Geral](#11-conceito-geral)
  * [1.2 Da Descrição da Cena ao Pixel](#12-da-descrição-da-cena-ao-pixel)
  * [1.3 Resolução e Representação da Imagem](#13-resolução-e-representação-da-imagem)
  * [1.4 Arquitetura Gráfica em Hardware](#14-arquitetura-gráfica-em-hardware)
  * [1.5 Composição e Memória de Vídeo](#15-composição-e-memória-de-vídeo)
  * [1.6 Double Buffering](#16-double-buffering)
  * [1.7 Organização Modular](#17-organização-modular)
  * [1.8 Estrutura Principal do Projeto](#18-estrutura-principal-do-projeto)

* [2. Levantamento de Requisitos](#2-levantamento-de-requisitos)

  * [2.1 Requisitos Funcionais](#21-requisitos-funcionais)
  * [2.2 Requisitos Não Funcionais](#22-requisitos-não-funcionais)
  * [2.3 Requisitos de Memória](#23-requisitos-de-memória-e-organização-interna)

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

  * [4.1 Visão Geral da Arquitetura](#41-visão-geral-da-arquitetura)
  * [4.2 Conjunto de Instruções (ISA)](#42-conjunto-de-instruções-isa)
    * [4.2.1 Formatos de Instrução](#421-formatos-de-instrução)
    * [4.2.2 Instruções](#422-instruções)
    * [4.2.3 Registradores](#423-registradores)
    * [4.2.4 Flags e Desvios Condicionais](#424-flags-e-desvios-condicionais)
  * [4.3 Caminho de Controle](#43-caminho-de-controle)
    * [4.3.1 Unidade de Busca de Instruções](#431-unidade-de-busca-de-instruções)
    * [4.3.2 Banco de Registradores](#432-banco-de-registradores)
    * [4.3.3 Unidade Lógica e Aritmética](#433-unidade-lógica-e-aritmética)
    * [4.3.4 Unidade de Controle](#434-unidade-de-controle)
  * [4.4 Fluxo de Composição e Prioridade entre Camadas](#44-fluxo-de-composição-e-prioridade-entre-camadas)
    * [4.4.1 Seleção do Motor (`engine_mux`)](#441-seleção-do-motor-engine_mux)
    * [4.4.2 Camada de Composição (`camada_composicao`)](#442-camada-de-composição-camada_composicao)
  * [4.5 Ciclo de Quadro e Orçamento de Tempo](#45-ciclo-de-quadro-e-orçamento-de-tempo)
  * [4.6 Principais Módulos](#46-principais-módulos)
  * [4.7 Memórias do Sistema](#47-memórias-do-sistema)
    * [4.7.1 `bg_tile_ram` — 1200 × 8 bits](#471-bg_tile_ram--1200--8-bits)
    * [4.7.2 `bg_tile_pattern_ram` — 16384 × 8 bits](#472-bg_tile_pattern_ram--16384--8-bits)
    * [4.7.3 Atributos dos Sprites — 32 entradas](#473-atributos-dos-sprites--32-entradas)
    * [4.7.4 `sprite_pattern_ram` — 16384 × 8 bits](#474-sprite_pattern_ram--16384--8-bits)
    * [4.7.5 `palette_ram` — 512 × 9 bits](#475-palette_ram--512--9-bits)
    * [4.7.6 `framebuffer_ram` — 2 bancos de 76800 × 9 bits](#476-framebuffer_ram--2-bancos-de-76800--9-bits)
    * [4.7.7 `instruction_memory` — 16384 × 32 bits](#477-instruction_memory--16384--32-bits)
    * [4.7.8 Mapas de Camadas — 2 × (76800 × 2 bits)](#478-mapas-de-camadas--2--76800--2-bits)
  * [4.8 Organização do Armazenamento](#48-organização-do-armazenamento)

* [5. Especificação de Hardware e Software](#5-especificacao-de-hardware-e-software)

  * [5.1 Hardware](#51-hardware)
  * [5.2 Software](#52-software)
  * [5.3 Arquivos de Inicialização](#53-arquivos-de-inicialização)


* [6. Processo de Desenvolvimento](#6-processo-de-desenvolvimento)

  * [6.1 Sistema VGA e Escalonamento Espacial](#61-sistema-vga-e-escalonamento-espacial)
  * [6.2 Framebuffer e Sincronismo de Exibição](#62-framebuffer-e-sincronismo-de-exibição)
  * [6.3 Engine de Background (Tilemap e Scrolling)](#63-engine-de-background-tilemap-e-scrolling)
  * [6.4 Engine de Sprites e Matriz de Atributos (OAM)](#64-engine-de-sprites-e-matriz-de-atributos-oam)
  * [6.5 Rasterizador de Polígonos](#65-rasterizador-de-polígonos)
  * [6.6 Compositor de Vídeo e Paleta de Cores](#66-compositor-de-vídeo-e-paleta-de-cores)
  * [6.7 Integração no Top-Level e Validação Física](#67-integração-no-top-level-e-validação-física)
  * [6.8 Definição da ISA e do Modelo de Execução](#68-definição-da-isa-e-do-modelo-de-execução)
  * [6.9 Banco de Registradores e ULA](#69-banco-de-registradores-e-ula)
  * [6.10 Unidade de Busca de Instruções e Unidade de Controle](#610-unidade-de-busca-de-instruções-e-unidade-de-controle)
  * [6.11 Integração no `coprocessador_top`](#611-integração-no-coprocessador_top)
  * [6.12 Prioridade entre Camadas (Camada de Composição)](#612-prioridade-entre-camadas-camada-de-composição)
  * [6.13 Desvios Condicionais e Flags](#613-desvios-condicionais-e-flags)
  * [6.14 Ferramentas de Apoio](#614-ferramentas-de-apoio)
  * [6.15 Programas de Demonstração](#615-programas-de-demonstração)
  * [6.16 Verificação e Medições da Segunda Etapa](#616-verificação-e-medições-da-segunda-etapa)


* [7. Instalação e Configuração](#7-instalação-e-configuração)

  * [7.1 Pré-requisitos](#71-pré-requisitos)
  * [7.2 Estrutura Geral do Projeto](#72-estrutura-geral-do-projeto)
  * [7.3 Observação Importante sobre o Projeto Quartus](#73-observação-importante-sobre-o-projeto-quartus)
  * [7.4 Configuração Básica](#74-configuração-básica)
  * [7.5 Programação](#75-programação)

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

* [11. Equipe do Desenvolvimento](#11-equipe-do-desenvolvimento)

* [12. Referências](#12-referências)

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

A partir da análise do enunciado do Problema #2 de Sistemas Digitais (2026.2) e da implementação presente no repositório, os requisitos foram organizados em **Requisitos Funcionais (RF)**, **Requisitos Não Funcionais (RNF)** e **Requisitos de Memória e Organização Interna**. A classificação considera os requisitos explícitos do problema e distingue as funcionalidades identificáveis no código daquelas cuja validação depende de resultados de simulação, síntese ou demonstração em hardware.

---

## 2.1 Requisitos Funcionais

| ID | Requisito | Detalhamento Técnico | Status |
| :--- | :--- | :--- | :--- |
| **RF01** | **ISA de 32 bits** | Conjunto de instruções próprio, com instruções de largura fixa de 32 bits e opcode de 5 bits. | **IMPLEMENTADO NO RTL** |
| **RF02** | **Unidade de Busca de Instruções** | Busca ativa de instruções em memória interna, com atualização do contador de programa (PC) e suporte a desvios. | **IMPLEMENTADO NO RTL** |
| **RF03** | **Registrador de Instrução (IR)** | Armazenamento e disponibilização da instrução para decodificação e execução. | **A VALIDAR** — confirmar a correspondência explícita com o requisito de IR no datapath integrado. |
| **RF04** | **Unidade de Controle** | Decodificação dos opcodes e geração dos sinais de controle para a ULA, o banco de registradores, as memórias e os motores gráficos. | **IMPLEMENTADO NO RTL** |
| **RF05** | **Datapath** | Integração do banco de registradores, ULA, unidade de busca, controle e unidades funcionais. | **IMPLEMENTADO NO RTL** |
| **RF06** | **Banco de Registradores** | Armazenamento de operandos gerais, flags e registradores dedicados às coordenadas dos vértices e à cor do rasterizador. | **IMPLEMENTADO NO RTL** |
| **RF07** | **Registradores de Estado** | Disponibilização de informações de estado do coprocessador e das flags utilizadas nas operações e nos desvios condicionais. | **IMPLEMENTADO NO RTL** |
| **RF08** | **Unidade Lógica e Aritmética (ULA)** | Execução das operações `ADD`, `SUB`, `AND`, `LSL`, `LSR` e `PASS`, com geração das flags utilizadas pelos desvios. | **IMPLEMENTADO NO RTL** |
| **RF09** | **Programa Gráfico em Assembly da ISA Própria** | Programa de demonstração codificado para a ISA criada pela equipe e armazenado na memória interna de instruções. | **SUPORTE PRESENTE** — a conformidade do programa entregue com todos os requisitos deve ser verificada. |
| **RF10** | **Definição da Sintaxe da ISA** | Documentação dos formatos de instrução, operandos, campos de codificação, opcodes e regras de execução. | **DOCUMENTAÇÃO PRESENTE** — conferir se a versão final está incluída e atualizada no repositório. |
| **RF11** | **Motor de Background** | Geração do plano de fundo a partir de um mapa de tiles e de uma memória de padrões gráficos. | **IMPLEMENTADO NO RTL** |
| **RF12** | **Motor de Sprites** | Renderização de até 32 sprites, com posição, habilitação, padrão, seleção de paleta, prioridade e espelhamento horizontal e vertical. | **IMPLEMENTADO NO RTL** — validar os comportamentos por simulação e hardware. |
| **RF13** | **Rasterizador de Polígonos** | Rasterização de retângulos preenchidos e triângulos, acionada por instruções da ISA. | **IMPLEMENTADO NO RTL** |
| **RF14** | **Compositor Gráfico** | Composição das camadas com prioridade entre background, rasterizadores e sprites. | **IMPLEMENTADO NO RTL** |
| **RF15** | **Controlador VGA** | Geração dos sinais de vídeo para saída VGA de 640 × 480 pixels, a partir da imagem lógica de 320 × 240 pixels. | **IMPLEMENTADO NO RTL** |
| **RF16** | **Sincronização com VGA** | Utilização do `vblank` para sincronização do quadro e troca dos bancos do framebuffer. | **IMPLEMENTADO NO RTL** |
| **RF17** | **Comunicação entre Unidades Funcionais** | Uso de sinais de controle, incluindo `busy`, `done` e sinais de início de operação, conforme a unidade acionada. | **IMPLEMENTADO NO RTL** — a validação dos protocolos deve ser documentada pelos testes. |
| **RF18** | **Memória Interna de Instruções** | Armazenamento do programa gráfico em memória de 16.384 palavras de 32 bits, configurada para inicialização por arquivo de memória. | **IMPLEMENTADO NO RTL** |
| **RF19** | **Testbenches dos Módulos Principais** | O enunciado exige testes para cada módulo principal. O repositório contém testbenches para diversos módulos e comportamentos específicos. | **PARCIALMENTE DOCUMENTADO** — a cobertura completa e os resultados de execução precisam ser comprovados. |
| **RF20** | **Testbench de Integração** | O enunciado exige um testbench de integração do coprocessador. Existem testes de sistema associados a cenários específicos, mas é necessário confirmar e documentar a cobertura integral exigida. | **A VALIDAR** |
| **RF21** | **Driver Linux em Assembly ARM** | Na alternativa de busca passiva, o enunciado prevê comunicação com o coprocessador por fila de comandos via MMIO e um programa Assembly ARM. | **NÃO IMPLEMENTADO NESTA ARQUITETURA** — o projeto adota busca ativa, alternativa permitida pelo enunciado. |
| **RF22** | **Aplicação de Jogo em C** | Aplicação prevista como etapa posterior, destinada a utilizar o coprocessador gráfico. | **ETAPA POSTERIOR** — não constitui requisito de implementação imediata do caminho de busca ativa escolhido. |

> **Nota sobre os status:** “Implementado no RTL” identifica funcionalidades observáveis na implementação; não significa que tenham sido aprovadas em todos os testes ou demonstradas com sucesso na placa. Os itens que dependem de evidências de execução permanecem indicados como validação pendente.

---

## 2.2 Requisitos Não Funcionais

1. **Plataforma e hardware-alvo**
   - Placa **DE1-SoC**, equipada com FPGA Intel Cyclone V, dispositivo `5CSEMA5F31C6`.
   - Projeto desenvolvido em Verilog e organizado para compilação no Quartus.

2. **Frequências de clock e temporização**
   - **Clock de sistema: 50 MHz**, utilizado pela lógica do coprocessador.
   - **Clock de pixel: 25 MHz**, configurado pelo PLL para o subsistema VGA.
   - A frequência máxima alcançada, a margem de temporização e o atendimento às restrições de *timing* devem ser confirmados pelo relatório de compilação e análise temporal do Quartus.

3. **Resolução e apresentação de vídeo**
   - Resolução lógica de **320 × 240 pixels**.
   - Saída VGA de **640 × 480 pixels**, com escala de 2 × 2 pixels físicos para cada pixel lógico.
   - A taxa efetiva de atualização e a estabilidade da saída devem ser verificadas por medição ou demonstração; não são inferidas apenas da resolução e dos clocks configurados.

4. **Organização da arquitetura**
   - Integração de busca de instruções, unidade de controle, datapath, banco de registradores, ULA, registradores de estado e unidades funcionais gráficas.
   - O compositor, o controle de quadro e o controlador VGA devem operar continuamente, independentemente da execução de instruções específicas, conforme estabelecido no enunciado.

5. **Sincronização e integridade do quadro**
   - Utilização de sincronização com `vblank` para a troca dos bancos do framebuffer.
   - A ausência de *screen tearing*, *glitches* ou outros artefatos não deve ser declarada sem testes específicos que comprovem esses comportamentos.

6. **Linguagem e ferramentas**
   - Implementação do hardware em Verilog HDL.
   - Projeto e arquivos de configuração destinados ao Quartus e à FPGA da placa DE1-SoC.
   - Os resultados finais devem identificar a versão das ferramentas efetivamente utilizada nos testes.

7. **Reprodutibilidade e documentação**
   - O repositório deve conter código RTL, projeto Quartus, documentação da ISA, programa gráfico, testbenches e scripts necessários à reprodução dos testes.
   - O README deve apresentar os resultados efetivamente obtidos, as limitações identificadas e as funcionalidades que não atenderem aos requisitos.

8. **Análise de recursos e desempenho**
   - O enunciado exige relatório de síntese, utilização de recursos, frequência máxima e análise de *timing*.
   - A ocupação de blocos M10K, a frequência máxima e os gargalos devem ser informados com base nos relatórios gerados pelas ferramentas, e não apenas por estimativas teóricas.

---

## 2.3 Requisitos de Memória e Organização Interna

A arquitetura utiliza memórias internas para armazenar o programa gráfico, o mapa de tiles, os padrões gráficos, a paleta e os pixels do framebuffer. As capacidades abaixo são calculadas a partir das dimensões configuradas nos arquivos de memória do projeto. Elas representam capacidades nominais, não resultados de ocupação obtidos após a síntese.

### Memória de Instruções

- **Profundidade:** 16.384 palavras.
- **Largura da palavra:** 32 bits.
- **Capacidade nominal:** 524.288 bits, equivalentes a **64 KiB**.
- **Finalidade:** armazenar as instruções executadas pela unidade de busca ativa.
- **Inicialização:** por arquivo de memória, como `.mif`, conforme a configuração da memória.

### Mapa de Tiles do Background

- **Dimensões:** 40 × 30 posições, totalizando 1.200 entradas.
- **Largura da entrada:** 8 bits.
- **Capacidade nominal:** 9.600 bits, equivalentes a **1.200 bytes (aproximadamente 1,17 KiB)**.
- **Finalidade:** associar cada posição do mapa a um padrão gráfico de tile.

### Memória de Padrões do Background

- **Profundidade configurada:** 16.384 palavras.
- **Largura da palavra:** 8 bits.
- **Capacidade nominal:** 131.072 bits, equivalentes a **16 KiB**.
- **Finalidade:** armazenar índices de cor dos pixels utilizados pelos padrões de tiles.
- **Dimensão do tile:** 8 × 8 pixels. A quantidade de padrões representáveis depende da organização e do endereçamento utilizados pelo motor.

### Memória de Padrões de Sprites

- **Profundidade configurada:** 16.384 palavras.
- **Largura da palavra:** 8 bits.
- **Capacidade nominal:** 131.072 bits, equivalentes a **16 KiB**.
- **Finalidade:** armazenar os índices de cor dos pixels dos padrões de sprites.
- **Observação:** a capacidade da memória não determina, por si só, a dimensão de cada sprite; o tamanho e o endereçamento efetivos dependem da implementação do motor.

### Atributos de Sprites

- **Quantidade suportada pelo motor:** até 32 sprites.
- **Campos de atributos:** habilitação, prioridade, espelhamento horizontal e vertical, seleção de paleta e índice do padrão gráfico.
- **Posição:** coordenadas X e Y armazenadas com larguras de 9 e 8 bits, respectivamente.
- **Armazenamento ativo:** os atributos são mantidos em estruturas internas do motor de sprites. Embora exista um arquivo de RAM de atributos no projeto Quartus, a implementação atual do motor não utiliza essa RAM como armazenamento ativo dos atributos.

### Paleta de Cores

- **Profundidade configurada:** 512 entradas.
- **Largura da saída:** 9 bits por entrada, correspondentes à representação RGB `RRRGGGBBB`.
- **Capacidade nominal:** 4.608 bits, equivalentes a **576 bytes**.
- **Finalidade:** converter índices de cor em valores RGB utilizados pelo subsistema gráfico.

### Framebuffer com Double Buffering

- **Resolução lógica:** 320 × 240 pixels.
- **Quantidade de pixels por banco:** 76.800.
- **Largura configurada do pixel:** 9 bits.
- **Capacidade nominal por banco:** 691.200 bits, equivalentes a **84,375 KiB**.
- **Quantidade de bancos:** dois, para permitir a renderização em um banco enquanto o outro é apresentado.
- **Capacidade nominal dos dois bancos:** 1.382.400 bits, equivalentes a **168,75 KiB**.

A troca dos bancos está associada ao sincronismo de quadro. A capacidade nominal calculada não inclui automaticamente todas as estruturas auxiliares, como mapas de prioridade por pixel, nem representa o total final de blocos M10K consumidos após síntese.

### Considerações sobre o consumo de memória

A soma das capacidades nominais das memórias listadas acima é uma estimativa parcial da arquitetura. Ela não deve ser apresentada como o consumo total da FPGA, pois pode excluir estruturas adicionais, como os mapas de camadas utilizados pela composição, e não considera o mapeamento final de cada memória nos recursos físicos do dispositivo.

O consumo real de memória, a quantidade de blocos M10K utilizados, a frequência máxima e os resultados de *timing* devem ser obtidos dos relatórios de síntese e implementação do Quartus, conforme exigido pelo Problema #2.



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

A arquitetura do coprocessador foi organizada em dois caminhos complementares: o **caminho de controle**, responsável por executar um programa armazenado em memória e comandar os recursos gráficos, e o **caminho gráfico**, formado pelos motores de renderização, pela composição das camadas, pelo framebuffer e pelo controlador VGA. Na primeira etapa do projeto, a sequência de desenho era fixa e determinada pelo módulo `compositor.v`, e a demonstração dependia de módulos auxiliares (`test_driver` e `sprite_mover_flip`). Nesta etapa, essa responsabilidade passou a ser de uma **unidade de controle por instruções**: um programa em linguagem de montagem, armazenado na memória de instruções, define o que é configurado e o que é desenhado em cada quadro.

O módulo `coprocessador_top.v` atua como elemento central de integração. Ele conecta a unidade de busca, o banco de registradores, a ULA, a unidade de controle, as memórias gráficas, os três motores de renderização, a seleção do motor ativo, a camada de composição, o framebuffer com double buffering e o controlador VGA. As interfaces externas se resumem ao clock de 50 MHz, aos botões (`KEY`), aos LEDs (`LEDR`) e à saída VGA, não havendo mais portas de escrita nas memórias gráficas: toda configuração passa a ser feita por instruções.

Internamente, o sistema continua trabalhando com a resolução lógica de 320×240 pixels e com a saída VGA de 640×480, na qual cada pixel lógico corresponde a um bloco de 2×2 pixels físicos. O clock de 50 MHz é fornecido ao PLL `pll01`, que gera o clock de pixel de 25 MHz do controlador VGA, e o sinal `pll_locked` garante que a saída de vídeo somente opere normalmente após a estabilização do PLL.

> **Observação:** nesta etapa, o módulo `coprocessador_top` substitui o conjunto `top_video`, `test_driver` e `sprite_mover_flip`. Para sintetizar esta versão, ele deve ser definido como *top-level entity* do projeto Quartus, uma vez que o `DE1_SOC_golden_top` da primeira etapa ainda instancia o `top_video`.

## 4.1 Visão Geral da Arquitetura

O fluxo completo do sistema pode ser representado da seguinte forma:

```text
                    memória de instruções (.mif)
                               |
                               v
                  +-------------------------+
                  |  UNIDADE DE BUSCA       |<---- vblank (reinício do quadro)
                  |  PC, stall, HALT, desvios|<---- flags {C, V, N, Z}
                  +------------+------------+
                               | instrução
                               v
                  +-------------------------+
                  |  UNIDADE DE CONTROLE    |
                  |  decodificação          |
                  +--+-------+-------+------+
                     |       |       |
        ULA / flags  |       |       | escritas nas memórias gráficas
           +---------+       |       | (paleta, tilemap, padrões,
           v                 v       |  atributos de sprites, scroll)
  +----------------+  +--------------+--+
  |  BANCO DE      |  |  start / done    |
  |  REGISTRADORES |  |  engine_sel      |
  |  + ULA         |  +--+------+------+-+
  +--------+-------+     |      |      |
           | V0X..COLOR  v      v      v
           |         +------+ +-----+ +-------+
           +-------> | BG   | |RASTE| |SPRITES|
                     |MOTOR | |RIZ. | | MOTOR |
                     +--+---+ +--+--+ +---+---+
                        +--------+--------+
                                 | requisições de paleta / escrita
                                 v
                      +---------------------+
                      |     ENGINE_MUX      |  seleciona o motor ativo
                      +----------+----------+
                                 v
                      +---------------------+
                      | CAMADA DE COMPOSIÇÃO|  garante fundo < polígonos < sprites
                      +----------+----------+
                                 v
                      +---------------------+
                      |    FRAMEBUFFER      |  2 bancos (double buffering)
                      +----------+----------+
                                 v
                            VGA DRIVER --> MONITOR
```

O controle do sistema segue o modelo de **execução comandada por programa**. A unidade de busca lê uma instrução por vez da memória de instruções e a entrega à unidade de controle. Instruções simples, como as aritméticas e as de configuração de memórias, executam em poucos ciclos. Instruções de desenho (`DRAW_BG`, `DRAW_RECT`, `DRAW_TRI` e `DRAW_SPRITES`) disparam o motor correspondente e **mantêm o contador de programa parado** até que o motor sinalize o término. Dessa forma, os motores nunca disputam o framebuffer nem a paleta, e a ordem em que os elementos são desenhados é a ordem das instruções do programa.

O fim do programa de cada quadro é marcado pela instrução `HALT`. Quando ela é executada, a unidade de busca aguarda a próxima borda de subida do sinal de apagamento vertical (VBlank), troca os bancos do framebuffer e reinicia o programa no endereço 0. Os registradores não são zerados nessa reinicialização, o que permite que o programa mantenha estado entre quadros, como a posição e a velocidade de um objeto em movimento.

## 4.2 Conjunto de Instruções (ISA)

O coprocessador executa instruções de **32 bits**. O conjunto foi projetado para ser pequeno e dividido em três grupos: instruções aritméticas e lógicas, instruções de configuração das memórias gráficas e instruções de desenho e controle de fluxo. A numeração dos registradores e a codificação dos desvios seguem a convenção do ARMv8/LEGv8.

### 4.2.1 Formatos de Instrução

Existem quatro formatos de instrução:

| Formato | Uso | Campos |
| :--- | :--- | :--- |
| **A** | ULA (`ADD`, `SUB`, `AND`, `LSL`, `LSR`, `PASS`) | `[31:27]` opcode · `[26]` I · `[25:21]` Rd[4:0] · `[20:15]` Rn · `[14]` Rd[5] · `[11:0]` imm12 ou Rm |
| **G** | Configuração de memórias (`SET_*`, `WRITE_*`, `SCROLL_BG`) | `[31:27]` opcode · `[26:21]` Ra · `[20:15]` Rb |
| **N** | Sem operandos (`DRAW_*`, `NOP`, `WAIT_VBLANK`, `HALT`) | `[31:27]` opcode |
| **D** | Desvios (`B`, `B_COND`) | `[31:27]` opcode · `[26:23]` cond · `[13:0]` deslocamento |

No formato A, o bit `I` seleciona o segundo operando: quando vale 1, ele é um imediato de 12 bits sem sinal (`imm12`); quando vale 0, é o conteúdo do registrador Rm. O destino Rd possui 6 bits, divididos entre `[25:21]` e `[14]`, para permitir o acesso aos registradores dedicados do rasterizador.

### 4.2.2 Instruções

| Opcode | Mnemônico | Formato | Função |
| :---: | :--- | :---: | :--- |
| `00000` | `NOP` | N | Não faz nada |
| `00001` | `ADD` | A | `Rd = Rn + Rm` (ou `imm12`) |
| `00010` | `SUB` | A | `Rd = Rn − Rm` (ou `imm12`) |
| `00011` | `AND` | A | `Rd = Rn & Rm` (ou `imm12`) |
| `00100` | `LSL` | A | `Rd = Rn << Rm[4:0]` (ou `imm12`) |
| `00101` | `LSR` | A | `Rd = Rn >> Rm[4:0]` (ou `imm12`) |
| `00110` | `PASS` | A | `Rd = Rm` (ou `imm12`) |
| `00111` | `SET_PALETTE` | G | `paleta[Ra[8:0]] = Rb[8:0]` |
| `01000` | `DRAW_RECT` | N | Desenha um retângulo preenchido |
| `01001` | `DRAW_TRI` | N | Desenha um triângulo preenchido |
| `01010` | `SET_SPRITE_POS` | G | Posição do sprite `Ra[4:0]` recebe `Rb[16:0]` = `{y, x}` |
| `01011` | `SET_SPRITE_ATTR` | G | Atributos do sprite `Ra[4:0]` recebem `Rb[14:0]` |
| `01100` | `SET_TILEMAP` | G | `tilemap[Ra] = Rb[7:0]` |
| `01101` | `SCROLL_BG` | G | Deslocamento `Ra[8:0]` no eixo indicado por `Rb[0]` (0: X, 1: Y) |
| `01110` | `WRITE_SPRITE_DATA` | G | `padrões_sprite[Ra[13:0]] = Rb[7:0]` |
| `01111` | `WRITE_TILE_DATA` | G | `padrões_tile[Ra[13:0]] = Rb[7:0]` |
| `10000` | `DRAW_BG` | N | Desenha o background |
| `10001` | `DRAW_SPRITES` | N | Desenha todos os sprites habilitados |
| `10010` | `WAIT_VBLANK` | N | Aguarda a próxima borda de subida do VBlank |
| `10011` | `HALT` | N | Fim do programa do quadro |
| `10100` | `B` | D | Desvio incondicional |
| `10101` | `B_COND` | D | Desvio condicional |

Os opcodes `10110` a `11111` são reservados. Se executados, são tratados como `NOP` e sinalizados pela unidade de busca como instrução inválida.

O atributo de um sprite, escrito por `SET_SPRITE_ATTR`, possui 15 bits:

```text
 14      13:9         8        7       6       5:0
+------+-----------+--------+--------+-------+---------+
|enable|prioridade |flip_v  | flip_h |paleta | padrão  |
+------+-----------+--------+--------+-------+---------+
```

### 4.2.3 Registradores

| Registrador | Função |
| :--- | :--- |
| `R0` a `R30` | Propósito geral |
| `R31` (`XZR`) | Lê sempre 0; escritas são descartadas |
| `R33` (`STATUS`) | Somente leitura: `{29'b0, vblank, waiting, running}` |
| `R36` (`FLAGS`) | Somente leitura: `{28'b0, C, V, N, Z}` |
| `R37` a `R43` | `V0X`, `V0Y`, `V1X`, `V1Y`, `V2X`, `V2Y` e `COLOR`: parâmetros do rasterizador |

Os registradores `V0X` a `COLOR` alimentam diretamente o rasterizador. Antes de uma instrução `DRAW_RECT` ou `DRAW_TRI`, o programa escreve os vértices e a cor nesses registradores por meio de instruções comuns da ULA. O registrador `COLOR` possui 9 bits: os 8 bits menos significativos são o índice na paleta e o bit 8 seleciona o banco da paleta.

O uso de `XZR` como destino permite realizar **comparações** sem alterar nenhum registrador. A instrução `SUB XZR, R1, #304`, por exemplo, calcula `R1 − 304`, descarta o resultado e atualiza apenas as flags.

### 4.2.4 Flags e Desvios Condicionais

Toda instrução da ULA atualiza as quatro flags do registrador `FLAGS`: **N** (resultado negativo), **Z** (resultado nulo), **C** (carry de `ADD` ou ausência de empréstimo em `SUB`) e **V** (overflow com sinal). As demais instruções não alteram as flags, e as operações `AND`, `LSL`, `LSR` e `PASS` zeram C e V.

O desvio `B_COND` avalia uma condição sobre essas flags e, se ela for verdadeira, altera o contador de programa. Os códigos de condição seguem o LEGv8:

| `cond` | Nome | Desvia se | Após `SUB a, b` |
| :---: | :---: | :--- | :--- |
| `0000` | `EQ` | Z = 1 | a = b |
| `0001` | `NE` | Z = 0 | a ≠ b |
| `0010` | `HS` | C = 1 | a ≥ b (sem sinal) |
| `0011` | `LO` | C = 0 | a < b (sem sinal) |
| `0100` | `MI` | N = 1 | resultado negativo |
| `0101` | `PL` | N = 0 | resultado não negativo |
| `0110` | `VS` | V = 1 | overflow |
| `0111` | `VC` | V = 0 | sem overflow |
| `1000` | `HI` | C = 1 e Z = 0 | a > b (sem sinal) |
| `1001` | `LS` | C = 0 ou Z = 1 | a ≤ b (sem sinal) |
| `1010` | `GE` | N = V | a ≥ b (com sinal) |
| `1011` | `LT` | N ≠ V | a < b (com sinal) |
| `1100` | `GT` | Z = 0 e N = V | a > b (com sinal) |
| `1101` | `LE` | Z = 1 ou N ≠ V | a ≤ b (com sinal) |
| `1110` | `AL` | sempre | — |
| `1111` | reservado | nunca | sinaliza instrução inválida |

O alvo do desvio é calculado em **palavras**, relativo ao próprio endereço do desvio: `alvo = endereço_do_desvio + 4 × deslocamento`. O campo de deslocamento possui 14 bits e a soma é feita módulo o tamanho da memória de instruções (16384 palavras), de modo que qualquer endereço é alcançável e deslocamentos negativos usam complemento de dois.

## 4.3 Caminho de Controle

### 4.3.1 Unidade de Busca de Instruções

O módulo `unidade_de_busca_de_instrucoes.v` mantém o contador de programa (PC) de 16 bits, que endereça a memória de instruções em bytes e avança de 4 em 4. A memória de instruções fica instanciada dentro da própria unidade de busca. Como a memória possui entrada de endereço e saída registradas, a instrução correta só aparece 2 ciclos após uma mudança do PC, e a unidade insere uma bolha de um ciclo a cada avanço. Por esse motivo, cada instrução simples consome **2 ciclos de clock**.

Para cada instrução, a unidade gera um pulso `execute` de um ciclo, que aciona a unidade de controle. O avanço do PC depende da categoria da instrução:

* **Instruções de um ciclo** (aritméticas, de configuração, `NOP` e desvios): o PC avança imediatamente após o pulso.
* **Instruções de desenho:** o PC permanece parado até o sinal `engine_done` do motor ativo.
* **`WAIT_VBLANK`:** o PC permanece parado até a próxima borda de subida do VBlank.
* **`HALT`:** o programa termina. A unidade ativa `prog_done` e aguarda o VBlank.

Quando `prog_done` está ativo e ocorre o VBlank, a unidade gera o pulso `frame_swap`, que troca os bancos do framebuffer, e reinicia o PC em 0. Esse reinício automático é o que produz o laço de quadros contínuos. O reinício também ocorre após o reset, sem intervenção do usuário, e o botão `KEY[1]` permite reiniciar o programa manualmente.

Os desvios são executados no mesmo ciclo `execute`, com a mesma temporização das demais instruções: a única diferença é que o próximo valor do PC é o alvo do desvio em vez de `PC + 4`. A condição é avaliada pelo módulo combinacional `avalia_condicao.v`, a partir das flags `{C, V, N, Z}` fornecidas pelo banco de registradores. Um desvio tomado na última palavra da memória continua o programa no alvo, e somente o fim da memória sem desvio encerra o programa.

### 4.3.2 Banco de Registradores

O `banco_registradores.v` implementa os registradores descritos na seção 4.2.3, com duas portas de leitura e uma de escrita. Os índices possuem 6 bits. Além dos registradores de propósito geral, o banco mantém as flags, capturadas no término de cada instrução da ULA, e os sete registradores dedicados ao rasterizador, cujas saídas são ligadas diretamente às entradas de vértices e cor do `rasterizador_top`.

### 4.3.3 Unidade Lógica e Aritmética

A `alu.v` executa as operações `ADD`, `SUB`, `AND`, `LSL`, `LSR` e `PASS` sobre operandos de 32 bits. Além do resultado, ela produz as flags N, Z, C e V. A soma e a subtração são calculadas com 33 bits para que o carry e o overflow possam ser obtidos. Na subtração, a ULA calcula `Rn + ~Rm + 1`, de forma que o carry indica ausência de empréstimo, como no ARMv8. Quando a ULA não está habilitada, todas as flags valem 0.

### 4.3.4 Unidade de Controle

A `unidade_de_controle.v` decodifica o opcode da instrução corrente e, ao receber o pulso `execute`, gera os sinais correspondentes:

* para as instruções da ULA, habilita a operação, seleciona o segundo operando (registrador ou imediato), controla a escrita em Rd e a captura das flags;
* para as instruções `SET_*`, `WRITE_*` e `SCROLL_BG`, gera as escritas nas memórias gráficas, nos atributos dos sprites e nos registradores de scroll, a partir dos conteúdos de Ra e Rb;
* para as instruções de desenho, gera o pulso `start` do motor correspondente, mantém o sinal `engine_sel` com o motor selecionado e aguarda o `done` desse motor;
* para `DRAW_RECT` e `DRAW_TRI`, quando o rasterizador rejeita o comando por coordenadas fora da tela (`invalid_cmd`), conclui a instrução sem desenhar e sinaliza o erro.

Opcodes reservados e condições reservadas de `B_COND` são sinalizados como instrução inválida. Essa sinalização é mostrada em `LEDR[2]`, com trava.

## 4.4 Fluxo de Composição e Prioridade entre Camadas

Na primeira etapa, a ordem **fundo → polígonos → sprites** era garantida pelo `compositor.v`, que executava os três motores em sequência fixa. No modelo por instruções, a ordem de desenho passa a ser definida pelo programa, e um `DRAW_BG` ou um `DRAW_RECT` executado depois de um `DRAW_SPRITES` sobrescreveria os sprites no framebuffer. Para manter a hierarquia de camadas independentemente da ordem das instruções, a arquitetura utiliza dois módulos: o `engine_mux`, que seleciona o motor ativo, e a `camada_composicao`, que aplica a prioridade pixel a pixel.

### 4.4.1 Seleção do Motor (`engine_mux`)

O `engine_mux` substitui a função de arbitragem do compositor sequencial. A partir do sinal `engine_sel`, gerado pela unidade de controle, ele conecta ao recurso físico único da paleta e à porta de escrita do framebuffer os sinais do motor que está em execução. Como as instruções de desenho são bloqueantes, apenas um motor está ativo por vez, e a seleção funciona como uma arbitragem simples baseada no estado da instrução corrente.

### 4.4.2 Camada de Composição (`camada_composicao`)

A `camada_composicao` fica entre o `engine_mux` e o framebuffer e impõe a hierarquia de camadas:

| Camada | Elemento | `engine_sel` |
| :---: | :--- | :---: |
| 0 (atrás) | Background | 1 |
| 1 | Polígonos (retângulos e triângulos) | 3 |
| 2 (frente) | Sprites | 2 |

Para cada pixel do banco de escrita, um **mapa de camadas** de 2 bits armazena a camada mais alta que já escreveu naquele pixel durante o quadro atual. Uma escrita só chega ao framebuffer se a sua camada for maior ou igual à registrada no pixel, e, quando passa, atualiza o mapa:

$$\text{camada da escrita} \geq \text{camada registrada no pixel}$$

Disso resultam as seguintes propriedades:

* uma escrita de camada inferior sobre um pixel de camada superior é descartada, de modo que um fundo desenhado depois de um sprite não o cobre;
* escritas da mesma camada se sobrepõem, preservando a ordem de execução entre polígonos: o último `DRAW_RECT` fica por cima dos anteriores;
* pixels transparentes dos sprites (índice 0) não geram escrita e, portanto, não marcam o mapa nem escondem as camadas inferiores;
* a ordem das instruções de desenho deixa de importar entre camadas diferentes.

A camada é implementada como um pipeline de dois estágios, com a camada da escrita registrada junto com o endereço, de modo que ela não depende do `engine_sel` nos estágios seguintes. Escritas em ciclos consecutivos no mesmo pixel são tratadas por encaminhamento (*forwarding*) das escritas ainda em voo, o que elimina o risco de leitura de uma marca desatualizada.

Há um mapa de camadas para cada banco do framebuffer. A limpeza é feita sem custo para o programa: o mapa do banco que está sendo **exibido** não é usado pelos motores, e por isso é zerado por uma varredura de 76800 ciclos (cerca de 1,5 ms) logo após cada troca de bancos. Quando esse banco volta a ser o de escrita, seu mapa já está limpo. Após o reset ou após o reinício manual do programa, os dois mapas são zerados e a unidade de busca é mantida em reset durante essa varredura. O `LEDR[4]` acende, com trava, quando algum pixel é descartado por prioridade, o que indica que o programa desenhou fora da ordem das camadas.

Uma consequência dessa regra é que um retângulo de tela cheia, usado para limpar o quadro, cobre o fundo e os polígonos anteriores, mas não apaga sprites já desenhados no mesmo quadro.

## 4.5 Ciclo de Quadro e Orçamento de Tempo

Um quadro a 60 Hz dura **840 000 ciclos** de 50 MHz. Como o programa de cada quadro é executado em sequência, o tempo total de um quadro é a soma dos custos das instruções. Se o programa terminar antes do VBlank, o quadro aguarda a troca de bancos e a taxa se mantém em 60 quadros por segundo. Se o programa ultrapassar a duração de um quadro, o resultado é exibido no VBlank seguinte e a taxa cai para 30, 20 quadros por segundo e assim por diante. Os custos a seguir foram medidos em simulação do RTL:

| Operação | Custo em ciclos |
| :--- | :--- |
| Instrução simples (aritmética, `SET_*`, desvio) | 2 |
| Retângulo | 1 por pixel + 5 de overhead |
| Triângulo | 1 por pixel + 70 a 300 de overhead (divisão das arestas) |
| `DRAW_BG` | ≈ 543 000 (cerca de 65% do quadro) |
| `DRAW_SPRITES` | ≈ 79 000 (varredura da tela inteira, independente do número de sprites) |

Com o fundo e os sprites desenhados a cada quadro, sobram aproximadamente 219 000 ciclos para polígonos, o que corresponde a cerca de 1 900 retângulos de 10×10 pixels ou 135 retângulos de 40×40 pixels. Em cenas com fundo estático, substituir o `DRAW_BG` por um retângulo de tela cheia reduz o custo de limpeza para cerca de 77 000 ciclos.

## 4.6 Principais Módulos

| Módulo | Função |
| :--- | :--- |
| `coprocessador_top.v` | Integração do sistema: controle, motores, composição, framebuffer e VGA |
| `unidade_de_busca_de_instrucoes.v` | PC, memória de instruções, stall, `HALT`, reinício por VBlank e desvios |
| `avalia_condicao.v` | Avaliação combinacional das condições de `B_COND` |
| `unidade_de_controle.v` | Decodificação, escritas nas memórias, `start`/`done` dos motores e `engine_mux` |
| `banco_registradores.v` | Registradores gerais, flags, `STATUS` e registradores do rasterizador |
| `alu.v` | Operações aritméticas e lógicas, com flags N, Z, C e V |
| `motor_background.v` | Geração da camada de fundo a partir do tilemap, dos padrões e da paleta |
| `motor_sprite.v` | Atributos dos sprites, varredura, transparência, prioridade e espelhamento |
| `rasterizador_top.v` | Interface do rasterizador de retângulos e triângulos, com `invalid_cmd` |
| `camada_composicao.v` | Prioridade entre fundo, polígonos e sprites por mapa de camadas |
| `framebuffer.v` | Dois bancos de pixels com escrita em 50 MHz e leitura em 25 MHz |
| `vga_driver.v` | Temporização VGA, coordenadas do pixel e `vblank_tick` |
| `fb_addr_gen.v` | Conversão `(x, y)` em endereço linear: `y × 320 + x` |

Os motores de background, sprites e rasterização mantêm as características descritas na primeira etapa: o background combina tilemap, padrões e paleta, com deslocamento circular; o motor de sprites trata sprites de 16×16 pixels formados por 4 tiles, com índice 0 transparente, prioridade e espelhamento; e o rasterizador preenche retângulos e triângulos por varredura de linhas, com aritmética inteira. A diferença desta etapa está na forma de acionamento: os parâmetros agora vêm dos registradores e das instruções, e não de módulos auxiliares de demonstração.

## 4.7 Memórias do Sistema

O projeto utiliza **seis RAMs principais**, implementadas como RAMs de porta dupla simples (*simple dual-port RAM*) e geradas pelo IP Catalog do Quartus com a megafunction `altsyncram`: `bg_tile_ram`, `bg_tile_pattern_ram`, `sprite_pattern_ram`, `palette_ram`, `framebuffer_ram` e `instruction_memory`. A porta A é usada para escrita e a porta B para leitura. Cinco delas operam em um único domínio de clock. A exceção é o framebuffer, cuja escrita ocorre a 50 MHz e cuja leitura ocorre a 25 MHz. Além das RAMs, o sistema mantém os atributos dos sprites em registradores internos ao motor de sprites (seção 4.7.3) e utiliza dois mapas de camadas na camada de composição (seção 4.7.8).

### 4.7.1 `bg_tile_ram` — 1200 × 8 bits

Armazena o **tilemap do background**: uma grade de 40×30 tiles, ou seja, 1200 posições. Cada posição guarda um `pattern_id` de 8 bits, que seleciona um dos 256 padrões disponíveis. O endereço é `linha × 40 + coluna`. A escrita ocorre por `SET_TILEMAP`, e o deslocamento do background é feito por enrolamento (*wraparound*).

### 4.7.2 `bg_tile_pattern_ram` — 16384 × 8 bits

Armazena os padrões do background: 256 padrões de 8×8 pixels (256 × 64 = 16384 posições), com um índice de cor de 8 bits por pixel. O endereço é `{tile[7:0], y[2:0], x[2:0]}`. A escrita ocorre por `WRITE_TILE_DATA`.

### 4.7.3 Atributos dos Sprites — 32 entradas

Os atributos dos 32 sprites ficam em **registradores internos ao `motor_sprite`**, e não mais em uma RAM dedicada. A posição é escrita por `SET_SPRITE_POS` e os demais atributos por `SET_SPRITE_ATTR`, sempre entre as varreduras de desenho. Os registradores são zerados no reset, de modo que todos os sprites começam desabilitados e somente aparecem depois que o programa os configura.

| Campo | Bits | Função |
| :--- | ---: | :--- |
| `enable` | 1 | Habilita ou desabilita o sprite |
| `priority` | 5 | Prioridade de sobreposição |
| `flip_v` | 1 | Espelhamento vertical |
| `flip_h` | 1 | Espelhamento horizontal |
| `palette_sel` | 1 | Seleciona o banco da paleta |
| `pattern_index` | 6 | Seleciona o padrão 16×16 |
| `pos_y` | 8 | Posição vertical |
| `pos_x` | 9 | Posição horizontal |

Quando dois sprites ocupam o mesmo pixel, vence o de maior prioridade e, em caso de empate, o de maior índice.

### 4.7.4 `sprite_pattern_ram` — 16384 × 8 bits

Armazena os padrões dos sprites em tiles de 8×8 pixels: 256 tiles, ou seja, 64 padrões de 16×16 pixels. O padrão `P` ocupa os endereços de `P × 256` a `P × 256 + 255`, com o tile obtido por `P × 4 + (y >> 3) × 2 + (x >> 3)`. O índice 0 é reservado para a transparência: o pixel correspondente não é escrito no framebuffer. A escrita ocorre por `WRITE_SPRITE_DATA`.

### 4.7.5 `palette_ram` — 512 × 9 bits

Armazena as cores do sistema em duas paletas de 256 entradas. O endereço é `{palette_sel, color_index}`, e cada entrada guarda uma cor `RRR GGG BBB`. A escrita ocorre por `SET_PALETTE`. A seleção do banco depende do consumidor:

* o **background** lê sempre o banco 0, com endereço `{0, índice}`;
* cada **sprite** escolhe o banco pelo bit `palette_sel` do seu atributo, o que permite usar o mesmo padrão com duas paletas diferentes;
* os **polígonos** escolhem o banco pelo bit 8 do registrador `COLOR`.

Como o background e os sprites compartilham o banco 0, as entradas usadas pelos sprites nesse banco não podem ser alteradas ao compor a paleta do fundo.

### 4.7.6 `framebuffer_ram` — 2 bancos de 76800 × 9 bits

Armazena o resultado da composição. Cada posição guarda uma cor RGB de 9 bits, de modo que não há nova consulta à paleta na leitura para o vídeo. Cada banco possui 320 × 240 = 76800 pixels. Enquanto um banco recebe o próximo quadro, o outro é exibido, e a troca ocorre no VBlank. O framebuffer é a única memória com dois domínios de clock.

### 4.7.7 `instruction_memory` — 16384 × 32 bits

Armazena o programa do coprocessador. Cada palavra é uma instrução de 32 bits, e a capacidade é de 16384 instruções (64 KiB). A memória é inicializada por um arquivo `.mif`, gerado pelo montador a partir do código em linguagem de montagem, e é lida pela unidade de busca com latência de 2 ciclos. As posições além do fim do programa são preenchidas com `NOP`.

### 4.7.8 Mapas de Camadas — 2 × (76800 × 2 bits)

A camada de composição mantém um mapa para cada banco do framebuffer, com 2 bits por pixel, inferidos pelo Quartus em blocos M10K (estimativa de cerca de 19 blocos por mapa). O mapa do banco de escrita é consultado e atualizado a cada escrita de pixel, e o mapa do banco exibido é zerado em segundo plano, como descrito na seção 4.4.2.

## 4.8 Organização do Armazenamento

As memórias possuem funções distintas dentro do sistema:

```text
                        PROGRAMA
                           |
                  instruction_memory
                   (instruções 32 bits)
                           |
                           v
                 UNIDADE DE BUSCA / CONTROLE
                           |
     +----------+----------+-----------+------------+
     |          |          |           |            |
     v          v          v           v            v
 bg_tile_ram  bg_tile_    sprite_    atributos    palette_ram
 (tilemap)    pattern_    pattern_   dos sprites  (512 x 9)
              ram         ram        (registr.)
     |          |          |           |            |
     +----+-----+          +-----+-----+            |
          |                      |                  |
          v                      v                  |
   motor_background         motor_sprite            |
          |                      |                  |
          +---> índice de cor <--+                  |
                     |                              |
                     +------------>-----------------+
                                   |
                                   v
                            cor RGB (9 bits)

   BACKGROUND ─┐
   POLÍGONOS  ─┼─► ENGINE_MUX ─► CAMADA DE COMPOSIÇÃO ─► FRAMEBUFFER
   SPRITES    ─┘                  (2 mapas de camadas)    Banco 0 | Banco 1
                                                                  |
                                                            Double Buffer
                                                                  |
                                                                  v
                                                             Controlador VGA
```

Essa organização mantém separadas as informações de **programa**, **descrição da cena**, **dados gráficos**, **cores** e **imagem final**. O programa define o que é configurado e desenhado, os motores acessam apenas as memórias de que precisam, e o framebuffer funciona como ponto de convergência das camadas, após a aplicação da prioridade pela camada de composição.


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

O processo de projeto e implementação do co-processador gráfico seguiu uma abordagem ascendente (*bottom-up*) e foi dividido em duas etapas. Na **primeira etapa** (seções 6.1 a 6.7), partiu-se dos módulos de menor nível (sinalização física de vídeo) até a composição final do pipeline gráfico e a integração no *top-level* da FPGA DE1-SoC. Na **segunda etapa** (seções 6.8 a 6.16), o núcleo gráfico passou a ser comandado por um programa: foram definidos um conjunto de instruções, o caminho de controle que o executa e as garantias de composição e de controle de fluxo necessárias para o desenvolvimento de animações.

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
* **Evolução na segunda etapa:** A hierarquia de camadas deixou de depender da execução sequencial do compositor e passou a ser garantida pela camada de composição descrita na seção 6.12.

---

## 6.7 Integração no Top-Level e Validação Física

Finalização da descrição em Verilog e teste direto na plataforma de prototipagem:

* **Interconexão de Módulos:** Conexão de todas as unidades internas ao módulo *top-level* do projeto no Quartus Prime.
* **Interface Hardware de Validação:** Mapeamento temporário de sinais de controle nas chaves (*SW*), botões (*KEY*) e LEDs da placa **DE1-SoC**, permitindo a alternância de *buffers*, scroll manual de background, disparo de comandos do rasterizador e controle de visibilidade de sprites diretamente no monitor VGA durante a apresentação do protótipo.

---

## 6.8 Definição da ISA e do Modelo de Execução

A segunda etapa começou pela definição de como o coprocessador seria comandado. Em vez de módulos auxiliares gerando comandos fixos, optou-se por uma unidade de controle que executa um programa armazenado em memória, o que torna a cena programável sem alterar o hardware:

* **Conjunto de Instruções de 32 Bits:** Definição de um conjunto pequeno, com quatro formatos (ULA, configuração de memórias, instruções sem operandos e desvios), documentado em um documento de especificação da ISA. A numeração dos registradores e as condições de desvio seguem a convenção do ARMv8/LEGv8.
* **Registradores Dedicados ao Rasterizador:** Os vértices e a cor das primitivas ocupam registradores de endereços 37 a 43 (`V0X` a `COLOR`), ligados diretamente ao rasterizador. Dessa forma, os parâmetros de desenho são escritos por instruções comuns da ULA, sem barramento adicional.
* **Instruções de Desenho Bloqueantes:** As instruções `DRAW_*` seguram o contador de programa até o término do motor, de modo que os motores nunca disputam o framebuffer nem a paleta.
* **Ciclo de Quadro por Programa:** O `HALT` marca o fim do programa de um quadro. A troca de bancos e o reinício do programa ocorrem no VBlank, e os registradores são preservados, o que permite manter estado entre quadros, requisito central para animações.
* **Espaço de Opcodes Reservado:** Os opcodes ainda livres foram reservados para extensões futuras, como instruções de acesso à memória e chamada de sub-rotinas.

---

## 6.9 Banco de Registradores e ULA

Implementação do núcleo de dados do caminho de controle:

* **Banco de Registradores:** Registradores de propósito geral (`R0` a `R30`), registrador zero (`XZR`), registrador de estado (`STATUS`), registrador de flags (`FLAGS`) e os sete registradores do rasterizador, com duas portas de leitura e uma de escrita e índices de 6 bits.
* **ULA:** Operações `ADD`, `SUB`, `AND`, `LSL`, `LSR` e `PASS` sobre 32 bits. A soma e a subtração são calculadas com 33 bits para que o carry e o overflow possam ser extraídos.
* **Flags N, Z, C e V:** O desenvolvimento começou com as flags N e Z. Ao implementar os desvios (seção 6.13), foram acrescentadas as flags C e V, necessárias para comparações corretas com e sem sinal. No `SUB`, o carry indica ausência de empréstimo, como no ARMv8.
* **Comparação sem Destino:** O uso de `XZR` como destino permite que `SUB XZR, Rn, Rm` funcione como uma instrução de comparação, que atualiza apenas as flags.

---

## 6.10 Unidade de Busca de Instruções e Unidade de Controle

Desenvolvimento dos módulos que executam o programa:

* **Memória de Instruções e Latência:** A memória de instruções possui entrada de endereço e saída registradas, o que gera uma latência de leitura de 2 ciclos. A unidade de busca insere uma bolha de um ciclo a cada avanço do contador de programa, resultando em 2 ciclos por instrução simples.
* **Unidade de Busca:** Contador de programa de 16 bits, pulso `execute` de um ciclo por instrução, parada (*stall*) durante instruções de desenho e `WAIT_VBLANK`, `HALT`, reinício automático por VBlank e reinício manual por botão.
* **Tratamento de Instruções Inválidas:** Opcodes reservados são tratados como `NOP` e sinalizados.
* **Unidade de Controle:** Decodificação do opcode, controle da ULA e das escritas no banco de registradores, escritas nas memórias gráficas (paleta, tilemap, padrões, atributos de sprites e scroll) e geração de `start` e `done` dos motores.
* **Seleção do Motor Ativo:** O módulo `engine_mux`, definido junto à unidade de controle, conecta ao framebuffer e à paleta o motor indicado por `engine_sel`.

---

## 6.11 Integração no `coprocessador_top`

Substituição do top-level da primeira etapa por um novo módulo de integração:

* **Remoção dos Módulos Auxiliares:** O `coprocessador_top` substitui o `top_video`, o `test_driver` e o `sprite_mover_flip`. As portas externas de escrita nas memórias deixaram de existir, e a configuração passou a ser feita pelo programa.
* **Componentes Reaproveitados:** PLL, controlador VGA, framebuffer com double buffering, memórias de background, de padrões de sprites e de paleta, e os três motores de renderização foram mantidos.
* **Memória de Instruções:** Nova RAM de 16384 × 32 bits, inicializada por arquivo `.mif` gerado pelo montador.
* **Atributos dos Sprites em Registradores:** Os atributos passaram a ser mantidos em registradores internos ao `motor_sprite`, escritos por `SET_SPRITE_POS` e `SET_SPRITE_ATTR`, e a `sprite_attribute_ram` deixou de ser utilizada. Todos os sprites começam desabilitados após o reset.
* **Controles da Placa:** `KEY[0]` realiza o reset, sincronizado por dois estágios de registradores, e `KEY[1]` reinicia o programa na borda de descida, sem *debounce*. `LEDR[0]` indica programa em execução, `LEDR[1]` indica espera por motor ou VBlank, `LEDR[2]` indica erro (com trava), `LEDR[3]` indica PLL travado e `LEDR[4]` indica que algum pixel foi descartado por prioridade (com trava).
* **Seleção do Top-Level:** Para sintetizar esta versão, o `coprocessador_top` deve ser definido como *top-level entity* do projeto Quartus.

---

## 6.12 Prioridade entre Camadas (Camada de Composição)

Com o desenho comandado por instruções, identificou-se um problema: a hierarquia **fundo → polígonos → sprites** deixou de ser garantida. Na primeira etapa ela era consequência da execução sequencial do compositor, mas no modelo por instruções a ordem é a do programa, e um `DRAW_BG` executado depois de um `DRAW_SPRITES` apagava os sprites:

* **Alternativa Avaliada:** Reaproveitar o compositor sequencial, executando as camadas em ordem fixa ao final do quadro. A alternativa foi descartada porque faria os desenhos ocorrerem somente após o `HALT`, com o estado final do quadro: programas que alteram a paleta, os atributos dos sprites ou o scroll entre duas instruções de desenho passariam a produzir resultados diferentes dos esperados.
* **Solução Adotada:** Módulo `camada_composicao`, entre o `engine_mux` e o framebuffer. Um mapa de 2 bits por pixel registra a camada mais alta que já escreveu em cada pixel do quadro, e uma escrita só é aceita se a sua camada for maior ou igual à registrada. Os desenhos continuam imediatos e bloqueantes, preservando a semântica da ISA.
* **Pipeline com *Forwarding*:** A camada é implementada em dois estágios, com a camada da escrita registrada junto com o endereço. Escritas em ciclos consecutivos no mesmo pixel são tratadas por encaminhamento, sem risco de leitura de marcas desatualizadas.
* **Limpeza dos Mapas sem Custo para o Programa:** Cada banco do framebuffer possui o seu mapa. O mapa do banco exibido, que não é usado pelos motores, é zerado em segundo plano após cada troca de bancos. Após o reset ou o reinício manual, os dois mapas são zerados e a busca fica em reset durante essa varredura.
* **Diagnóstico em Hardware:** `LEDR[4]` acende, com trava, quando algum pixel é descartado por prioridade.
* **Verificação:** Testbench unitário, testbench com os motores reais desenhando a mesma cena em quatro ordens diferentes e simulação do `coprocessador_top` completo com um programa em ordem invertida. Na ordem invertida e sem a camada, 1600 pixels da cena de teste saíam errados (o fundo cobrindo o retângulo e o sprite); com a camada, o quadro foi idêntico ao da ordem correta em todos os cenários.

---

## 6.13 Desvios Condicionais e Flags

Para tornar viável a programação de animações, foram acrescentadas instruções de controle de fluxo:

* **Motivação:** Sem desvios, o programa é linear e não consegue limitar a posição de um objeto, inverter sua velocidade ao atingir uma borda, repetir um desenho em laço ou distinguir o primeiro quadro dos demais.
* **Instruções `B` e `B_COND`:** Desvio incondicional e desvio condicional com as condições do LEGv8 (`EQ`, `NE`, `HS`, `LO`, `MI`, `PL`, `VS`, `VC`, `HI`, `LS`, `GE`, `LT`, `GT`, `LE` e `AL`), implementadas no módulo combinacional `avalia_condicao`.
* **Deslocamento Relativo:** Deslocamento de 14 bits, em palavras, relativo ao endereço do desvio e somado módulo o tamanho da memória de instruções, de modo que qualquer endereço é alcançável.
* **Mesma Temporização das Demais Instruções:** O desvio executa no ciclo `execute`, alterando apenas o próximo valor do contador de programa. A unidade de controle não precisou ser modificada.
* **Desvio na Última Palavra:** O fim da memória sem desvio encerra o programa, mas um desvio tomado na última palavra continua a execução no alvo.
* **Flags V e C:** Acrescentadas à ULA para que as comparações com sinal (`LT`, `GE`, `GT`, `LE`) e sem sinal (`HS`, `LO`, `HI`, `LS`) sejam corretas, inclusive nos casos de overflow.
* **Padrão de Uso:** A comparação é feita com `SUB XZR, Rn, Rm` (ou imediato) imediatamente antes do desvio, já que toda instrução da ULA atualiza as flags.

---

## 6.14 Ferramentas de Apoio

Foram desenvolvidas ferramentas para escrever, converter e validar programas e dados:

* **Montador (`montador.py`):** Converte código em linguagem de montagem para os arquivos `.mif`, `.hex` e `.lst`. Foi estendido com *labels* (`nome:`), `B` e `B.cond` com *label* ou deslocamento literal, codificação do registrador destino com 6 bits e nomes simbólicos (`V0X` a `COLOR`, `XZR`, `FLAGS`). A saída para programas escritos na sintaxe anterior permaneceu idêntica.
* **Conversores de Imagem para `.mif`:** Scripts que transformam imagens em dados de background (mapa de tiles, padrões e paleta) e em padrões de sprite. A conversão respeita as restrições do hardware: no máximo 256 tiles distintos de $8 \times 8$ pixels no fundo, cores RGB de 3 bits por canal e preservação das entradas da paleta usadas pelos sprites, que compartilham o banco 0 com o background.
* **Simulador em Navegador (`simulador_isa.html`):** Arquivo único que monta o programa, executa as instruções já codificadas, desenha em um framebuffer de $320 \times 240$ com a prioridade entre camadas e exibe registradores, flags e a memória de instruções, com execução passo a passo, por quadro e contínua. Carrega os `.mif` de paleta, tilemap e padrões. É um modelo funcional: não reproduz a temporização do hardware e trata `WAIT_VBLANK` como instrução sem espera.
* **Geradores de Programas de Teste:** Scripts que montam programas curtos para os testes de sistema.

---

## 6.15 Programas de Demonstração

Programas escritos em linguagem de montagem para exercitar o sistema:

* **Retângulo que quica (`animacao_quicando.asm`):** Mantém posição e velocidade em registradores que persistem entre quadros, usa um desvio para a inicialização no primeiro quadro, desvios condicionais para os limites e um laço com contador que desenha quatro quadrados em cada quadro.
* **Fundo e sprites (`demo_programa`):** Desenha o fundo, um quadrado e um triângulo, e movimenta um sprite que é espelhado a cada vez que atinge uma borda: borda lateral inverte `flip_h` e borda superior ou inferior inverte `flip_v`.
* **Dois bancos de paleta:** Segundo sprite que usa o banco 1 da paleta, e sprites estáticos no centro da tela, um de cada padrão.
* **Teste de cores (`teste_cores`):** Barras de cores saturadas e rampa de cinzas, definidas pelo próprio programa, para isolar o caminho de vídeo do conteúdo dos arquivos `.mif`.

---

## 6.16 Verificação e Medições da Segunda Etapa

A verificação desta etapa combinou testes unitários, de integração e de sistema, executados no Icarus Verilog:

* **ULA e Condições (`tb_condicoes_desvio`):** Para pares de valores de borda e aleatórios, verifica as 16 condições após `SUB` e as flags C e V de `ADD`, comparando com aritmética de 64 bits (469 200 verificações). Defeitos introduzidos de propósito na ULA e no avaliador de condições foram todos detectados.
* **Camada de Composição (`tb_camada_composicao`):** Escritas roteirizadas cobrindo sprite antes do fundo, sobreposição na mesma camada, escritas em ciclos consecutivos, troca de bancos, reinício manual e escritas durante a limpeza. Defeitos introduzidos de propósito (sem *forwarding*, sem o teste de prioridade, sem a varredura de limpeza e sem o descarte durante a inicialização) foram todos detectados.
* **Integração com Motores Reais (`tb_composicao_ordem_desenho`):** Background, sprite e rasterizador reais desenham a mesma cena em quatro ordens diferentes, e o quadro final é comparado com o esperado.
* **Sistema Completo (`tb/sim_top`):** Simulação do `coprocessador_top` completo, com modelos comportamentais para o PLL e as RAMs do Quartus, executando programas reais. Um *script* de testes cobre laço de soma, desvios para frente e para trás, as 15 condições em 6 pares de valores, desvio na última palavra com volta da memória, condição reservada e a animação do retângulo que quica durante 7 quadros.
* **Medição de Custos:** Custo de instruções, de desenho e de quadro medidos no RTL, resumidos na seção 4.5.
* **Limitação:** Os testes de sistema usam modelos comportamentais no lugar das IPs do Quartus e, por isso, não substituem a síntese, a análise de timing nem a validação em hardware.



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



