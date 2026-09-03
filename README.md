# CoProcessador Grafico em FPGA - Sistema Digital 2026.2

## Sumário

- [1. Visão Geral do Projeto](#1-visão-geral-do-projeto)
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

O projeto consiste no desenvolvimento de um coprocessador grafico em FPGA capaz de executar operacoes graficas sem depender do processador principal para desenhar individualmente cada pixel da imagem.

A proposta segue o principio de arquiteturas graficas utilizadas em consoles classicos, nas quais circuitos especializados sao responsaveis por gerar background, sprites e primitivas geometricas.

A imagem e construida logicamente em resolucao de 320 x 240 pixels. Para exibicao em um monitor VGA de 640 x 480 pixels, cada pixel logico e reproduzido em um bloco de 2 x 2 pixels fisicos.

A implementacao foi organizada em tres camadas graficas principais:

# 1. Background baseado em tiles.
# 2. Poligonos rasterizados, atualmente retangulos e triangulos preenchidos.
# 3. Sprites, com suporte a posicao, padrao grafico, prioridade, selecao de paleta e espelhamento horizontal e vertical.

O resultado dessas etapas e armazenado em um framebuffer.

O sistema utiliza double buffering, mantendo dois buffers. Enquanto um e exibido pelo controlador VGA, o outro pode ser atualizado pelos motores graficos. A troca dos buffers ocorre durante o intervalo de vertical blanking, reduzindo artefatos visuais causados pela alteracao de pixels durante a leitura da imagem.

O modulo de nivel superior utilizado no projeto e:

DE1_SOC_golden_top.v

A integracao principal do sistema de video e realizada em:

top_video.v



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



# 3. Fundamentação TEORICA

## 3.1 Representação Gráfica Indexada

Em vez de armazenar diretamente a intensidade de vermelho, verde e azul de cada recurso grafico, o sistema trabalha principalmente com indices de cor.

Um pixel armazenado nos padroes de tiles ou sprites possui 8 bits e representa uma posicao da paleta.

A paleta converte o indice em uma palavra de cor de 9 bits utilizada pelo sistema de video.

Essa abordagem reduz a quantidade de memoria necessaria para armazenar imagens e permite alterar varias cores de um recurso modificando somente a paleta.


## 3.2 Background Baseado em Tiles

Um sistema de tiles divide a tela em pequenos blocos reutilizaveis.

Neste projeto, cada tile possui:

8 x 8 pixels

Como a tela logica possui:

320 x 240 pixels

temos:

320 / 8 = 40 tiles na horizontal

240 / 8 = 30 tiles na vertical

Portanto, o tilemap possui:

40 x 30 = 1200 entradas

Cada entrada do tilemap contem o indice de um padrao armazenado na memoria de padroes.

Para determinar o pixel do background, o sistema utiliza a posicao atual do pixel, aplica os valores de scroll, identifica o tile correspondente e acessa o pixel correto dentro do padrao selecionado.


## 3.3 Scroll e Wraparound

O scroll altera a origem da imagem exibida sem alterar fisicamente todo o conteudo do tilemap.

Sao mantidos deslocamentos horizontal e vertical.

Esses deslocamentos sao utilizados nas coordenadas logicas antes do calculo do tile correspondente.

Quando a coordenada ultrapassa o limite da area grafica, a logica realiza o retorno para o inicio, criando o efeito de wraparound.

Isso permite que o cenario se desloque continuamente.


## 3.4 Sprites

Sprites sao objetos graficos independentes do background.

Cada sprite possui uma palavra de atributos com 32 bits.

Na implementacao analisada, a codificacao utilizada e:

Bit 31       - Enable
Bits 30:26   - Prioridade
Bit 25       - Flip vertical
Bit 24       - Flip horizontal
Bit 23       - Selecao de paleta
Bits 22:17   - Indice do padrao
Bits 16:9    - Coordenada Y
Bits 8:0     - Coordenada X

Os sprites possuem dimensao de:

16 x 16 pixels

Internamente, cada sprite e formado por quatro regioes de 8 x 8 pixels.

O motor de sprites percorre os niveis de prioridade e os 32 slots de atributos.

Para cada sprite habilitado, verifica se o pixel correspondente deve ser escrito no framebuffer.

O indice de cor 0 e tratado como transparente. Portanto, pixels com esse indice nao sobrescrevem a imagem previamente desenhada.


## 3.5 Espelhamento

O flip horizontal e vertical e realizado modificando a coordenada local utilizada para acessar o padrao.

Para uma coordenada local x de um sprite 16 x 16:

x_flip = 15 - x

De forma equivalente:

y_flip = 15 - y

Com isso, o mesmo padrao grafico pode ser exibido em diferentes orientacoes sem armazenar novas versoes da imagem em memoria.


## 3.6 Rasterização

Rasterizacao e o processo de transformar uma descricao geometrica em pixels.

O projeto implementa dois tipos de primitivas:

- Retangulos preenchidos.
- Triangulos preenchidos.

O rasterizador de retangulos normaliza as coordenadas recebidas, determinando os valores minimo e maximo em cada eixo e percorrendo toda a regiao correspondente.

O rasterizador de triangulos ordena os vertices pela coordenada Y e calcula incrementalmente os limites esquerdo e direito de cada linha do triangulo.

A implementacao utiliza aritmetica inteira/fixa e um divisor sequencial dedicado.


## 3.7 Double Buffering

Se o mesmo framebuffer estiver sendo lido pelo VGA e modificado simultaneamente pelos motores graficos, partes de dois estados diferentes da cena podem ser exibidas na mesma atualizacao.

Para evitar esse problema sao utilizados dois buffers.

Buffer A -> exibido
Buffer B -> escrito

Apos a construcao do novo quadro:

Buffer B -> exibido
Buffer A -> escrito

A troca ocorre no periodo de VBlank.


## 3.8 VGA

O clock principal da placa e:

50 MHz

Um PLL gera o clock aproximado de:

25 MHz

utilizado pelo controlador VGA.

A saida fisica opera em:

640 x 480 pixels

As coordenadas fisicas sao convertidas para coordenadas logicas utilizando uma divisao por dois.

Dessa forma, cada pixel logico e visualizado como quatro pixels fisicos.



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
