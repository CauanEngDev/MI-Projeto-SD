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



# 4. Arquitetura DO SISTEMA

A arquitetura implementada possui os seguintes blocos principais:

DE1_SOC_golden_top
        |
        v
Controle da demonstracao
        |
        v
top_video
        |
        +----------------------+
        |                      |
        v                      v
Motor de Background       Rasterizador
        |                 de Poligonos
        |                      |
        +----------+-----------+
                   |
                   v
             Motor de Sprites
                   |
                   v
               Compositor
                   |
                   v
          Double Framebuffer
                   |
                   v
              VGA Driver
                   |
                   v
             Saida VGA


## 4.1 Fluxo de Composição

O modulo compositor.v organiza a construcao do quadro de forma sequencial:

Background
    |
    v
Poligonos
    |
    v
Sprites

Portanto, a solucao atual nao realiza uma comparacao simultanea de tres camadas para cada pixel.

Cada etapa escreve sobre o framebuffer apos a anterior.

Como pixels transparentes de sprites nao sao escritos, o conteudo ja existente permanece visivel nessas posicoes.

Essa organizacao simplifica a arbitragem de memoria e estabelece a ordem de camadas utilizada pela demonstracao.


## 4.2 Principais Módulos


DE1_SOC_golden_top.v

E o top-level da placa DE1-SoC.

Responsavel por:

- Conexao com CLOCK_50.
- Botoes KEY.
- Chaves SW.
- Interface VGA.
- Controles de demonstracao.
- Controle do movimento e flip de sprites.
- Criacao de sprites.
- Geracao de comandos de teste para poligonos.
- Instanciacao de top_video.


top_video.v

Integra o subsistema grafico.

Possui interfaces para:

- Escrita no tilemap.
- Escrita em padroes de background.
- Atributos de sprites.
- Padroes de sprites.
- Paleta.
- Scroll.
- Comandos de rasterizacao.
- Framebuffer.
- Controlador VGA.

Essas interfaces tambem formam uma base para uma futura integracao com um processador por registradores ou MMIO.


motor_background.v

Responsavel pela geracao do background a partir do tilemap e dos padroes de tiles.

Implementa:

- Tiles de 8 x 8.
- Tilemap 40 x 30.
- Scroll horizontal.
- Scroll vertical.
- Wraparound.
- Acesso a paleta.
- Escrita da camada de background no framebuffer.
- Cache de linha para auxiliar o processamento.


motor_sprite.v

Renderiza os sprites armazenados na memoria de atributos.

Implementa:

- Ate 32 sprites.
- Enable.
- Posicao X/Y.
- Prioridade.
- Selecao de padrao.
- Selecao de paleta.
- Flip horizontal.
- Flip vertical.
- Transparencia do indice 0.


subsistema_sprite.v

Integra as memorias e sinais relacionados ao subsistema de sprites.


sprite_mover_flip.v

Modulo de demonstracao utilizado para alterar atributos de um sprite atraves dos controles fisicos da placa.

Permite:

- Movimentacao.
- Flip horizontal.
- Flip vertical.


sprite_spawner.v

Cria novos sprites em posicoes definidas pelas chaves da placa enquanto existirem slots disponiveis na memoria de atributos.


rasterizador_top.v

Interface superior dos rasterizadores.

Responsavel por:

- Validar as coordenadas recebidas.
- Iniciar o rasterizador correspondente.
- Informar busy.
- Informar done.
- Sinalizar comandos invalidos.

As coordenadas validas sao:

0 <= X < 320
0 <= Y < 240


rasterizador_quadrado.v

Rasteriza retangulos preenchidos.

O modulo aceita vertices em diferentes ordens e determina internamente os valores minimos e maximos das coordenadas antes de gerar os pixels.


rasterizador_triangulo.v

Rasteriza triangulos preenchidos.

A implementacao:

# 1. Ordena os vertices por Y.
# 2. Calcula as inclinacoes das arestas.
# 3. Percorre cada linha do triangulo.
# 4. Determina os limites esquerdo e direito.
# 5. Gera os pixels entre os limites.


divisor_unsigned.v

Divisor inteiro sem sinal implementado de forma sequencial.

E utilizado pelo rasterizador de triangulos para obtencao das inclinacoes necessarias ao preenchimento.


framebuffer.v

Gerencia os dois bancos de framebuffer.

Responsavel por:

- Selecao do buffer de leitura.
- Selecao do buffer de escrita.
- Sincronizacao entre dominio do sistema e dominio de video.
- Troca de buffers.


fb_addr_gen.v

Converte coordenadas x e y em endereco linear do framebuffer.

A relacao utilizada e equivalente a:

endereco = y x 320 + x

ou seja:

endereco = y * 320 + x


vga_driver.v

Gera os sinais de temporizacao VGA e fornece as coordenadas do pixel atualmente exibido.


tile_memory.v

Modulo relacionado ao armazenamento e acesso de tiles utilizado pelo sistema grafico.



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
