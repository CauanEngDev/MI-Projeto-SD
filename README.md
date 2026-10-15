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
  * [2.3 Requisitos de Memória e Organização Interna](#23-requisitos-de-memória-e-organização-interna)

* [3. Fundamentação Teórica](#3-fundamentação-teórica)
  * [3.1 Arquitetura de Conjunto de Instruções (ISA)](#31-arquitetura-de-conjunto-de-instruções-isa)
  * [3.2 Arquitetura do Coprocessador Gráfico](#32-arquitetura-do-coprocessador-gráfico)
  * [3.3 Unidade de Busca de Instruções e Contador de Programa](#33-unidade-de-busca-de-instruções-e-contador-de-programa)
  * [3.4 Unidade de Controle e Decodificação](#34-unidade-de-controle-e-decodificação)
  * [3.5 Registrador de Instrução e Datapath](#35-registrador-de-instrução-e-datapath)
  * [3.6 Banco de Registradores](#36-banco-de-registradores)
  * [3.7 Unidade Lógica e Aritmética (ULA)](#37-unidade-lógica-e-aritmética-ula)
  * [3.8 Memórias de Instruções e de Dados Gráficos](#38-memórias-de-instruções-e-de-dados-gráficos)
  * [3.9 Representação de Cores por Índices e Paletas](#39-representação-de-cores-por-índices-e-paletas)
  * [3.10 Background Baseado em Tiles](#310-background-baseado-em-tiles)
  * [3.11 Sprites e Atributos Gráficos](#311-sprites-e-atributos-gráficos)
  * [3.12 Rasterização de Primitivas Geométricas](#312-rasterização-de-primitivas-geométricas)
  * [3.13 Compositor e Prioridade entre Camadas](#313-compositor-e-prioridade-entre-camadas)
  * [3.14 Framebuffer e Double Buffering](#314-framebuffer-e-double-buffering)
  * [3.15 Controlador VGA e Resolução de Vídeo](#315-controlador-vga-e-resolução-de-vídeo)
  * [3.16 FPGA e Descrição de Hardware em Verilog](#316-fpga-e-descrição-de-hardware-em-verilog)

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

* [5. Especificação de Hardware e Software](#5-especificação-de-hardware-e-software)
  * [5.1 Hardware](#51-hardware)
  * [5.2 Software e Ferramentas de Desenvolvimento](#52-software-e-ferramentas-de-desenvolvimento)
    * [5.2.1 Montador e Gerador de Programas](#521-montador-e-gerador-de-programas)
    * [5.2.2 Simulador HTML da ISA](#522-simulador-html-da-isa)
    * [5.2.3 Ferramentas de Conversão de Imagens e Visualização de Memórias](#523-ferramentas-de-conversão-de-imagens-e-visualização-de-memórias)
  * [5.3 Arquivos de Inicialização das Memórias](#53-arquivos-de-inicialização-das-memórias)


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
  * [8.1 Testes por Simulação em Verilog](#81-testes-por-simulação-em-verilog)
  * [8.2 Simulador HTML da ISA](#82-simulador-html-da-isa)
  * [8.3 Testes com Programas Assembly](#83-testes-com-programas-assembly)
  * [8.4 Montagem de Instruções e Geração de Arquivos `.mif`](#84-montagem-de-instruções-e-geração-de-arquivos-mif)
  * [8.5 Testes do Rasterizador de Quadrados](#85-testes-do-rasterizador-de-quadrados)
  * [8.6 Testes do Rasterizador de Triângulos](#86-testes-do-rasterizador-de-triângulos)
  * [8.7 Testes do Motor de Background](#87-testes-do-motor-de-background)
  * [8.8 Testes do Motor de Sprites](#88-testes-do-motor-de-sprites)
    * [8.8.1 Transparência](#881-transparência)
    * [8.8.2 Espelhamento](#882-espelhamento)
    * [8.8.3 Prioridade entre Sprites](#883-prioridade-entre-sprites)
  * [8.9 Testes do Framebuffer e da Composição Gráfica](#89-testes-do-framebuffer-e-da-composição-gráfica)
  * [8.10 Testes de Integração e Desvios](#810-testes-de-integração-e-desvios)
  * [8.11 Testes na FPGA DE1-SoC](#811-testes-na-fpga-de1-soc)
  * [8.12 Erros, Limitações e Decisões de Projeto](#812-erros-limitações-e-decisões-de-projeto)


* [9. Análise do Resultado](#9-análise-do-resultado)

  * [9.1 Resultados de Simulação](#91-resultados-de-simulação)
  * [9.2 Resultados da Demonstração em Hardware](#92-resultados-da-demonstração-em-hardware)
  * [9.3 Atendimento aos Requisitos](#93-atendimento-aos-requisitos)
  * [9.4 Recursos, Timing e Desempenho](#94-recursos-timing-e-desempenho)
  * [9.5 Gargalos e Limitações](#95-gargalos-e-limitações)
  * [9.6 Melhorias Possíveis](#96-melhorias-possíveis)
  * [9.7 Funcionalidades Não Atendidas](#97-funcionalidades-não-atendidas)

* [10. Equipe do Desenvolvimento](#10-equipe-do-desenvolvimento)

* [11. Referências](#11-referências)

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
| **RF03** | **Registrador de Instrução (IR)** | Armazenamento e disponibilização da instrução para decodificação e execução. | **VALIDADO** — correspondência existente com o requisito de IR no datapath integrado. |
| **RF04** | **Unidade de Controle** | Decodificação dos opcodes e geração dos sinais de controle para a ULA, o banco de registradores, as memórias e os motores gráficos. | **IMPLEMENTADO NO RTL** |
| **RF05** | **Datapath** | Integração do banco de registradores, ULA, unidade de busca, controle e unidades funcionais. | **IMPLEMENTADO NO RTL** |
| **RF06** | **Banco de Registradores** | Armazenamento de operandos gerais, flags e registradores dedicados às coordenadas dos vértices e à cor do rasterizador. | **IMPLEMENTADO NO RTL** |
| **RF07** | **Registradores de Estado** | Disponibilização de informações de estado do coprocessador e das flags utilizadas nas operações e nos desvios condicionais. | **IMPLEMENTADO NO RTL** |
| **RF08** | **Unidade Lógica e Aritmética (ULA)** | Execução das operações `ADD`, `SUB`, `AND`, `LSL`, `LSR` e `PASS`, com geração das flags utilizadas pelos desvios. | **IMPLEMENTADO NO RTL** |
| **RF09** | **Programa Gráfico em Assembly da ISA Própria** | Programa de demonstração codificado para a ISA criada pela equipe e armazenado na memória interna de instruções. | **SUPORTE PRESENTE** — implementado também por um simulador em html. |
| **RF10** | **Definição da Sintaxe da ISA** | Documentação dos formatos de instrução, operandos, campos de codificação, opcodes e regras de execução. | **DOCUMENTAÇÃO PRESENTE** — conferir se a versão final está incluída e atualizada no repositório. |
| **RF11** | **Motor de Background** | Geração do plano de fundo a partir de um mapa de tiles e de uma memória de padrões gráficos. | **IMPLEMENTADO NO RTL** |
| **RF12** | **Motor de Sprites** | Renderização de até 32 sprites, com posição, habilitação, padrão, seleção de paleta, prioridade e espelhamento horizontal e vertical. | **IMPLEMENTADO NO RTL** — comportamentos por simulação e hardware validados. |
| **RF13** | **Rasterizador de Polígonos** | Rasterização de retângulos preenchidos e triângulos, acionada por instruções da ISA. | **IMPLEMENTADO NO RTL** |
| **RF14** | **Compositor Gráfico** | Composição das camadas com prioridade entre background, rasterizadores e sprites. | **IMPLEMENTADO NO RTL** |
| **RF15** | **Controlador VGA** | Geração dos sinais de vídeo para saída VGA de 640 × 480 pixels, a partir da imagem lógica de 320 × 240 pixels. | **IMPLEMENTADO NO RTL** |
| **RF16** | **Sincronização com VGA** | Utilização do `vblank` para sincronização do quadro e troca dos bancos do framebuffer. | **IMPLEMENTADO NO RTL** |
| **RF17** | **Comunicação entre Unidades Funcionais** | Uso de sinais de controle, incluindo `busy`, `done` e sinais de início de operação, conforme a unidade acionada. | **IMPLEMENTADO NO RTL** — a validação dos protocolos deve ser documentada pelos testes. |
| **RF18** | **Memória Interna de Instruções** | Armazenamento do programa gráfico em memória de 16.384 palavras de 32 bits, configurada para inicialização por arquivo de memória. | **IMPLEMENTADO NO RTL** |
| **RF19** | **Testbenches dos Módulos Principais** | O enunciado exige testes para cada módulo principal. O repositório contém testbenches para diversos módulos e comportamentos específicos. | **PARCIALMENTE DOCUMENTADO** |
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




# 3. FUNDAMENTAÇÃO TEÓRICA

A fundamentação teórica deste projeto aborda os conceitos de arquitetura de computadores, sistemas digitais e computação gráfica utilizados no desenvolvimento de um coprocessador gráfico programável em FPGA. Diferentemente de um sistema em que os módulos gráficos precisam ser acionados individualmente por sinais externos, um coprocessador programável permite descrever operações por meio de instruções de uma arquitetura de conjunto de instruções (*Instruction Set Architecture* — ISA).

O projeto tem como objetivo integrar os mecanismos de geração gráfica desenvolvidos anteriormente a uma arquitetura capaz de buscar e executar instruções, manipular registradores e acionar unidades funcionais especializadas. Essa organização aproxima o coprocessador dos princípios empregados na construção de processadores convencionais, adaptando-os às necessidades de geração e composição de imagens.

A implementação utiliza Verilog para descrever os circuitos digitais e uma FPGA para executar a lógica projetada. O sistema reúne uma unidade de busca de instruções, uma unidade de controle, um banco de registradores, uma Unidade Lógica e Aritmética (ULA), mecanismos de controle de fluxo e unidades funcionais gráficas, incluindo os motores de background, sprites e rasterização. Os resultados dessas operações são encaminhados ao sistema de composição e ao controlador VGA.

Além da implementação em hardware, o projeto conta com uma especificação própria da ISA, programas Assembly, ferramentas de montagem e geração de arquivos de inicialização de memória e um simulador HTML utilizado para acompanhar a execução das instruções e seus efeitos gráficos.

Os conceitos apresentados a seguir fundamentam as decisões de organização do sistema e explicam a relação entre o programa executado, o processamento digital e a imagem produzida.

## 3.1 Arquitetura de Conjunto de Instruções (ISA)

A arquitetura de conjunto de instruções, conhecida pela sigla ISA (*Instruction Set Architecture*), define a interface entre o software e o hardware de um processador. Ela especifica as operações disponíveis, os formatos das instruções, os registradores acessíveis, os operandos utilizados e as regras que determinam o comportamento de cada operação.

Uma ISA estabelece, portanto, o contrato funcional que deve ser respeitado tanto pelos programas quanto pela implementação em hardware. Um programa escrito para uma determinada arquitetura precisa utilizar instruções compatíveis com os formatos e as operações definidos por ela (PATTERSON; HENNESSY, 2016).

No projeto, foi definida uma ISA própria para o coprocessador gráfico, com instruções de largura fixa de 32 bits e campo de código de operação (*opcode*) de 5 bits. Esse campo permite representar até \(2^5 = 32\) códigos distintos, embora nem todas as combinações precisem corresponder a instruções implementadas.

A arquitetura adota um modelo de utilização de registradores para operações aritméticas e lógicas, enquanto as instruções específicas acionam funcionalidades gráficas. Assim, o programa pode preparar valores em registradores e utilizá-los em operações da ULA ou em comandos relacionados à geração de imagens.

Entre as instruções definidas na especificação do projeto estão:

- **Operações da ULA:** instruções como `ADD`, `SUB` e `PASS`, utilizadas para realizar operações aritméticas, lógicas ou transferir valores;
- **Configuração gráfica:** instruções como `SET_PALETTE`, `SET_SPR_POS` e `SET_SPR_ATTR`;
- **Desenho de primitivas:** instruções como `DRAW_RECT` e `DRAW_TRI`;
- **Manipulação de recursos gráficos:** instruções como `SET_TILEMAP`, `WRITE_SPRITE_DATA` e `WRITE_TILE_DATA`;
- **Controle da execução:** instruções como `WAIT_VBLANK` e `HALT`;
- **Controle de fluxo:** instruções de desvio, incluindo `B` e `B_COND`.

Essas instruções permitem que um programa descreva uma sequência de operações gráficas sem precisar controlar diretamente, em cada etapa, todos os sinais internos dos motores.

O fluxo conceitual de execução pode ser representado por:

    PROGRAMA ASSEMBLY
           |
           v
    CODIFICAÇÃO DAS INSTRUÇÕES
           |
           v
    MEMÓRIA DE INSTRUÇÕES
           |
           v
    BUSCA E DECODIFICAÇÃO
           |
           v
    EXECUÇÃO NO COPROCESSADOR
           |
           v
    RESULTADO GRÁFICO

A definição da ISA é importante porque organiza a comunicação entre o programa e o hardware, tornando possível testar as instruções individualmente e verificar como elas se combinam para produzir operações gráficas mais complexas.

## 3.2 Arquitetura do Coprocessador Gráfico

Um coprocessador é uma unidade de processamento especializada em determinadas classes de operações. Em vez de executar todas as tarefas de um processador de propósito geral, ele concentra recursos de hardware nas funções para as quais foi projetado.

No presente projeto, essa especialização está relacionada à geração e à composição de imagens. A arquitetura reúne unidades de processamento convencionais, responsáveis pela execução das instruções, e unidades funcionais gráficas, responsáveis por produzir os elementos visuais.

A organização pode ser resumida da seguinte forma:

    +-----------------------------+
    |     MEMÓRIA DE INSTRUÇÕES   |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   UNIDADE DE BUSCA          |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   UNIDADE DE CONTROLE       |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   BANCO DE REGISTRADORES    |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   ULA E DATAPATH            |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   UNIDADES GRÁFICAS         |
    |   Background, Sprites,      |
    |   Rasterização              |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   COMPOSIÇÃO E FRAMEBUFFER  |
    +-----------------------------+
                  |
                  v
    +-----------------------------+
    |   CONTROLADOR VGA           |
    +-----------------------------+

O diagrama apresenta a organização conceitual do sistema. Na implementação, os caminhos de dados e os sinais de controle conectam os módulos de acordo com as interfaces definidas no código Verilog.

A principal característica dessa arquitetura é que as operações gráficas passam a ser comandadas por instruções da ISA. O programa configura parâmetros, prepara os dados necessários e solicita operações às unidades funcionais, enquanto o hardware realiza o processamento correspondente.

Essa organização permite separar a interpretação do programa da execução das operações gráficas, facilitando a evolução da arquitetura e a validação de seus componentes.

## 3.3 Unidade de Busca de Instruções e Contador de Programa

A unidade de busca de instruções é responsável por obter as instruções que serão executadas pelo coprocessador. Para isso, ela utiliza uma memória de instruções e um contador de programa (*Program Counter* — PC), que identifica a posição da próxima instrução a ser buscada.

Na implementação do projeto, a busca é ativa: o próprio coprocessador obtém as instruções de uma memória interna, inicializada por um arquivo de configuração. Essa decisão permite executar programas sem depender de um processador externo para enviar cada comando individualmente.

A memória de instruções possui 16384 palavras de 32 bits. Considerando a largura das instruções, sua capacidade nominal é:

\[
16384 \times 32 = 524288 \text{ bits}
\]

Isso corresponde a 65536 bytes, ou 64 KiB.

O contador de programa utilizado na arquitetura possui 16 bits e trabalha com endereçamento em bytes. Como as instruções possuem 32 bits, cada instrução ocupa quatro bytes. Na execução sequencial, o endereço do PC avança em quatro unidades, salvo quando uma instrução de controle de fluxo determina outro destino.

O processo pode ser representado por:

    +-------------------+
    | CONTADOR DE       |
    | PROGRAMA (PC)     |
    +-------------------+
              |
              v
    +-------------------+
    | MEMÓRIA DE        |
    | INSTRUÇÕES        |
    +-------------------+
              |
              v
       INSTRUÇÃO LIDA
              |
              v
       EXECUÇÃO DA ISA
              |
              v
      ATUALIZAÇÃO DO PC

Quando ocorre um desvio, o próximo endereço deixa de corresponder necessariamente à instrução seguinte. No caso de um desvio incondicional, o fluxo é direcionado ao destino especificado; em um desvio condicional, essa alteração depende da condição avaliada pela arquitetura.

A unidade de busca é, portanto, fundamental para transformar um conjunto de instruções armazenado em memória em uma sequência ordenada de operações executadas pelo hardware.

## 3.4 Unidade de Controle e Decodificação

A unidade de controle coordena a execução das instruções. Sua função consiste em interpretar o código de operação e os demais campos relevantes da instrução, determinando quais operações devem ocorrer e quais sinais precisam ser ativados.

Em uma arquitetura digital, a unidade de controle deve considerar não apenas o tipo da instrução, mas também o estado atual do sistema. Operações que envolvem unidades gráficas podem exigir vários ciclos de clock, enquanto outras podem ser concluídas em menos tempo.

Por esse motivo, a execução de uma instrução não se resume necessariamente a um único ciclo. A unidade de controle pode precisar aguardar a conclusão de uma operação, observar sinais de estado e somente então permitir o avanço para a próxima instrução.

No projeto, a ISA inclui instruções de controle como `WAIT_VBLANK` e `HALT`, além de instruções que acionam recursos gráficos. Essas operações possuem finalidades diferentes: enquanto uma instrução pode configurar dados, outra pode solicitar uma operação gráfica, aguardar uma condição de sincronização ou encerrar a execução do programa.

O funcionamento geral da decodificação pode ser representado por:

    INSTRUÇÃO DE 32 BITS
             |
             v
    +----------------------+
    | EXTRAÇÃO DOS CAMPOS  |
    +----------------------+
             |
             v
    +----------------------+
    | DECODIFICAÇÃO DO     |
    | OPCODE E OPERANDOS   |
    +----------------------+
             |
             v
    +----------------------+
    | GERAÇÃO DOS SINAIS   |
    | DE CONTROLE          |
    +----------------------+
             |
             v
    EXECUÇÃO DA OPERAÇÃO

A unidade de controle também precisa considerar o término das operações e as condições de sincronização. Esse gerenciamento é importante porque os motores gráficos não necessariamente concluem suas tarefas no mesmo número de ciclos.

Conceitos como `busy`, `done` e `valid` são úteis nesse contexto. De maneira geral, `busy` indica que uma unidade está ocupada, `done` sinaliza a conclusão de uma operação e `valid` pode indicar que uma informação ou solicitação é válida. A utilização exata desses sinais depende da interface implementada em cada módulo.

## 3.5 Registrador de Instrução e Datapath

O registrador de instrução (*Instruction Register* — IR) é um elemento utilizado em arquiteturas de processadores para manter a instrução atualmente selecionada para execução. Sua função conceitual é separar a obtenção da instrução de seu processamento, mantendo os bits da instrução disponíveis para a decodificação e o controle.

O datapath, por sua vez, corresponde ao conjunto de componentes e caminhos pelos quais os dados são armazenados, selecionados, transformados e encaminhados durante a execução das instruções. Ele pode incluir registradores, ULA, multiplexadores, extensores de operandos e conexões entre unidades funcionais.

Esses conceitos são complementares: a unidade de controle determina o que deve ser feito, enquanto o datapath fornece os recursos utilizados para realizar as operações.

No coprocessador gráfico, o datapath precisa permitir a manipulação dos operandos da ISA e a preparação dos parâmetros utilizados pelas unidades gráficas. Por exemplo, coordenadas e valores de cor podem ser calculados ou transferidos por instruções da ULA antes de serem utilizados pelo rasterizador.

É importante distinguir o papel arquitetural do IR da existência de um módulo independente com esse nome. A presença de uma instrução buscada e decodificada não comprova, isoladamente, que todos os requisitos de armazenamento explícito da instrução estejam implementados em um registrador dedicado. Essa distinção deve ser considerada ao descrever a implementação concreta do projeto.

## 3.6 Banco de Registradores

Um banco de registradores é um conjunto de posições de armazenamento de pequena capacidade utilizadas para manter operandos e resultados temporários durante a execução das instruções. Em comparação com memórias maiores, os registradores permitem acesso rápido aos dados necessários às operações do processador.

No projeto, a especificação da ISA descreve um espaço de registradores numerados, com registradores gerais e posições reservadas para funções específicas. Os registradores gerais são utilizados como operandos da ULA, enquanto alguns registradores possuem associação direta com os recursos gráficos.

Entre os registradores especiais descritos na especificação estão:

- `XZR`: registrador de valor zero;
- `STATUS`: conjunto de indicadores de estado, incluindo informações relacionadas à execução e à sincronização;
- `FLAGS`: registrador de indicadores aritméticos e lógicos;
- `V0X`, `V0Y`, `V1X`, `V1Y`, `V2X` e `V2Y`: registradores associados às coordenadas dos vértices utilizados pelo rasterizador;
- `COLOR`: registrador associado à informação de cor utilizada pelo rasterizador.

Os registradores dedicados ao rasterizador permitem que os parâmetros geométricos sejam preparados por instruções da ULA e disponibilizados à unidade gráfica por conexões internas.

Essa organização reduz a necessidade de criar uma instrução diferente para cada possível combinação de coordenadas e cores. Em vez disso, o programa pode utilizar instruções de manipulação de registradores para preparar os valores e, posteriormente, solicitar a operação gráfica correspondente.

A especificação do projeto descreve um banco com duas portas de leitura combinacional e uma porta de escrita síncrona. Isso permite disponibilizar dois operandos para uma operação, enquanto os resultados podem ser armazenados em uma posição de destino.

O banco de registradores, portanto, funciona como um ponto central de armazenamento e comunicação entre as instruções executadas pela ULA e os parâmetros consumidos pelas unidades funcionais gráficas.

## 3.7 Unidade Lógica e Aritmética (ULA)

A Unidade Lógica e Aritmética (ULA) é o componente responsável por realizar operações aritméticas e lógicas sobre os operandos fornecidos pela arquitetura. Entre as operações tradicionalmente realizadas por uma ULA estão adição, subtração, operações booleanas e comparações.

No projeto, a ULA é utilizada para executar operações previstas na ISA e para manipular valores armazenados no banco de registradores. Esses valores podem representar operandos gerais ou parâmetros utilizados pelas unidades gráficas.

Por exemplo, antes de desenhar um retângulo ou triângulo, o programa pode preparar coordenadas e informações de cor nos registradores correspondentes. A ULA permite calcular ou transferir esses valores por meio das instruções disponíveis.

O fluxo básico de uma operação pode ser representado por:

    REGISTRADOR A ----+
                     |
                     v
                  +------+
    REGISTRADOR B -> ULA |
                  +------+
                     |
                     v
               RESULTADO
                     |
                     v
             BANCO DE REGISTRADORES

A ULA também pode produzir indicadores de estado, como zero, negativo, carry e overflow, conforme a operação executada. Esses indicadores são úteis para avaliar condições e controlar desvios condicionais.

No projeto, a especificação descreve um registrador `FLAGS` associado a esses indicadores. A instrução `B_COND` utiliza o mecanismo de avaliação de condições para determinar se o fluxo do programa deve ser alterado.

A ULA contribui, assim, para a execução das operações fundamentais da ISA e para o controle do fluxo de instruções.

## 3.8 Memórias de Instruções e de Dados Gráficos

As memórias são componentes fundamentais do coprocessador porque armazenam tanto o programa que será executado quanto os dados necessários à geração das imagens.

A memória de instruções contém palavras de 32 bits que representam as operações codificadas pela ISA. Já as memórias gráficas armazenam informações como índices de cor, padrões de tiles, mapa do background, padrões de sprites e pixels do framebuffer.

No projeto, a memória de instruções é inicializada por um arquivo `.mif` (*Memory Initialization File*). Esse formato permite especificar valores que serão utilizados para inicializar uma memória durante a compilação do projeto no Quartus.

O fluxo de preparação do programa é:

    PROGRAMA ASSEMBLY
           |
           v
    MONTAGEM / CODIFICAÇÃO
           |
           v
    ARQUIVO .MIF
           |
           v
    MEMÓRIA DE INSTRUÇÕES
           |
           v
    EXECUÇÃO NA FPGA

O repositório inclui ferramentas auxiliares relacionadas à montagem e à geração desses arquivos. Dessa forma, as instruções podem ser preparadas a partir de uma descrição de programa e convertidas para o formato esperado pela memória de instruções, evitando a necessidade de inserir manualmente cada palavra binária.

Os arquivos `.mif` também podem ser utilizados para inicializar memórias que contêm recursos gráficos. Nesses casos, o conteúdo precisa respeitar a largura, a profundidade e a organização esperadas pelo módulo correspondente.

Essa separação entre programa e recursos gráficos facilita a preparação de diferentes demonstrações e permite modificar o comportamento do coprocessador sem alterar a estrutura física de todos os módulos.

É importante observar que a capacidade nominal de uma memória não corresponde necessariamente à quantidade de recursos físicos efetivamente utilizada após a síntese. A ocupação real depende da inferência das memórias, das otimizações do compilador e da configuração final do projeto no Quartus.

## 3.9 Representação de Cores por Índices e Paletas

Uma técnica utilizada em sistemas gráficos é a representação indexada de cores. Nesse modelo, cada pixel não armazena diretamente todos os componentes RGB da cor; em vez disso, armazena um índice que referencia uma entrada de uma paleta.

No projeto, os padrões gráficos de tiles e sprites utilizam índices de 8 bits. Esses índices são utilizados para consultar a paleta, que fornece a representação da cor utilizada na imagem.

A cor de saída possui 9 bits, organizados no formato `RRRGGGBBB`, com três bits para cada componente de cor. Assim, cada componente pode assumir oito níveis de intensidade, permitindo representar até \(8^3 = 512\) combinações de cores.

O processo de conversão pode ser representado por:

    ÍNDICE DO PIXEL
           |
           v
    +------------------+
    | PALETA DE CORES  |
    +------------------+
           |
           v
       COR DE 9 BITS
       RRR GGG BBB
           |
           v
       FRAMEBUFFER

A representação indexada separa a informação do padrão gráfico da cor efetivamente apresentada. Isso permite que diferentes pixels compartilhem entradas da paleta e que a cor associada a um índice seja alterada sem modificar todos os padrões que utilizam esse índice.

No projeto, a paleta é utilizada pelos motores gráficos para converter os índices dos pixels em valores de cor apropriados ao framebuffer. Essa organização também facilita a geração e a conversão de recursos gráficos por meio das ferramentas auxiliares do repositório.

## 3.10 Background Baseado em Tiles

Tiles são pequenos blocos gráficos utilizados para construir cenários a partir da repetição e combinação de padrões. Em vez de armazenar individualmente todos os pixels de um cenário completo, o sistema mantém os padrões dos tiles em uma memória e utiliza um mapa para indicar qual padrão deve ocupar cada posição.

No projeto, cada tile possui dimensões de 8 × 8 pixels. A resolução lógica utilizada pelos motores gráficos é de 320 × 240 pixels. Portanto, o background pode ser organizado em:

\[
\frac{320}{8}=40 \text{ tiles por linha}
\]

\[
\frac{240}{8}=30 \text{ linhas de tiles}
\]

O mapa do background possui, assim, 40 × 30, ou 1200 posições de tiles para preencher a área lógica da tela.

A determinação de um pixel do background envolve a identificação do tile correspondente e da posição local do pixel dentro desse tile. O índice do tile permite consultar o padrão gráfico apropriado, enquanto as coordenadas locais determinam qual pixel deve ser lido.

O fluxo pode ser representado por:

    COORDENADA DO PIXEL
            |
            v
       TILEMAP
            |
            v
      ÍNDICE DO TILE
            |
            v
     PADRÃO DO TILE
            |
            v
      ÍNDICE DE COR
            |
            v
          PALETA
            |
            v
       COR DO PIXEL

A principal vantagem dessa técnica é a reutilização dos padrões. Um mesmo tile pode aparecer em diferentes posições do cenário sem que seja necessário armazenar cópias independentes de todos os seus pixels.

Essa organização reduz a quantidade de dados necessária para representar cenários e permite que o motor de background gere a imagem consultando o mapa e os padrões armazenados nas respectivas memórias.

## 3.11 Sprites e Atributos Gráficos

Sprites são elementos gráficos que podem ser posicionados independentemente do background. Eles são frequentemente utilizados para representar personagens, objetos e outros componentes móveis de uma cena.

Diferentemente do background, que é organizado por meio de um tilemap, o motor de sprites utiliza informações de posição, padrão gráfico, paleta e outros atributos para determinar como cada elemento deve ser apresentado.

No projeto, o motor de sprites processa os atributos e os padrões gráficos necessários à renderização. A especificação da ISA contempla instruções para configurar a posição e os atributos de sprites, além de instruções para escrever seus dados gráficos.

A palavra de atributos definida na especificação possui 32 bits e contempla campos relacionados a habilitação, prioridade, espelhamento horizontal e vertical, seleção de paleta e identificação do padrão gráfico. A organização exata desses campos deve seguir a codificação utilizada pelo projeto.

Durante a renderização, o motor utiliza as informações de configuração para determinar a posição ocupada pelo sprite e consultar seus pixels. Os índices de cor são convertidos pela paleta e os pixels resultantes são encaminhados ao processo de composição.

A utilização de atributos permite modificar a posição e a aparência de um sprite sem precisar reconstruir todo o seu padrão gráfico. Isso favorece a reutilização dos recursos armazenados e simplifica a programação das cenas.

## 3.12 Rasterização de Primitivas Geométricas

Rasterização é o processo de converter uma descrição geométrica em uma representação discreta formada por pixels. Uma primitiva, como um retângulo ou triângulo, pode ser descrita por coordenadas e vértices; entretanto, a imagem final é armazenada em uma grade de posições discretas.

No projeto, existem unidades de rasterização destinadas ao desenho de retângulos e triângulos. Esses módulos recebem os parâmetros das primitivas e determinam quais pixels devem ser produzidos para representar as regiões geométricas.

No caso de um retângulo preenchido, as coordenadas fornecidas permitem determinar os limites horizontais e verticais da região. O rasterizador percorre os pixels correspondentes e gera as escritas necessárias no framebuffer.

Para um triângulo, a descrição é feita por três vértices. A partir deles, o rasterizador determina a região interna da primitiva e os pixels que pertencem ao seu preenchimento.

O fluxo geral pode ser representado por:

    COORDENADAS E PARÂMETROS
               |
               v
    +----------------------+
    |     RASTERIZADOR     |
    |                      |
    | Retângulos           |
    | Triângulos           |
    +----------------------+
               |
               v
        PIXELS GERADOS
               |
               v
          COMPOSIÇÃO
               |
               v
           FRAMEBUFFER

A rasterização transforma os comandos geométricos da ISA em dados gráficos concretos. Dessa forma, o programa pode solicitar o desenho de uma primitiva por meio de uma instrução, enquanto o circuito especializado executa os cálculos necessários para produzir seus pixels.

A divisão entre a descrição geométrica e a geração de pixels permite que o programa opere em um nível mais abstrato, sem precisar especificar individualmente cada pixel que compõe uma figura.

## 3.13 Compositor e Prioridade entre Camadas

O compositor é responsável por organizar a contribuição dos diferentes motores gráficos para a formação da imagem final. Como background, primitivas geométricas e sprites podem ocupar regiões coincidentes, o sistema precisa definir como essas informações serão combinadas.

Uma estratégia consiste em processar as camadas em uma ordem determinada e encaminhar as escritas ao framebuffer por meio de uma interface compartilhada. A arbitragem seleciona a origem dos dados que serão escritos e evita que múltiplos motores controlem simultaneamente a mesma porta de escrita.

No projeto, o compositor integra os elementos gráficos produzidos pelos motores de background, rasterização e sprites. Os testes de composição presentes no repositório incluem cenários de sobreposição e verificação da ordem de desenho.

O fluxo conceitual pode ser representado por:

    BACKGROUND
         |
         v
    PRIMITIVAS GEOMÉTRICAS
         |
         v
       SPRITES
         |
         v
      COMPOSIÇÃO
         |
         v
      FRAMEBUFFER

A ordem apresentada representa a sequência conceitual de composição utilizada no projeto, e não implica que todos os motores estejam necessariamente executando operações em paralelo. A implementação depende do controle e do sequenciamento adotados nos módulos.

A prioridade entre sprites constitui outro aspecto importante. Quando diferentes sprites ocupam a mesma região, o sistema precisa determinar qual contribuição deve prevalecer. O motor de sprites contempla atributos de prioridade, e o repositório possui testbenches destinados à verificação desse comportamento.

O compositor e o mecanismo de prioridade contribuem, portanto, para transformar os pixels produzidos pelas unidades funcionais em uma imagem coerente.

## 3.14 Framebuffer e Double Buffering

O framebuffer é uma região de memória que armazena os pixels utilizados para representar a imagem. Em vez de gerar diretamente todos os sinais de cor do monitor a partir dos cálculos dos motores gráficos, o sistema escreve os pixels em memória e permite que o controlador de vídeo os leia durante a varredura da tela.

No projeto, o framebuffer armazena valores de cor de 9 bits por pixel lógico. Considerando a resolução lógica de 320 × 240 pixels, cada buffer possui 76800 posições.

A capacidade nominal de um buffer é:

\[
320 \times 240 \times 9 = 691200 \text{ bits}
\]

Isso corresponde a 86400 bytes, ou aproximadamente 84,4 KiB.

O projeto utiliza dois buffers, permitindo separar a construção de um quadro da leitura utilizada para exibição. Essa técnica é conhecida como *double buffering*.

Enquanto um buffer é utilizado para fornecer pixels ao controlador VGA, o outro pode receber os dados do quadro seguinte. Quando o sistema realiza a troca de buffers, o papel de cada memória é invertido.

A troca pode ser sincronizada com o período de apagamento vertical (*Vertical Blanking Interval* — VBlank), evitando a mudança do buffer de exibição no meio da varredura do quadro.

O mecanismo pode ser representado por:

    +-------------------+      +-------------------+
    | BUFFER DE LEITURA |      | BUFFER DE ESCRITA |
    |                   |      |                   |
    | Controlador VGA   |      | Motores gráficos  |
    +-------------------+      +-------------------+
               \                    /
                \                  /
                 v                v
                    TROCA NO VBLANK
                            |
                            v
                     NOVOS PAPÉIS

O double buffering reduz a possibilidade de a imagem exibida misturar partes de quadros diferentes. Entretanto, o resultado depende da correta sincronização da troca e da conclusão das operações de renderização.

## 3.15 Controlador VGA e Resolução de Vídeo

O controlador VGA é responsável por gerar os sinais de sincronização e os dados de cor utilizados para apresentar a imagem em um monitor compatível.

No projeto, o controlador de vídeo realiza a leitura dos pixels do framebuffer e produz a saída VGA. A implementação utiliza um clock principal de 50 MHz e um PLL para gerar um clock de pixel de aproximadamente 25 MHz.

A resolução física configurada é de 640 × 480 pixels, enquanto os motores gráficos trabalham com uma resolução lógica de 320 × 240 pixels. Essa diferença é tratada por meio de uma representação em que cada pixel lógico corresponde a uma região de 2 × 2 pixels físicos.

A relação entre as coordenadas pode ser descrita por:

\[
x_{\text{físico}}=2x_{\text{lógico}}
\]

\[
y_{\text{físico}}=2y_{\text{lógico}}
\]

Assim, cada pixel lógico é apresentado como quatro pixels físicos adjacentes. Essa estratégia reduz a quantidade de pixels que precisam ser armazenados e processados internamente.

O fluxo da imagem até a saída pode ser representado por:

    MOTORES GRÁFICOS
           |
           v
       COMPOSITOR
           |
           v
       FRAMEBUFFER
           |
           v
    CONTROLADOR VGA
           |
           v
      SAÍDA DE VÍDEO
           |
           v
         MONITOR

O controlador VGA constitui a interface final entre o processamento gráfico interno e a exibição física da imagem. Sua operação precisa estar sincronizada com os endereços de leitura do framebuffer e com os sinais de temporização do vídeo.

## 3.16 FPGA e Descrição de Hardware em Verilog

Uma FPGA (*Field-Programmable Gate Array*) é um dispositivo lógico programável que permite implementar circuitos digitais por meio de uma configuração definida pelo projetista. Ao contrário de um programa executado sequencialmente por uma CPU de propósito geral, uma descrição de hardware define estruturas lógicas que podem operar de forma concorrente.

No projeto, o Verilog é utilizado para descrever os módulos do coprocessador, incluindo a unidade de busca, a ULA, o banco de registradores, os motores gráficos, o compositor e os circuitos relacionados à saída VGA.

A organização modular permite desenvolver e verificar componentes de maneira independente antes de integrá-los ao sistema completo. Também possibilita descrever registradores, máquinas de estados, operações combinacionais e interfaces entre módulos.

A síntese converte a descrição de hardware em uma implementação adequada aos recursos disponíveis na FPGA. No fluxo do Quartus, o projeto é analisado, sintetizado, ajustado ao dispositivo selecionado e preparado para programação da placa.

A validação do sistema exige mais do que a compilação: testbenches permitem verificar o comportamento lógico em simulação, enquanto os testes na placa permitem observar a interação dos módulos no hardware real. A análise de utilização de recursos, temporização e frequência máxima também é necessária para avaliar as características físicas da implementação.

Essa abordagem permite integrar lógica de controle e unidades gráficas especializadas em um único dispositivo, tornando possível executar programas que comandam diretamente a geração de imagens.

## Referências

PATTERSON, David A.; HENNESSY, John L. *Computer Organization and Design ARM Edition: The Hardware Software Interface*. 2. ed. Cambridge: Morgan Kaufmann, 2016.

IEEE. *IEEE Standard for Verilog Hardware Description Language*. IEEE Std 1364-2005. New York: Institute of Electrical and Electronics Engineers, 2006.

INTEL. *Cyclone V Device Handbook*. Santa Clara: Intel Corporation. Disponível em: https://www.intel.com/content/www/us/en/products/details/fpga/cyclone/v/docs.html. Acesso em: 15 out. 2026.


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


# 5. Especificação de Hardware e Software

Esta seção apresenta os recursos de hardware e software utilizados no desenvolvimento, na simulação e na execução do coprocessador gráfico em FPGA. Também são descritos os arquivos de inicialização das memórias, as ferramentas auxiliares desenvolvidas para a ISA e os recursos utilizados para testar os programas Assembly antes de executá-los no hardware.

## 5.1 Hardware

A implementação utiliza como plataforma-alvo a placa **Terasic DE1-SoC**, equipada com um dispositivo Intel/Altera Cyclone V SoC. O projeto Quartus está configurado para o dispositivo `5CSEMA5F31C6`, e o módulo de topo do sistema é `coprocessador_top`.

A FPGA executa o núcleo de processamento, a unidade de controle, os motores gráficos, a composição das camadas e os circuitos de armazenamento e exibição da imagem.

As principais especificações da plataforma são:

- **Placa-alvo:** Terasic DE1-SoC.
- **Família da FPGA:** Intel/Altera Cyclone V.
- **Dispositivo configurado no Quartus:** `5CSEMA5F31C6`.
- **Módulo de topo:** `coprocessador_top`.
- **Clock principal:** 50 MHz.
- **Clock de pixel:** aproximadamente 25 MHz, gerado por PLL.
- **Interface de vídeo:** VGA.
- **Resolução física de saída:** 640 × 480 pixels.
- **Resolução lógica de renderização:** 320 × 240 pixels.
- **Controles físicos:** botões `KEY`, utilizados para reset e reinício, além de LEDs de estado.

A resolução lógica reduz a quantidade de pixels processados e armazenados internamente. Na saída VGA, cada pixel lógico é ampliado para um bloco de 2 × 2 pixels físicos, permitindo a exibição da imagem em 640 × 480 pixels.

A arquitetura utiliza dois bancos de framebuffer (*double buffering*). Enquanto um banco fornece os pixels para a saída VGA, o outro recebe as operações de desenho. Ao final do programa gráfico, a troca dos bancos é sincronizada com o intervalo de apagamento vertical (*vertical blanking*), evitando que a imagem seja atualizada de maneira arbitrária durante a exibição.

De forma simplificada, o fluxo de processamento pode ser representado por:

```text
+-----------------------------+
| MEMÓRIA DE INSTRUÇÕES       |
| Programa Assembly em .mif   |
+--------------+--------------+
               |
               v
+-----------------------------+
| NÚCLEO DO COPROCESSADOR     |
| Busca, controle, ULA        |
| Banco de registradores      |
+--------------+--------------+
               |
               v
+-----------------------------+
| UNIDADES GRÁFICAS           |
| Background | Rasterizadores |
| Sprites                    |
+--------------+--------------+
               |
               v
+-----------------------------+
| COMPOSIÇÃO DAS CAMADAS      |
| Controle de sobreposição    |
+--------------+--------------+
               |
               v
+-----------------------------+
| FRAMEBUFFER DUPLO           |
+--------------+--------------+
               |
               v
+-----------------------------+
| CONTROLADOR VGA + PLL       |
+--------------+--------------+
               |
               v
          MONITOR VGA
```

O núcleo utiliza o clock principal de 50 MHz, enquanto a geração dos sinais de vídeo e a leitura do framebuffer utilizam o clock de pixel gerado pelo PLL. A sincronização entre o processamento dos quadros e a exibição é realizada pelo próprio hardware.

## 5.2 Software e Ferramentas de Desenvolvimento

O projeto utiliza ferramentas de desenvolvimento, compilação, simulação e geração de arquivos de inicialização. Os principais recursos presentes no repositório são:

- **Intel Quartus Prime Standard Lite Edition 25.1:** ambiente associado ao projeto `CoProcessador.qpf`, utilizado para configurar, sintetizar e preparar a implementação do hardware na FPGA.
- **ModelSim/Questa:** ferramentas de simulação HDL para as quais o repositório contém testbenches e arquivos auxiliares de simulação.
- **Verilog HDL:** linguagem utilizada na descrição do núcleo, dos motores gráficos, das memórias e dos circuitos de controle.
- **Python:** utilizado em ferramentas auxiliares para montagem de programas, geração de Assembly e conversão de imagens em arquivos de inicialização.
- **C:** utilizado no programa `compiladorISA.c`, que gera programas codificados para a ISA do coprocessador em formato `.mif`.
- **HTML, CSS e JavaScript:** utilizados no simulador da ISA executado diretamente no navegador.

### 5.2.1 Montador e Gerador de Programas

O repositório contém ferramentas para produzir programas destinados à memória de instruções do coprocessador.

O arquivo `aux_files/montador.py` recebe um programa Assembly e gera três arquivos:

- `.mif`: conteúdo destinado à inicialização da memória de instruções no Quartus.
- `.hex`: representação hexadecimal das instruções, utilizada em fluxos de simulação compatíveis com `$readmemh`.
- `.lst`: listagem com endereços, instruções codificadas, campos binários e linhas de origem.

O montador reconhece instruções da ISA, registradores, valores imediatos, rótulos e desvios condicionais e incondicionais. Isso permite escrever programas de demonstração em Assembly e convertê-los para a representação binária esperada pelo hardware.

Também está presente o arquivo `aux_files/compiladorISA.c`, que implementa um gerador de programas em C e produz arquivos `.mif`. Entre os recursos previstos nesse gerador estão a composição de cenas com retângulos, triângulos, sprites e rolagem do background.

O repositório contém ainda `aux_files/gerador_assembly.py`, utilizado para gerar programas Assembly de demonstração.

É importante distinguir a geração do arquivo da sua utilização pelo hardware: depois de produzir um novo `.mif`, é necessário garantir que a memória de instruções do projeto Quartus esteja configurada para carregar esse arquivo durante a compilação.

### 5.2.2 Simulador HTML da ISA

O diretório `aux_files/` contém o simulador `simulador_isa (1).html`, desenvolvido com HTML, CSS e JavaScript para executar programas da ISA do coprocessador gráfico no navegador.

O simulador permite montar e executar instruções Assembly, acompanhar os registradores e observar a imagem produzida em uma área de vídeo lógica de 320 × 240 pixels. Também contempla recursos como rótulos, desvios, desenho de primitivas, background baseado em tiles, sprites e composição por prioridade.

Essa ferramenta oferece um ambiente auxiliar para estudar o comportamento dos programas e verificar a sequência de operações gráficas antes dos testes na FPGA. Entretanto, sua execução ocorre no navegador e não substitui a síntese, a simulação HDL ou a execução física do circuito.

O repositório também contém `aux_files/Simulador do coprocessador gráfico (1).html`, outro arquivo HTML de simulação. Os arquivos HTML devem ser considerados ferramentas auxiliares distintas do hardware descrito em Verilog.

### 5.2.3 Ferramentas de Conversão de Imagens e Visualização de Memórias

O projeto contém scripts que facilitam a preparação dos dados gráficos utilizados pelas memórias da FPGA.

Entre eles estão:

- `aux_files/imagem_para_mif.py`: converte uma imagem em arquivos de inicialização para o tilemap, os padrões do background, a paleta e o programa associado à exibição do fundo.
- `aux_files/gerar_background.py`: ferramenta auxiliar para geração de dados de background.
- `aux_files/mif_visualizador.html`: visualizador de arquivos `.mif`, útil para inspecionar o conteúdo das memórias inicializadas.

Esses recursos permitem preparar imagens e programas sem precisar editar manualmente cada endereço das memórias. Os arquivos gerados devem respeitar as dimensões, a organização dos dados e a representação de cores esperadas pelos módulos HDL correspondentes.

## 5.3 Arquivos de Inicialização das Memórias

O projeto utiliza arquivos no formato `.mif` (*Memory Initialization File*) para fornecer os dados iniciais das memórias de instruções e dos recursos gráficos.

Os arquivos presentes em `memory_files/initialization_files/` incluem:

- `apresentacao_programa.mif`
- `apresentacao_background_tilemap.mif`
- `apresentacao_background_padrao.mif`
- `apresentacao_paleta.mif`
- `apresentacao_sprite_pattern.mif`
- `scroll_background.mif`

Os módulos de memória gerados para o projeto referenciam os arquivos `apresentacao_*.mif` correspondentes às instruções, ao tilemap, aos padrões do background, à paleta e aos padrões de sprites. O diretório também contém `scroll_background.mif`, associado a um cenário de demonstração.

A função dos principais arquivos é:

| Arquivo | Finalidade |
|---|---|
| `apresentacao_programa.mif` | Inicialização da memória de instruções com o programa gráfico de demonstração. |
| `apresentacao_background_tilemap.mif` | Inicialização do mapa que organiza os tiles do background. |
| `apresentacao_background_padrao.mif` | Inicialização dos padrões gráficos utilizados pelos tiles do background. |
| `apresentacao_paleta.mif` | Inicialização dos valores de cor utilizados pelo sistema gráfico. |
| `apresentacao_sprite_pattern.mif` | Inicialização dos padrões gráficos dos sprites. |
| `scroll_background.mif` | Arquivo de dados incluído no projeto para a demonstração de rolagem do background. |

A organização das memórias acompanha a arquitetura gráfica. O motor de background consulta o mapa de tiles e seus padrões gráficos; o motor de sprites utiliza os padrões dos sprites; e a paleta fornece os valores de cor usados na composição dos pixels.

Os dados produzidos pelos motores gráficos são encaminhados à composição das camadas e ao framebuffer, de onde são lidos pelo controlador VGA para formar a imagem exibida.

O processo pode ser resumido da seguinte maneira:

```text
+--------------------------------+
| ARQUIVOS DE INICIALIZAÇÃO .MIF  |
|                                |
| Programa | Tilemap | Padrões   |
| Paleta   | Sprite              |
+----------------+---------------+
                 |
                 v
+--------------------------------+
| MEMÓRIAS DO COPROCESSADOR      |
|                                |
| Instruções | Background        |
| Paleta     | Padrões de sprites|
+----------------+---------------+
                 |
                 v
+--------------------------------+
| MOTORES GRÁFICOS                |
| Background | Rasterizadores    |
| Sprites                        |
+----------------+---------------+
                 |
                 v
+--------------------------------+
| COMPOSIÇÃO E FRAMEBUFFER DUPLO |
+----------------+---------------+
                 |
                 v
           CONTROLADOR VGA
```

Dessa forma, os arquivos `.mif` fornecem os dados utilizados na inicialização das memórias, enquanto os módulos Verilog implementam a lógica de busca, processamento, renderização, composição e exibição. As ferramentas auxiliares permitem gerar ou inspecionar esses dados, facilitando a criação de novas demonstrações e a validação da ISA.


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

A validação do coprocessador gráfico foi realizada por meio de diferentes estratégias complementares: simulação dos módulos em Verilog, execução de programas Assembly em um simulador desenvolvido em HTML, geração de arquivos de inicialização de memória e testes do sistema integrado na FPGA DE1-SoC.

A utilização dessas estratégias permitiu analisar o comportamento do projeto em diferentes níveis. Enquanto os testbenches verificam condições específicas dos circuitos digitais, o simulador HTML possibilita acompanhar a execução das instruções da ISA e observar seus efeitos sobre os registradores e a imagem produzida. Já os testes na placa permitem verificar o funcionamento do sistema integrado com as memórias, os motores gráficos e a saída VGA.

Também foram desenvolvidas ferramentas auxiliares para facilitar a criação e a execução de programas destinados ao coprocessador. Entre elas estão o simulador da ISA, o montador de Assembly e o gerador de arquivos `.mif`, utilizados para preparar programas e dados que podem ser carregados nas memórias do projeto.

## 8.1 Testes por Simulação em Verilog

O repositório contém testbenches desenvolvidos em Verilog para verificar o funcionamento de módulos individuais e de partes integradas do coprocessador. Esses arquivos permitem aplicar entradas controladas, observar os sinais internos e comparar os resultados obtidos com os valores esperados.

Entre os principais componentes contemplados pelos testes estão:

- **Unidade de busca de instruções:** verificação do fluxo de busca, da execução automática, do reinício e do tratamento do término do programa;
- **Rasterizadores:** análise da geração de pixels para quadrados e triângulos, incluindo a verificação das coordenadas e das cores escritas no framebuffer;
- **Motor de background:** verificação do deslocamento automático do cenário (*scroll*) e de sua atualização entre quadros;
- **Motor de sprites:** análise da transparência, do espelhamento horizontal e vertical e da prioridade entre sprites;
- **Framebuffer:** verificação da troca entre buffers e da independência dos conteúdos armazenados;
- **Composição gráfica:** análise da ordem de desenho, da sobreposição de elementos e da arbitragem das escritas no framebuffer;
- **Desvios da ISA:** testes de instruções de desvio, incluindo `B` e `B_COND`, por meio de simulações do sistema integrado.

Os testbenches possuem verificações automáticas para comparar pixels, quantidades de escritas, valores de registradores e outros sinais com os resultados esperados. Quando uma condição não é satisfeita, alguns testes registram mensagens de erro; outros também contabilizam as falhas e apresentam um resumo ao final da execução.

A existência desses mecanismos facilita a identificação de erros e a repetição dos testes após alterações no código. Entretanto, a presença de um testbench no repositório, isoladamente, não comprova que sua execução mais recente tenha sido aprovada.

## 8.2 Simulador HTML da ISA

Além das simulações em Verilog, foi desenvolvido um simulador em HTML para testar a arquitetura de conjunto de instruções (*Instruction Set Architecture* — ISA) do coprocessador gráfico.

A ferramenta permite escrever um programa em Assembly, montar as instruções e executar o programa dentro do ambiente de simulação. Ela também permite acompanhar o estado dos registradores, o contador de programa (*Program Counter* — PC), a quantidade de instruções executadas e o resultado gráfico produzido.

Durante a execução, é possível observar como as instruções modificam os registradores e como os comandos gráficos afetam a imagem. O simulador considera a ordem de composição definida para o projeto, na qual o background é processado antes dos rasterizadores e das sprites.

A ferramenta também oferece suporte ao carregamento de arquivos `.mif` correspondentes às memórias gráficas, incluindo paleta, mapa de tiles, padrões do background e padrões de sprites. Isso permite utilizar dados de inicialização do próprio projeto na simulação, aproximando os cenários testados daqueles preparados para a FPGA.

Esse recurso foi importante para investigar a relação entre o programa Assembly e o resultado visual esperado, facilitando a identificação de problemas de codificação, de utilização dos registradores e de interpretação das instruções antes dos testes em hardware.

## 8.3 Testes com Programas Assembly

O projeto contém programas Assembly utilizados para exercitar a ISA e comandar as funcionalidades gráficas. Entre os comandos presentes nos programas estão instruções para configuração de paletas, escrita de dados de tiles, desenho de primitivas, configuração de sprites, movimentação do background e controle da execução.

Um dos arquivos presentes na raiz do repositório é `programa.asm`, que contém um programa de teste com operações de configuração de paleta e preenchimento de dados do background. Também existe o arquivo `aux_files/demo_programa_4sprites.asm`, utilizado como outro exemplo de programa para a arquitetura.

A execução dos programas no simulador HTML permite verificar se as instruções são reconhecidas e montadas, se os registradores são utilizados conforme os operandos especificados e se os comandos gráficos produzem o efeito esperado na imagem simulada.

Os testes de desvios também são contemplados por programas específicos, permitindo verificar o comportamento de instruções de salto e de desvio condicional. Para esses casos, o repositório inclui cenários automatizados de teste do sistema integrado.

É importante distinguir a simulação da ISA da validação do hardware: o simulador HTML facilita a análise da lógica e dos efeitos esperados das instruções, mas não substitui os testes do circuito sintetizado na FPGA.

## 8.4 Montagem de Instruções e Geração de Arquivos `.mif`

Para facilitar a preparação de programas destinados ao hardware, o projeto contém ferramentas auxiliares de montagem e geração de arquivos de inicialização de memória.

O arquivo `aux_files/montador.py` integra o conjunto de ferramentas relacionado à montagem de programas. O repositório também contém o código-fonte `aux_files/compiladorISA.c`, responsável por gerar programas codificados no formato Memory Initialization File (`.mif`).

O gerador em C permite configurar ações gráficas, incluindo desenho de retângulos e triângulos, quantidade de sprites e deslocamento do background. A partir dessas configurações, as instruções são codificadas em palavras de 32 bits e gravadas em um arquivo `.mif`, com largura de 32 bits e profundidade de 16384 posições.

O arquivo gerado pode ser associado à memória de instruções do projeto no Quartus, permitindo que o coprocessador execute o programa após a compilação e a programação da FPGA. Esse procedimento evita a necessidade de codificar manualmente cada instrução binária e torna mais simples modificar os comandos utilizados na demonstração.

O gerador também considera desvios e rótulos internos, resolvendo os destinos correspondentes durante a geração do programa. Dessa forma, a ferramenta contribui para testar programas mais elaborados, incluindo sequências de ações e animações.

Os arquivos `.mif` não se limitam ao programa de instruções. O projeto também contém arquivos destinados à inicialização de dados gráficos, como paleta, mapa de tiles, padrões do background e padrões de sprites. Esses arquivos devem corresponder às dimensões e aos formatos esperados pelas respectivas memórias do hardware.

A utilização dessas ferramentas estabelece um fluxo de trabalho entre a descrição do programa, sua codificação, a inicialização das memórias e a execução na FPGA.

## 8.5 Testes do Rasterizador de Quadrados

O testbench `tb/tb_rasterizer_square.v` verifica a geração de pixels pelo rasterizador de quadrados.

O teste compara os pixels escritos no framebuffer de teste com a região esperada, verificando a cor e a quantidade de pixels produzidos. Também verifica possíveis escritas fora dos limites da região definida, incluindo as bordas esquerda, direita, superior e inferior.

Essas verificações permitem detectar erros de delimitação, preenchimento ou escrita no framebuffer. O testbench registra mensagens de aprovação ou erro conforme as comparações realizadas.

## 8.6 Testes do Rasterizador de Triângulos

O arquivo `tb/tb_rasterizer_triangle.v` verifica o preenchimento de triângulos por meio da análise das coordenadas e das cores produzidas pelo rasterizador.

O testbench compara as posições dos pixels escritos com as regiões esperadas para cada linha do triângulo, utilizando os limites calculados para o preenchimento. Também verifica se os pixels são escritos com a cor correspondente.

O teste contempla a identificação de divergências entre os limites esperados e os observados, além de registrar um aviso para triângulos degenerados em que todos os vértices possuem a mesma coordenada vertical.

## 8.7 Testes do Motor de Background

O arquivo `tb/tb_motor_background.v` contém um teste direcionado ao mecanismo de deslocamento automático do background.

Nesse cenário, o deslocamento horizontal é configurado para avançar um pixel por quadro. O testbench acompanha a evolução do valor de `scroll_x` ao longo de cinco quadros e verifica se o deslocamento alcança o valor esperado.

O teste também permite observar a atualização dos parâmetros utilizados pelo motor durante o processamento dos quadros. Dessa forma, auxilia na identificação de problemas relacionados ao controle do scroll e à consistência do deslocamento aplicado à imagem.

## 8.8 Testes do Motor de Sprites

O comportamento do motor de sprites é analisado por testbenches específicos, que verificam diferentes propriedades da renderização.

### 8.8.1 Transparência

O arquivo `tb/tb_motor_sprite_transparencia.v` verifica se pixels transparentes deixam de produzir escritas no framebuffer. O teste contabiliza as escritas realizadas pelo motor e apresenta o resultado da verificação.

Essa propriedade é importante para que as regiões transparentes de uma sprite não apaguem ou substituam os pixels das camadas gráficas posicionadas atrás dela.

### 8.8.2 Espelhamento

O arquivo `tb/tb_motor_sprite_espelhamento.v` verifica as configurações de espelhamento horizontal (`flip_h`), vertical (`flip_v`) e combinado, além da configuração original sem espelhamento.

O testbench utiliza um padrão assimétrico para permitir a identificação das alterações de posição dos pixels. Dessa forma, é possível comparar a imagem produzida com a imagem esperada para cada configuração.

A validação em simulação é complementada pela observação do comportamento na FPGA, pois a interação entre os sinais de controle, os módulos integrados e as memórias pode revelar problemas que não aparecem nos testes isolados.

### 8.8.3 Prioridade entre Sprites

O arquivo `tb/tb_motor_sprite_prioridade.v` verifica o comportamento do sistema quando duas sprites ocupam a mesma região da tela.

O teste configura sprites sobrepostas e verifica tanto a quantidade de escritas quanto o conteúdo final do framebuffer. A expectativa é que o resultado respeite a regra de prioridade implementada pelo motor, mantendo visível a sprite que deve prevalecer segundo essa configuração.

## 8.9 Testes do Framebuffer e da Composição Gráfica

O projeto possui testbenches voltados ao armazenamento e à composição dos elementos gráficos.

O arquivo `tb/tb_framebuffer_troca_buffers.v` verifica a troca entre os dois buffers, observando se cada um mantém seu conteúdo independentemente do outro. Esse teste auxilia na validação da estratégia de *double buffering*.

Já o arquivo `tb/tb_composicao_ordem_desenho.v` verifica a ordem de composição entre background, rasterizador e sprites. O resultado esperado considera a sprite sobre o retângulo e o retângulo sobre o background, de acordo com a ordem definida para a composição.

O testbench `tb/tb_compositor_sobreposicao.v` também está presente no repositório para verificar situações de sobreposição. Em conjunto, esses testes ajudam a identificar problemas de arbitragem, seleção de camadas e escrita no framebuffer.

A integração dos módulos é especialmente importante porque o funcionamento correto de cada motor isoladamente não garante, por si só, que a imagem final seja composta corretamente.

## 8.10 Testes de Integração e Desvios

Além dos testes dos módulos gráficos, o repositório contém testes direcionados à unidade de busca de instruções e ao comportamento do coprocessador integrado.

O arquivo `tb/tb_unidade_de_busca_de_instrucoes.v` possui verificações automatizadas relacionadas à execução de programas, ao início e reinício da execução, ao término por `HALT` e às condições de funcionamento da unidade de busca.

Para os desvios, o diretório `tb/sim_top/` contém o testbench `tb_top_desvios.v`, o script `testes_desvios.py` e o script de execução `run.sh`. Esses recursos foram organizados para permitir testes do coprocessador integrado, incluindo instruções `B` e `B_COND`.

Os scripts utilizam o Icarus Verilog para compilar e executar determinadas simulações, enquanto os modelos auxiliares em `stubs_ip_quartus.v` substituem IPs do Quartus, como PLL e memórias, durante esses testes.

A partir da raiz do repositório, o script de desvios pode ser executado com:

```bash
python3 tb/sim_top/testes_desvios.py
```

Para executar a simulação de integração relacionada à prioridade, pode-se utilizar:

```bash
sh tb/sim_top/run.sh
```

Esses comandos dependem das ferramentas indicadas nos próprios scripts e da disponibilidade dos arquivos necessários. A execução deve ser acompanhada pela saída do simulador para identificar eventuais falhas ou mensagens de timeout.

## 8.11 Testes na FPGA DE1-SoC

Após o desenvolvimento e a integração dos módulos, foram realizados testes na placa DE1-SoC para observar o comportamento do sistema em hardware e verificar a saída VGA.

Nessa etapa, o projeto foi compilado no Quartus e programado na FPGA. Os arquivos de inicialização das memórias gráficas e o programa de instruções foram utilizados para preparar a demonstração, permitindo observar o background, as primitivas geométricas e as sprites na imagem exibida.

A demonstração em hardware complementa as simulações porque permite observar a interação entre os módulos, as memórias e os sinais de controle em funcionamento integrado. Ela também possibilita verificar se os resultados observados no simulador correspondem ao comportamento real do sistema.

Durante os testes, foram utilizadas entradas físicas da placa para controlar funções da demonstração, conforme a configuração implementada no projeto. Os sinais de estado disponibilizados nos LEDs também auxiliam na observação de condições de execução, espera e erro.

## 8.12 Erros, Limitações e Decisões de Projeto

A utilização conjunta de simulação, ferramentas de montagem e testes em hardware permitiu investigar o comportamento do coprocessador em diferentes níveis. Ainda assim, é necessário distinguir os recursos implementados daqueles cuja validação permanece incompleta.

Uma limitação identificada durante a demonstração na FPGA está relacionada ao espelhamento horizontal das sprites. Embora exista um testbench dedicado ao espelhamento e o motor possua suporte aos sinais `flip_h` e `flip_v`, foi observado na demonstração que o espelhamento horizontal não apresentou o comportamento esperado. Essa divergência indica a necessidade de investigar a integração entre o controle dos atributos da sprite e o caminho de renderização utilizado no hardware.

Esse caso evidencia a importância de combinar testes isolados com testes integrados: uma propriedade verificada em um ambiente controlado deve também ser observada no sistema completo antes de ser considerada validada em hardware.

Outra consideração diz respeito à execução dos testbenches. Os arquivos de teste contêm verificações automáticas e mensagens para indicar erros, aprovações e timeouts, mas os resultados devem ser confirmados pela execução dos respectivos scripts ou pela análise dos registros gerados. Portanto, não se deve considerar todos os testes aprovados apenas porque seus arquivos estão presentes no repositório.

Por fim, as ferramentas de simulação e geração de arquivos `.mif` constituem parte importante do processo de desenvolvimento. Elas facilitam a preparação dos programas, a inspeção dos registradores e a reprodução de cenários gráficos, reduzindo a dependência de alterações manuais na memória de instruções. A continuidade da validação deve priorizar a investigação das divergências encontradas em hardware e a documentação dos resultados efetivamente obtidos em cada teste.



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



# 10. Equipe do Desenvolvimento

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



# 11. Referências

- **PATTERSON, David A.; HENNESSY, John L.** *Computer Organization and Design ARM Edition: The Hardware/Software Interface*. 2. ed. Cambridge: Morgan Kaufmann, 2016. Disponível em: <https://shop.elsevier.com/books/computer-organization-and-design-arm-edition/patterson/978-0-12-801733-3>.

- **IEEE.** *IEEE Standard for Verilog Hardware Description Language*. IEEE Std 1364-2005. New York: IEEE, 2006. DOI: <https://doi.org/10.1109/IEEESTD.2006.99495>. Disponível em: <https://ieeexplore.ieee.org/document/1620780>.

- **INTEL CORPORATION.** *Cyclone V Device Handbook: Volume 1 — Device Interfaces and Integration*. Seção 2: Embedded Memory Blocks in Cyclone V Devices. Disponível em: <https://www.intel.com/programmable/technical-pdfs/683375.pdf>.
  
- **UNIVERSIDADE ESTADUAL DE FEIRA DE SANTANA (UEFS).** *Problema #2 - Sistema Digital*. Disciplina de MI - Sistemas Digitais (2026.2), Departamento de Tecnologia, Feira de Santana, 2026.



