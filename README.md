# CoProcessador Grafico em FPGA - Sistema Digital 2026.2

## Sumário

- [1. Visão Geral do Projeto](#1-visão-geral-do-projeto)
  - [1.1 Conceito Geral](#11-conceito-geral)
  - [1.2 Da Descricao da Cena ao Pixel](#12-da-descricao-da-cena-ao-pixel)
  - [1.3 Resolucao e Representacao da Imagem](#13-resolucao-e-representacao-da-imagem)
  - [1.4 Arquitetura Grafica em Hardware](#14-arquitetura-grafica-em-hardware)
  - [1.5 Composicao e Memoria de Video](#15-composicao-e-memoria-de-video)
  - [1.6 Double Buffering](#16-double-buffering)
  - [1.7 Organizacao Modular](#17-organizacao-modular)
  - [1.8 Estrutura Principal do Projeto](#18-estrutura-principal-do-projeto)
- [2. Levantamento de Requisitos](#2-levantamento-de-requisitos)
  - [2.1 Requisitos Funcionais](#21-requisitos-funcionais)
  - [2.2 Requisitos de Memória](#22-requisitos-de-memória)
- [3. Fundamentação Teórica](#3-fundamentação-teórica)
  - [3.1 Representação Gráfica Indexada](#31-representação-gráfica-indexada)
  - [3.2 Background Baseado em Tiles](#32-background-baseado-em-tiles)
  - [3.3 Scroll e Wraparound](#33-scroll-e-wraparound)
  - [3.4 Sprites](#34-sprites)
  - [3.5 Espelhamento](#35-espelhamento)
  - [3.6 Rasterização](#36-rasterização)
  - [3.7 Double Buffering](#37-double-buffering)
  - [3.8 VGA](#38-vga)
- [4. Arquitetura do Sistema](#4-arquitetura-do-sistema)
  - [4.1 Fluxo de Composição](#41-fluxo-de-composição)
  - [4.2 Principais Módulos](#42-principais-módulos)
- [5. Especificação de Hardware e Software](#5-especificação-de-hardware-e-software)
- [6. Processo de Desenvolvimento](#6-processo-de-desenvolvimento)
- [7. Instalação e Configuração](#7-instalação-e-configuração)
- [8. Testes de Funcionamento](#8-testes-de-funcionamento)
- [9. Análise do Resultado](#9-análise-do-resultado)
- [10. Controles da Demonstração na FPGA](#10-controles-da-demonstração-na-fpga)
- [11. Estrutura dos Recursos Gráficos](#11-estrutura-dos-recursos-gráficos)
- [12. Equipe do Desenvolvimento](#12-equipe-do-desenvolvimento)
- [13. Referências](#13-referências)
- [14. Estado Resumido da Implementação](#14-estado-resumido-da-implementação)
- [15. Observação Final](#15-observação-final)


Projeto desenvolvido para o Problema #1 - 2026.2 / Sistema Digital, com o objetivo de implementar, em FPGA, um nucleo de coprocessamento grafico inspirado na arquitetura de consoles de 16 bits. A solucao implementa geracao de background por tiles, sprites com atributos e prioridade, rasterizacao de poligonos, framebuffer com double buffering e saida VGA.

Estado atual do projeto:
Esta versao implementa o nucleo grafico em FPGA e sua demonstracao diretamente na placa DE1-SoC. A integracao posterior com Linux, driver em ARM Assembly e jogo em C faz parte da continuidade proposta para o sistema, mas nao esta presente nesta versao do repositorio.


# 1. Visão GERAL DO PROJETO

Este projeto consiste no desenvolvimento de um sistema grafico dedicado implementado em FPGA, capaz de receber parametros de objetos graficos, processa-los em hardware e construir uma imagem destinada a exibicao em um monitor VGA.

A ideia central do projeto e explorar como funcionalidades normalmente associadas a um sistema grafico podem ser implementadas diretamente em hardware digital reconfiguravel, utilizando modulos especializados para executar diferentes etapas do processo de renderizacao.

Em vez de utilizar o processador principal para determinar e escrever individualmente cada pixel da imagem, o sistema trabalha com elementos graficos e seus respectivos parametros, permitindo que a FPGA execute as operacoes necessarias para gerar, rasterizar, compor e armazenar os pixels da cena.

Dessa forma, o projeto pode ser entendido como uma pequena pipeline grafica em hardware, na qual diferentes componentes cooperam para transformar informacoes abstratas sobre a cena em uma imagem efetivamente exibida no monitor.

## 1.1 Conceito GERAL

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

## 1.2 Da DESCRICAO da CENA ao PIXEL

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

## 1.3 Resolucao e REPRESENTACAO DA IMAGEM

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

## 1.4 Arquitetura GRAFICA EM HARDWARE

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

## 1.5 Composicao e MEMORIA DE VIDEO

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

## 1.6 Double BUFFERING

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

## 1.7 Organizacao MODULAR

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

## 1.8 Estrutura PRINCIPAL DO PROJETO

O modulo de nivel superior utilizado na integracao com a plataforma e:

DE1_SOC_golden_top.v

A integracao principal do sistema grafico e realizada em:

top_video.v

A partir desses modulos sao conectados os diferentes componentes responsaveis pelo processamento grafico, armazenamento e geracao da saida de video.

As proximas secoes apresentam cada uma dessas partes em maior profundidade, detalhando o funcionamento dos motores graficos, organizacao da memoria, rasterizacao, sprites, composicao, framebuffer, double buffering e controlador VGA.



# 2. Levantamento DE REQUISITOS

A partir do enunciado do Problema #1, foram identificados os seguintes requisitos principais.


## 2.1 Requisitos Funcionais

- Resolucao grafica logica de 320 x 240 pixels: IMPLEMENTADO
- Saida VGA em 640 x 480 pixels: IMPLEMENTADO
- Ampliacao de cada pixel logico para 2 x 2 pixels fisicos: IMPLEMENTADO
- Background formado por tiles de 8 x 8 pixels: IMPLEMENTADO
- Tilemap de 40 x 30 posicoes: IMPLEMENTADO
- Scroll horizontal: IMPLEMENTADO
- Scroll vertical: IMPLEMENTADO
- Wraparound do background: IMPLEMENTADO
- Memoria de padroes de tiles: IMPLEMENTADO
- Pelo menos 32 sprites: IMPLEMENTADO
- Sprites de 16 x 16 pixels: IMPLEMENTADO
- Posicao X/Y dos sprites: IMPLEMENTADO
- Enable de sprite: IMPLEMENTADO
- Prioridade de sprites: IMPLEMENTADO
- Flip horizontal: IMPLEMENTADO
- Flip vertical: IMPLEMENTADO
- Selecao de paleta: IMPLEMENTADO
- Transparencia por indice de cor 0 em sprites: IMPLEMENTADO
- Rasterizacao de retangulos preenchidos: IMPLEMENTADO
- Rasterizacao de triangulos preenchidos: IMPLEMENTADO
- Aritmetica inteira para rasterizacao: IMPLEMENTADO
- Paleta de cores indexada: IMPLEMENTADO
- Double buffering: IMPLEMENTADO
- Troca de framebuffer durante VBlank: IMPLEMENTADO
- Testes individuais dos principais modulos: IMPLEMENTADO
- Testes de integracao: IMPLEMENTADO
- Driver Linux em ARM Assembly: NAO IMPLEMENTADO NESTA ETAPA
- Aplicacao/jogo em C controlando o coprocessador: NAO IMPLEMENTADO NESTA ETAPA


## 2.2 Requisitos de Memória

A arquitetura possui memorias dedicadas para os principais recursos graficos.

Tilemap do background:
1200 x 8 bits

Padroes do background:
16384 x 8 bits

Atributos de sprites:
32 x 32 bits

Padroes de sprites:
16384 x 8 bits

Paleta:
512 x 9 bits

Framebuffer:
76800 x 9 bits por banco

O tilemap possui exatamente:

40 x 30 = 1200 posicoes

Essas posicoes correspondem a uma tela logica de 320 x 240 pixels dividida em tiles de 8 x 8 pixels.

A memoria de padroes do background possui:

16384 posicoes

Isso permite armazenar:

256 padroes x 8 x 8 pixels = 16384 pixels

O framebuffer possui:

320 x 240 = 76800 pixels

por banco.



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
                                                                         |   Arbitragem  |
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

# 5. Especificação DE HARDWARE E SOFTWARE

## 5.1 Hardware

Plataforma:
Terasic DE1-SoC

FPGA:
Intel/Altera Cyclone V SoC

Dispositivo utilizado na sintese:
5CSEMA5F31C6

Clock principal:
50 MHz

Clock VGA:
aproximadamente 25 MHz

Saida de video:
VGA

Resolucao fisica:
640 x 480

Resolucao logica:
320 x 240

Controles de demonstracao:
KEY, SW e sinais da placa


## 5.2 Software

Os relatorios presentes no projeto indicam utilizacao de:

Intel Quartus Prime Lite Edition 20.1.1

O repositorio tambem contem arquivos e scripts de simulacao para o fluxo ModelSim/Questa utilizado durante o desenvolvimento.

Alguns arquivos .qip de memoria apresentam metadados de IP gerados em versoes diferentes do Quartus.

Dessa forma, ao reconstruir o projeto em outra instalacao, pode ser necessario regenerar ou atualizar determinados IPs.


## 5.3 Arquivos de Inicialização

O diretorio de memorias contem arquivos .mif utilizados para inicializar os recursos graficos.

Entre eles estao:

bg_tile_pattern_praia.mif
bg_tile_ram.mif
palette_default.mif
sprite_attribute_ram.mif
sprite_pattern_ram_pikachu_charmander.mif

Esses arquivos definem recursos como:

- Cenario do background.
- Mapa de tiles.
- Paleta inicial.
- Atributos iniciais dos sprites.
- Padroes graficos dos sprites.



# 6. Processo DE DESENVOLVIMENTO

## 6.1 Sistema VGA

Inicialmente foi estabelecida a geracao dos sinais VGA e a conversao da resolucao fisica de 640 x 480 para a resolucao logica de 320 x 240.

Tambem foi criado o gerador de enderecos do framebuffer.


## 6.2 Framebuffer

Em seguida foi implementado o armazenamento da imagem.

O sistema foi ampliado para dois bancos de memoria, possibilitando double buffering.

A troca dos bancos foi sincronizada com o VBlank.


## 6.3 Background

O subsistema de background foi construido a partir de:

- Tilemap.
- Memoria de padroes.
- Paleta.
- Calculo da posicao do tile.
- Calculo da posicao local do pixel.
- Scroll.
- Wraparound.

Arquivos .mif foram utilizados para criar uma cena grafica de demonstracao.


## 6.4 Sprites

Foi criada uma memoria de atributos para 32 sprites.

Posteriormente foram implementados:

- Busca de atributos.
- Leitura do padrao.
- Selecao de quadrante.
- Prioridade.
- Transparencia.
- Flip horizontal.
- Flip vertical.
- Selecao de paleta.

Tambem foram criados modulos especificos para demonstracao de movimentacao e criacao de sprites em hardware.


## 6.5 Rasterização de Polígonos

A unidade de rasterizacao foi dividida em:

- Rasterizador de retangulos.
- Rasterizador de triangulos.
- Divisor inteiro.
- Modulo de controle superior.

Foram incluidas verificacoes de validade para impedir que comandos com coordenadas fora da tela iniciem a rasterizacao.


## 6.6 Compositor

Apos a validacao individual das camadas, elas foram integradas no compositor.

A sequencia de renderizacao utilizada e:

Background -> Poligonos -> Sprites


## 6.7 Integração na DE1-SoC

Por fim, os subsistemas foram conectados ao top-level da placa.

Para demonstracao, botoes e chaves permitem alterar alguns recursos graficos sem a necessidade do driver Linux.



# 7. Instalação E CONFIGURACAO

## 7.1 Pré-requisitos

Recomenda-se utilizar:

- Intel Quartus Prime com suporte ao Cyclone V.
- ModelSim Intel FPGA Edition ou Questa para simulacao.
- Placa Terasic DE1-SoC.
- Monitor compativel com VGA.
- Cabo USB-Blaster.

A sintese armazenada no repositorio foi realizada para:

5CSEMA5F31C6


## 7.2 Estrutura Geral do Projeto

Os principais arquivos RTL estao na raiz do projeto.

Os recursos de memoria estao organizados em:

memory_files/

Os resultados de compilacao estao organizados em:

output_files/


## 7.3 Observação Importante sobre o Projeto Quartus

O material analisado contem:

- Arquivos RTL.
- IPs.
- Arquivos .qip.
- Arquivos .mif.
- Relatorios de compilacao.
- Arquivo .sof.

Entretanto, na versao analisada do ZIP nao foi identificado o conjunto principal de arquivos .qpf/.qsf necessario para simplesmente abrir o projeto Quartus completo com todas as configuracoes e atribuicoes de pinos.

Assim, caso esses arquivos nao estejam disponiveis em outra versao do repositorio, podera ser necessario criar um novo projeto Quartus e adicionar os arquivos manualmente.


## 7.4 Configuração Básica

Criar um projeto para o dispositivo:

5CSEMA5F31C6

Definir como top-level:

DE1_SOC_golden_top

Adicionar os arquivos .v utilizados pelo projeto e os arquivos .qip das memorias/IPs.

Tambem devem ser restauradas as atribuicoes de pinos da DE1-SoC para:

- Clock.
- VGA.
- Switches.
- Push-buttons.
- LEDs e demais sinais utilizados.


## 7.5 Programação

O repositorio contem:

output_files/CoProcessador.sof

Esse arquivo pode ser utilizado para programacao temporaria da FPGA pelo Quartus Programmer, desde que corresponda a versao desejada do projeto e ao hardware utilizado.



# 8. Testes DE FUNCIONAMENTO

O projeto inclui testbenches especificos para os principais subsistemas.

Arquivos identificados:

tb_motor_background.v
tb_motor_sprite.v
tb_motor_sprite_espelhamento.v
tb_motor_sprite_prioridade.v
tb_motor_sprite_transparencia.v
tb_compositor_sobreposicao.v
tb_framebuffer_troca_buffers.v
tb_rasterizer_square.v
tb_rasterizer_triangle.v


## 8.1 Background

O teste do motor de background verifica o processo de geracao da camada com base no tilemap e nos padroes de tiles.


## 8.2 Transparência de Sprites

O testbench:

tb_motor_sprite_transparencia.v

verifica a regra:

indice de cor 0 -> nao escrever no framebuffer

Isso garante que regioes transparentes do sprite preservem o conteudo anteriormente desenhado.


## 8.3 Prioridade de Sprites

O teste:

tb_motor_sprite_prioridade.v

utiliza sprites sobrepostos com prioridades diferentes.

Um dos cenarios utiliza:

Sprite 0 -> prioridade 0
Sprite 1 -> prioridade 1

A expectativa e que o sprite de maior prioridade permaneça visivel na regiao de sobreposicao.


## 8.4 Espelhamento

O testbench:

tb_motor_sprite_espelhamento.v

exercita quatro situacoes:

- Sem flip.
- Flip horizontal.
- Flip vertical.
- Flip horizontal + vertical.


## 8.5 Sobreposição entre Camadas

O arquivo:

tb_compositor_sobreposicao.v

verifica a composicao das camadas.

O cenario utiliza:

Background -> verde
Poligono -> vermelho
Sprite -> azul

na regiao de sobreposicao.

Como o sprite e processado por ultimo, o resultado esperado nessa area e o pixel do sprite quando ele nao for transparente.


## 8.6 Double Buffering

O teste:

tb_framebuffer_troca_buffers.v

escreve conteudos diferentes nos dois bancos e verifica a alternancia do buffer de leitura.

Um dos cenarios utiliza o pixel:

(100, 100)

com valores distintos em cada framebuffer.


## 8.7 Retângulos

O arquivo:

tb_rasterizer_square.v

testa situacoes como:

- Coordenadas normais.
- Vertices invertidos.
- Retangulo de um pixel.
- Areas maiores.
- Diferentes indices de paleta.


## 8.8 Triângulos

O arquivo:

tb_rasterizer_triangle.v

exercita triangulos com diferentes formatos e inclinacoes, permitindo verificar a logica de ordenacao dos vertices e de preenchimento por linhas.


## 8.9 Comandos Inválidos

O rasterizador_top.v possui logica para rejeitar coordenadas fora da faixa valida:

0 <= X < 320
0 <= Y < 240

e gera sinalizacao:

invalid_cmd

Na versao analisada do repositorio, nao foi identificado um testbench separado dedicado exclusivamente a invalid_cmd, embora a validacao esteja presente no RTL.



# 9. Análise DO RESULTADO

## 9.1 Resultado Funcional

A arquitetura produz uma cadeia grafica composta por:

Tile background
      |
      v
Rasterizacao de poligonos
      |
      v
Sprites
      |
      v
Double framebuffer
      |
      v
VGA

O sistema demonstra conceitos centrais de uma unidade grafica dedicada:

- Separacao entre armazenamento de recursos e framebuffer.
- Composicao de multiplas categorias de objetos.
- Processamento independente do scanout VGA.
- Uso de memoria indexada.
- Prioridade e transparencia.
- Rasterizacao de primitivas em hardware.
- Sincronizacao entre producao e exibicao de frames.


## 9.2 Utilização de Recursos

Os relatorios de sintese presentes no projeto indicam aproximadamente:

ALMs:
709

Registradores:
996

Pinos:
241 / 457

Bits de memoria:
1.659.776 / 4.065.280

Blocos de RAM:
208 / 397

DSPs:
0

PLLs:
1 / 6

A maior parcela do custo da implementacao esta associada as memorias utilizadas pelos framebuffers, padroes graficos, tilemap, atributos e paletas.

O uso de 0 DSPs tambem mostra que as operacoes de rasterizacao foram implementadas sem depender dos blocos DSP dedicados da FPGA.


## 9.3 Temporização

Os relatorios analisados indicam folga positiva para os principais clocks do projeto.

Para o dominio de 50 MHz foi observada frequencia maxima reportada proxima de:

84,6 MHz

com setup slack aproximado de:

8,179 ns

Para o dominio de video de 25 MHz foi observada frequencia maxima proxima de:

92,64 MHz

e setup slack de aproximadamente:

13,278 ns

Esses valores indicam que, para a compilacao registrada nos relatorios, os clocks utilizados pelo sistema se encontram dentro das margens de temporizacao obtidas pela sintese.


## 9.4 Pontos Fortes da Arquitetura

A implementacao apresenta como principais pontos positivos:

- Divisao clara em modulos.
- Resolucao logica reduzida para economizar memoria.
- Reutilizacao de padroes por tiles.
- Sprites independentes do background.
- Atributos compactados em 32 bits.
- Suporte a flip sem duplicacao de padroes.
- Paleta indexada.
- Double buffering.
- Rasterizacao de primitivas em hardware.
- Testbenches especificos para funcionalidades criticas.
- Separacao entre dominio grafico e dominio de exibicao.


## 9.5 Limitações Atuais

A versao presente no repositorio ainda nao representa o sistema final completo descrito pelo problema.

As principais limitacoes sao:


# 1. AUSENCIA DO DRIVER LINUX/ARM

Nao foi identificado no projeto um driver Linux em ARM Assembly responsavel por controlar o coprocessador por MMIO.

A interface de top_video.v ja separa diversas operacoes de escrita, o que facilita uma integracao futura, mas essa ligacao ainda nao faz parte do material analisado.


# 2. AUSENCIA DA APLICACAO EM C

Nao foi identificado um jogo ou aplicacao em C controlando o hardware grafico.

A demonstracao atual utiliza principalmente controles locais da FPGA.


# 3. COMPOSICAO SEQUENCIAL

O compositor atual processa:

Background -> Poligonos -> Sprites

em fases distintas.

Portanto, nao existe nesta implementacao um compositor por pixel que receba simultaneamente todas as camadas e escolha dinamicamente o vencedor a partir de uma comparacao geral de prioridades.


# 4. TRANSPARENCIA DE POLIGONOS

A transparencia do indice de cor zero esta explicitamente implementada no motor de sprites.

Na versao analisada do rasterizador de poligonos, nao foi identificada uma regra equivalente que impeca a escrita do poligono quando seu indice de cor for zero.

Assim, nao se deve considerar a transparencia de poligonos como uma funcionalidade concluida apenas com base no RTL atual.


# 5. ARQUIVOS PRINCIPAIS DO PROJETO QUARTUS

A ausencia dos arquivos .qpf/.qsf no ZIP analisado dificulta a reproducao integral da compilacao a partir de um clone limpo.

Uma melhoria importante para o repositorio e incluir os arquivos de projeto e as atribuicoes de pinos necessarias para reconstruir a compilacao.


## 9.6 Melhorias Futuras

Como continuidade do projeto, podem ser desenvolvidos:

- Barramento de registradores/MMIO.
- Integracao FPGA-HPS da DE1-SoC.
- Driver Linux em ARM Assembly.
- Biblioteca de comandos graficos.
- Aplicacao ou jogo em C.
- FIFO de comandos graficos.
- Prioridade mais geral entre diferentes tipos de camada.
- Clipping mais completo.
- Transparencia configuravel para poligonos.
- Multiplos backgrounds.
- Animacao de sprites.
- Suporte a mais primitivas.
- Documentacao automatica dos registradores.
- Scripts completos de regressao de testes.



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



# 11. Estrutura DOS RECURSOS GRAFICOS

## 11.1 Background

Tilemap:

40 x 30 entradas
1200 posicoes
8 bits por entrada

Tile:

8 x 8 pixels
8 bits por pixel

Memoria de padroes:

256 tiles x 64 pixels
16384 posicoes


## 11.2 Sprites

Quantidade maxima:

32 sprites

Dimensao:

16 x 16 pixels

Atributos:

32 bits por sprite


## 11.3 Paleta

A memoria de paleta possui:

512 entradas x 9 bits

Na arquitetura implementada, ela pode ser vista como dois conjuntos de 256 posicoes, selecionados pelo sinal de escolha de paleta.


## 11.4 Framebuffer

Cada banco armazena:

320 x 240 = 76800 pixels

com:

9 bits por pixel

Sao utilizados dois bancos para implementacao do double buffering.



# 12. Equipe DO DESENVOLVIMENTO

Preencher com os integrantes oficiais do grupo:

Nome do integrante 1
Nome do integrante 2
Nome do integrante 3
...

Instituicao:
Universidade Estadual de Feira de Santana - UEFS

Disciplina:
Sistema Digital

Periodo:
2026.2



# 13. Referências

- TERASIC. DE1-SoC Development and Education Board - documentacao e recursos oficiais.
- INTEL. Cyclone V Device Documentation.
- INTEL. Cyclone V SoC Hard Processor System Technical Reference Manual.
- INTEL. Quartus Prime Documentation.
- INTEL. ModelSim / Questa FPGA Simulation Documentation.
- Documentacao do projeto Problema #1 - 2026.2 / Sistema Digital.
- Arquivos RTL, testbenches, relatorios de sintese e arquivos de inicializacao presentes neste repositorio.



# 14. Estado RESUMIDO DA IMPLEMENTACAO

Sistema VGA 640 x 480:
CONCLUIDO

Resolucao logica 320 x 240:
CONCLUIDO

Framebuffer:
CONCLUIDO

Double buffering:
CONCLUIDO

Background por tiles:
CONCLUIDO

Scroll horizontal e vertical:
CONCLUIDO

Wraparound:
CONCLUIDO

Sprites 16 x 16:
CONCLUIDO

32 slots de sprites:
CONCLUIDO

Prioridade de sprites:
CONCLUIDO

Transparencia de sprites:
CONCLUIDO

Flip horizontal e vertical:
CONCLUIDO

Rasterizacao de retangulos:
CONCLUIDO

Rasterizacao de triangulos:
CONCLUIDO

Paleta indexada:
CONCLUIDO

Testes dos principais modulos:
IMPLEMENTADOS

Demonstracao em hardware:
IMPLEMENTADA NO TOP-LEVEL

Interface Linux/HPS:
ETAPA FUTURA

Driver ARM Assembly:
ETAPA FUTURA

Jogo em C:
ETAPA FUTURA



# 15. Observação FINAL

Este repositorio representa a implementacao do nucleo grafico em FPGA do sistema proposto.

A arquitetura ja possui os principais blocos necessarios para a geracao de cenas:

- Background.
- Sprites.
- Poligonos.
- Paletas.
- Framebuffer.
- VGA.

A implementacao estabelece uma base para a futura integracao com o HPS da DE1-SoC e com uma camada de software responsavel pelo envio de comandos graficos
---

.
