# Pac-Man no coprocessador gráfico: marco 1

Labirinto, Pac-Man se movendo, pontos e energizers, placar, e medição de desempenho. Os fantasmas, as vidas, as fases e os dois modos entram nos marcos seguintes (seção 7).

## 1. Arquivos

| Arquivo | Onde fica | O que é |
|---|---|---|
| `maze.txt` | `driver/assets/` | Labirinto em ASCII (28 × 31). Fonte da **estrutura**; só a ferramenta e os testes o leem. |
| `gen_pac_assets.py` | `driver/tools/` | Valida o labirinto e gera os dados gráficos (arte **provisória**). |
| `pac_assets.h`, `pac_assets_data.c` | `driver/include/`, `driver/src/` | **Gerados**: tiles, mapa, classes de tile, sprites e paleta. Ficam versionados. |
| `maze.c/.h` | `driver/src/`, `driver/include/` | Grade lógica derivada dos dados (classes de tile). |
| `pac_core.c/.h` | idem | Movimento do Pac-Man, pontos e pontuação. Lógica pura. |
| `pac_input.c/.h` | idem | Teclado e mouse viram a direção pedida. Lógica pura. |
| `pac_render.c/.h` | idem | Carga dos recursos e desenho de cada quadro, só pela API `cop_*`. |
| `pac_app.c/.h`, `pac_main.c` | idem | Laço do jogo e `main`. |
| `perf.c/.h` | idem | Medição de desempenho. |
| `input.c/.h`, `compat_linux.h` | idem | Entrada (agora com setas, delta do mouse e tempo do evento). |
| `Makefile`, `tests/` | `driver/` | Alvos `all`, `assets` e `test`; testes de lógica e de ponta a ponta. |

## 2. Compilar e rodar na placa

```sh
cd driver
make                                  # compila estrelas e pacman (gcc na placa)
sudo ./pacman --frames 1800 --perf pac_perf.csv
```

Com cross-compilador no PC: `make CC=arm-linux-gnueabihf-gcc CFLAGS="-O2 -std=gnu11 -static"`.

| Opção | Efeito |
|---|---|
| `--frames N` | Termina após N quadros (1800 = 30 s a 60 quadros/s). Sem a opção, roda até ESC. |
| `--perf ARQ.csv` | Grava a medição, um registro por segundo. |
| `--kbd`, `--mouse` | Caminhos dos dispositivos (por padrão detecta). |

**Controles:** setas ou WASD, ou movimento do mouse (o deslocamento acumulado passa de um limiar e define a direção). ESC sai.

**Na tela:** labirinto no centro, `SCORE` à esquerda e `FPS` (medido) à direita. O labirinto tem 31 linhas e a tela comporta 30 de tiles; por isso há um scroll vertical de 4 px e a borda inferior (só parede) fica de fora. Os 244 itens e o túnel estão completos.

## 3. Como ler a medição

Ao terminar, o programa imprime um resumo e confere os dois requisitos do `PBL03`:

```
quadros: ...  | passos de logica: ...
periodo entre quadros (ms): p50 | p95 | p99 | max
envio dos comandos por quadro (ms): media | max
espera do vblank por quadro (ms): media | max
latencia entrada -> troca de buffer (ms): p50 | p95 | p99 | max
CPU: X% do tempo total | Y% sem a espera ativa do vblank
[OK/FALHOU] >= 30 atualizacoes/s ...
[OK/FALHOU] latencia <= 100 ms ...
```

Colunas do CSV: `t_s, fps, logic_steps_s, push_ms_avg, push_ms_max, present_wait_ms_avg, present_wait_ms_max, input_frames, input_latency_ms_avg, input_latency_ms_max, cpu_pct, cpu_excl_present_pct`.

Cuidados na interpretação:

- A **latência** vai do instante do evento do kernel (teclado ou mouse) até o retorno de `cop_present`, a troca de buffer. A imagem só aparece depois da varredura, que leva até 16,7 ms. O veredito soma esse tempo ao p99.
- Só há latência com **entrada durante a medição**: mexa no mouse ou nas teclas enquanto o programa roda.
- A espera do vblank é **ativa** (o driver consulta o `STATUS` em laço), então o uso de CPU total fica alto. A segunda cifra de CPU desconta essa espera e mostra o custo real do jogo.

## 4. Dados gráficos

`maze.txt` é a única fonte da estrutura. `make assets` regenera `pac_assets.h` e `pac_assets_data.c`. O jogo **não gera arte em tempo de execução**: carrega tiles, mapa, classes e sprites prontos, e deriva a grade lógica do mapa pela tabela de classes (parede, caminho, ponto, energizer, porta). Para usar arte definitiva, basta trocar as funções `build_*` do gerador por uma leitura de PNG; o formato de saída e o jogo não mudam.

A arte atual é provisória: paredes em contorno azul de 2 px, pontos e energizers simples e Pac-Man procedural (3 quadros de boca, direita e cima, com esquerda e baixo por espelhamento).

## 5. Testes

| Comando | O que verifica |
|---|---|
| `make test` | Lógica no host, com sanitizadores: o mapa gerado reproduz o ASCII; um jogador automático limpa o labirinto com exatamente 2600 pontos; 3 milhões de passos aleatórios; a medição com relógio falso; a conversão de entrada em direção. |
| `sh tests/e2e/run_e2e.sh` | O jogo inteiro sobre a API real em Assembly, com as palavras reproduzidas na RTL real: mapa, sprites, scroll, piscar dos energizers e estrutura de cada quadro, em 3600 quadros. Também erros de ERROR, vblank e fila, só mouse e 20 mil quadros aleatórios. Gera `build/e2e/pac_frames.png`. |

No último resultado, a fila de comandos usou em média 10,6 palavras por quadro e no máximo 25 (a fila comporta 64). A carga de recursos custa 13 043 palavras.

## 6. O que ainda não está verificado

- **Execução na placa.** Tudo acima foi verificado em simulação (QEMU e RTL). A taxa de quadros real, a latência e o uso de CPU dependem da medição na placa. O custo de `DRAW_BG` e de `DRAW_SPRITES` com vários sprites ainda é uma incógnita e define o orçamento dos fantasmas.
- **Velocidades.** Os 80%, 90% e 100% do Pac-Man por nível seguem o Pac-Man Dossier, mas os valores precisam ser conferidos contra a fonte antes dos marcos de dificuldade.
- O acelerômetro ainda não é usado (entra com o fantasma do segundo jogador).

## 7. Próximos marcos

1. **Medição na placa** com `--perf`, para fixar o orçamento por quadro.
2. **Fantasmas** com a IA original (alvos de Blinky, Pinky, Inky e Clyde, modos scatter, chase, frightened e eaten, saída da casa), colisões e vidas.
3. **Fases e modo contra a máquina:** tabelas de velocidade e tempo por fase (3 fases), menu, pausa, fim de fase e de jogo.
4. **Modo jogador contra jogador:** fantasma controlado pelo acelerômetro e a regra de vitória.
5. **Arte definitiva** (PNG), cores por fase e polimento.

Sugestão para o `.gitignore`: `driver/build/`, `driver/estrelas`, `driver/pacman`.
