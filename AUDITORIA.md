# AUDITORIA — FPGA Craft (Etapa 0)

Data: 2026-11-12 · Escopo: somente leitura. **Nenhum arquivo de código foi alterado.**
Entrada analisada: `fpgacraft.zip` (21 entradas). **Não foram fornecidos** `driver.zip` nem nenhum arquivo Verilog/SystemVerilog.

Legenda de confiança: **[MEDIDO]** = executei e observei · **[LIDO]** = li o código · **[NÃO VERIFICÁVEL]** = depende de RTL/driver ausentes.

---

## 0. Resumo executivo

1. **O núcleo do jogo tem um bug de física que o torna injogável** [MEDIDO]: o jogador nunca fica em repouso, oscila ~15 px por quadro e `on_ground` pisca (19 transições em 60 quadros), então o pulo falha na maior parte dos quadros.
2. **A comunicação com a FPGA é inverificável** [NÃO VERIFICÁVEL]. O ZIP traz `cop_api.c` (reescrita em C), mas o `cop_api.h` diz que a API real está em `api.S`. Sem `api.S`, sem RTL e sem `driver.zip`, nenhum opcode, codificação de instrução, semântica de scroll ou de sprite pôde ser conferido.
3. **O alvo "host" não é um jogo**: roda N quadros fixos e grava um PPM. Não há janela nem entrada interativa.
4. **O terreno gerado é praticamente intransponível** [MEDIDO]: degraus de até 8 blocos entre colunas vizinhas; o pulo alcança só 1,88 bloco.
5. Compila limpo (sem avisos, ASan/UBSan sem erros), mas **não existe nenhum teste automatizado**.

**Recomendação:** não confiar no código atual como base de física/terreno. Reaproveitar a ideia (mapa de bytes, tilemap circular + scroll por hardware, sprites) e reescrever o núcleo de forma testável. A Etapa 3 só deve começar após receber o RTL e o driver reais.

---

## 1. Estrutura atual do projeto

```
fpgacraft/
├── Makefile                 alvos: host, fpga, clean
├── README.md
├── fpgacraft-host.exe       ARTEFATO de build (PE32+ x86-64, 43 KB) — não é fonte
├── fpgacraft.ppm            ARTEFATO gerado (320x240, 230 KB) — não é fonte
├── include/
│   ├── minecraft.h          tipos Game/Player, constantes de mapa/blocos
│   ├── video.h              interface video_open/close/frame
│   ├── cop_api.h            API do coprocessador (diz "implementada em api.S")
│   ├── cop_api_c.h          redeclaração parcial da mesma API (duplicata)
│   ├── hps_0.h              gerado por swinfo2header (avalon_cmd_slave_0 @0x0, 16 B)
│   ├── hps_bridges.h        pontes HPS<->FPGA, registradores e bits de STATUS/CTRL
│   └── input.h              teclado/mouse via evdev
└── src/
    ├── minecraft.c   (2,4 KB)  lógica: mapa, terreno, física, mineração
    ├── main_host.c   (0,5 KB)  simulação determinística + PPM
    ├── video_host.c  (0,9 KB)  rasterizador de PPM em software
    ├── main_fpga.c   (0,8 KB)  loop principal na placa
    ├── video_fpga.c  (2,1 KB)  tiles/paleta/sprite/scroll via coprocessador
    ├── cop_api.c     (4,3 KB)  driver MMIO em C (/dev/mem)
    └── input.c       (7,1 KB)  leitura de /dev/input/event*
```

Total de código-fonte: ~20 KB. Os `.c` principais usam estilo compactado (linhas > 200 caracteres), o que dificulta manutenção.

## 2. Arquitetura existente

```
main_host ─┐                         ┌─ video_host  → PPM (320x240x3 em RAM estática)
           ├─► Game (minecraft.c) ───┤
main_fpga ─┘   mapa 64x32 bytes      └─ video_fpga  → cop_api.c → /dev/mem → LW bridge → avalon_cmd_slave
   ▲           jogador, câmera                          (fila de palavras de ISA de 32 bits)
   └─ input.c (evdev)
```

- **Mundo:** `uint8_t map[32][64]` (512×256 px). IDs: 0 vazio, 1 grama, 2 terra, 3 pedra, 4 carvão, 5 madeira, 6 folha, 7 bedrock.
- **Jogador:** inteiros em pixels, caixa de colisão 12×15, `vx = ±2`, pulo `vy = -6`, gravidade +1, terminal 7.
- **Câmera:** centralizada no jogador, limitada ao mundo. Vista de 320×240 (40×30 tiles).
- **Render FPGA:** tilemap 40×30 **circular** (`slot = (wy%30)*40 + (wx%40)`) + `scroll_bg(cam_x%320, cam_y%240)` + 1 sprite (jogador). Só envia tiles que mudaram (`oldmap`).
- **Render host:** pinta pixel a pixel para um buffer de 225 KB e grava PPM.
- **Entrada FPGA:** setas/A/D, Espaço/Enter, ESC; mouse relativo → cursor lógico em 320×240.

A consistência matemática do tilemap circular com o scroll é correta **se** o hardware somar o scroll com wrap em 320/240 [NÃO VERIFICÁVEL].

---

## 3. Erros e inconsistências

Severidade: **C** crítico · **A** alto · **M** médio · **B** baixo.

### Núcleo (`minecraft.c`)

| ID | Sev | Achado | Evidência |
|----|-----|--------|-----------|
| N1 | **C** | **Pouso incorreto.** `p->y = (ny/TS)*TS - 15` usa a linha da *cabeça* (`ny/TS`), mas a colisão ocorreu na linha dos *pés* (`(ny+14)/TS`). O jogador é teletransportado ~16 px para cima e cai de novo, em ciclo infinito. | [MEDIDO] repouso esperado y=97, observado oscilando 81↔96; `on_ground` com 19–37 transições em 60–120 quadros. |
| N2 | **C** | **Terreno impraticável.** Altura por coluna = `13 + rnd()%5`, independente entre colunas. | [MEDIDO] maior degrau = 8 blocos; salto máximo = 15 px (1,88 bloco). |
| N3 | A | `game_place` não verifica sobreposição com o jogador: o bloco é aceito dentro da caixa de colisão. | [MEDIDO] bloco colocado sobre o jogador foi aceito (dirt 20→19). |
| N4 | A | `game_mine`/`game_place`: alcance medido ao *canto* do tile, não ao centro; sem verificação de linha de visada; mineração atravessa blocos. | [LIDO] |
| N5 | A | `selected` é fixo em DIRT e não há função para trocá-lo; blocos de GRASS/LEAF/WOOD/COAL minerados não podem ser colocados. Sem inventário visual. | [MEDIDO]/[LIDO] |
| N6 | M | Colisão horizontal só aceita/rejeita o passo inteiro (sem encostar na parede); teto não ajusta `y`. | [LIDO] |
| N7 | M | Física acoplada ao número de quadros (sem passo de tempo fixo); `Player` guarda `score` não usado; `rng` global dentro de `Game`. | [LIDO] |
| N8 | M | Mundo só 64×32 blocos (rolagem vertical possível: 16 px). Sem persistência. | [LIDO] |
| N9 | B | Árvores a cada 13 colunas fixas, plantadas sem verificar o terreno vizinho; folhas podem sobrescrever terreno. | [LIDO] |

### Renderização / vídeo

| ID | Sev | Achado |
|----|-----|--------|
| V1 | **C** | `host` não é jogável: sem janela, sem teclado/mouse; entradas simuladas por fórmula (`(i/90)%2`). Os controles descritos no README só existem no alvo FPGA. |
| V2 | A | **Dois renderizadores divergentes** (`video_host.c` e `video_fpga.c`): paletas e padrões de tile diferentes. Não há gerador de tiles compartilhado, então o que se vê no PC não prediz o que se vê na placa. |
| V3 | A | **Sem cursor/mira na FPGA.** O mouse move um cursor lógico que nunca é desenhado; o jogador minera "às cegas". |
| V4 | M | Arte: STONE e BEDROCK usam a mesma cor base; COAL parece pedra; `pal[16]` declarado, 10 inicializados. |
| V5 | M | Sprite 16×16 para caixa de colisão 12×15; sprite totalmente opaco (nenhum pixel de índice 0) — transparência do índice 0 [NÃO VERIFICÁVEL]; `sx<0 → 0` distorce a posição na borda. |
| V6 | M | Origem/offset de coordenadas de sprite (x<512, y<256) [NÃO VERIFICÁVEL]; o código assume origem = canto superior esquerdo da tela. |
| V7 | B | `video_frame` varre 1200 tiles todo quadro (barato, mas desnecessário; basta atualizar na borda da câmera e nas edições). |

### Driver (`cop_api.c`, `cop_api.h`, `cop_api_c.h`, `hps_*.h`)

| ID | Sev | Achado |
|----|-----|--------|
| D1 | **C** | **Sem RTL/`api.S`/`driver.zip`:** a codificação das palavras de ISA (opcode `[31:27]`, bit imediato `[26]`, `rd[25:21]`, `rn[20:15]`, bit extra de `rd` em `[14]`, `imm[11:0]`), os registradores de rascunho (RA=0, RB=1, XZR=31, 37–40 e 43 para o retângulo) e a convenção do `scroll_bg` (x em RA com RB=0; y com RB=1) **não puderam ser conferidos**. |
| D2 | A | **6 funções declaradas em `cop_api.h` e não implementadas:** `cop_has_error`, `cop_clear_flags`, `cop_wait_idle`, `cop_load_palette`, `cop_draw_tri`, `cop_clear_screen` [MEDIDO via `nm`]. |
| D3 | A | **Flags ERROR/OVERFLOW são "travas"** (`hps_bridges.h`), mas o jogo nunca lê nem limpa. Um estouro de fila congela o vídeo sem diagnóstico. |
| D4 | M | `cop_init`: após `SOFT_RESET` testa `INIT_BUSY==0 && PLL_LOCKED` imediatamente — pode ler o estado *anterior* ao reset (corrida). |
| D5 | M | `cop_api.h` e `cop_api_c.h` duplicam declarações; `cop_api.c` usa `regp(b, off)` ignorando `HPS_LW_COPROC_OFFSET` (hoje 0, então inofensivo). |
| D6 | M | `cop_push` e `cop_wait_frame` fazem polling ocupado (até 2 M leituras na ponte LW); 100% de CPU e tempo de timeout não calibrado. |
| D7 | M | Escrita de tile/sprite gasta ~3 palavras por pixel (`PASS`/`WRITE`/`ADD`): ~190 palavras/tile, ~770/sprite. Aceitável na inicialização, mas não medido. |
| D8 | B | Comentários do `input.h` citam "acelerômetro", que o jogo não usa (resíduo de outro projeto). `hps_0.h` aponta para um caminho Windows do projeto original (RTL não incluído). |

### Entrada (`input.c`)

| ID | Sev | Achado |
|----|-----|--------|
| I1 | M | Dispositivo combinado (handlers `kbd` **e** `mouse`) é aberto duas vezes; cada evento é tratado duas vezes (movimento do mouse dobra). |
| I2 | M | Detecção de teclado exige `EV_REP`; teclados sem repetição são ignorados. |
| I3 | B | Sem tecla para escolher bloco; só ESC encerra. |

### Build e projeto

| ID | Sev | Achado |
|----|-----|--------|
| B1 | A | **Zero testes automatizados.** |
| B2 | M | `Makefile`: sem dependência de headers; `clean` não remove `.exe`; sem alvo de teste; sem alvo Windows com janela. |
| B3 | M | ZIP contém artefatos binários (`.exe`, `.ppm`) misturados ao código-fonte. |
| B4 | B | README afirma que a lógica é "testada" em modo host; o teste é só "gera um PPM". |

---

## 4. Comparação driver × headers × RTL

| Item | `cop_api.h` | `hps_bridges.h` / `hps_0.h` | `cop_api.c` | RTL |
|------|-------------|------------------------------|-------------|-----|
| Base LW | — | `0xFF200000`, 2 MB | mmap idêntico | ausente |
| Offset/tamanho do slave | — | `0x0`, 16 B (coerente nos dois headers) | usa offset 0 | ausente |
| Registradores | — | CMD `0x00` W · STATUS `0x04` R · CTRL `0x08` W · ID `0x0C` R | mesmos offsets | ausente |
| ID | — | `0xC0DE0001` | confere em `cop_init` | ausente |
| STATUS | — | FULL b0, EMPTY b1, RUNNING b2, WAITING b3, VBLANK b4, ERROR b5, OVERFLOW b6, INIT_BUSY b7, PLL_LOCKED b8, FRAME_COUNT `[31:16]` | usa FULL, INIT_BUSY, PLL_LOCKED, FRAME_COUNT | ausente |
| Geometria | 320×240; tilemap 40×30; tile 8×8; 256 padrões de tile; sprite 16×16; 32 sprites; 64 padrões; 2 paletas × 256 cores de 9 bits | — | valida os mesmos limites | ausente |
| Opcodes | declara só a API | — | usa ADD=1, LSL=4, LSR=5, PASS=6, SET_PALETTE=7, DRAW_RECT=8, SET_SPR_POS=10, SET_SPR_ATTR=11, SET_TILEMAP=12, SCROLL_BG=13, WRITE_SPR=14, WRITE_TILE=15, DRAW_BG=16, DRAW_SPR=17, HALT=19 | ausente |
| Opcodes sem uso | — | — | 0, 2, 3, 9, 18 e ≥20: **semântica desconhecida** (não presumir) | ausente |

**Conclusões:**
- Internamente os arquivos são **consistentes entre si** (endereços, offsets, geometria, constantes de limite).
- **Nenhum comportamento real de hardware foi confirmado.** O comentário do `cop_api.h` afirma que os limites "vêm da RTL" (`unidade_de_controle.v`, `banco_registradores.v`, `rasterizador_top.v`, `motor_sprite.v`, `motor_background.v`) — esses arquivos **não foram fornecidos**.
- O próprio `cop_api.h` menciona **"double buffer"** e rasterizador (`draw_rect`, `draw_tri`, `clear_screen`). Isso sugere que **o RTL possui framebuffer em memória da FPGA**, o que conflita com a regra 6 do briefing. O jogo atual só usa tilemap + sprite (não depende de `draw_rect/tri/clear`), mas isso precisa ser confirmado no RTL.

## 5. Instruções e registradores disponíveis (segundo o que está documentado)

- **Utilizáveis pelo jogo (documentadas e implementadas em `cop_api.c`):** `SET_PALETTE`, `SET_TILEMAP`, `WRITE_TILE`, `WRITE_SPR`, `SET_SPR_POS`, `SET_SPR_ATTR`, `SCROLL_BG`, `DRAW_BG`, `DRAW_SPR`, `HALT` (apresentar quadro), `DRAW_RECT`.
- **Documentadas mas não implementadas:** `draw_tri`, `clear_screen`, `load_palette`, leitura de erro, limpeza de flags, espera de ocioso.
- **Limites de hardware declarados:** 32 sprites, 64 padrões de sprite, 256 padrões de tile, 2 paletas de 256 entradas (RGB 3-3-3), prioridade `fundo < rasterizadores < sprites`, posição de sprite x<512 / y<256.
- **Tudo acima é "segundo o header"**, não confirmado por RTL.

## 6. Estimativa de consumo de memória

**Software (HPS/ARM) — medido** [MEDIDO, x86-64 como referência]:

| Item | Tamanho |
|------|---------|
| `sizeof(Game)` (mapa 2048 + jogador 60 + câmera 8 + rng 4) | 2.120 B |
| `sizeof(input_t)` | 104 B |
| `oldmap` + paleta (`video_fpga.c`) | 1.232 B |
| Binário FPGA (text+data+bss) | ≈ 16 KB |
| Binário host (bss dominado por buffer PPM) | ≈ 236 KB (inclui 230.400 B de imagem; **só existe no host**) |

→ O lado software do alvo FPGA usa **~20 KB**. Não há framebuffer no HPS. O alvo host (PC) tem 230 KB apenas para o PPM; não é o limite da placa.

**FPGA — inferido das constantes do `cop_api.h`** [NÃO VERIFICÁVEL sem RTL]:

| Memória | Cálculo | Tamanho |
|---------|---------|---------|
| Padrões de tile | 256 × 64 px × 8 b | 16 KiB |
| Padrões de sprite | 64 × 256 px × 8 b | 16 KiB |
| Tilemap | 1200 × 8 b | 1,2 KiB |
| Paletas | 2 × 256 × 9 b | 0,56 KiB |
| Registradores de sprite | 32 × (17 + 15 b) | ~0,13 KiB |
| **Subtotal (sem framebuffer)** | | **≈ 34 KiB** |
| Framebuffer duplo, *se existir* | 2 × 320 × 240 × (8–9 b) | ≈ 150–170 KiB |

Mesmo com framebuffer, a soma estimada fica bem abaixo de 512 KB. **Preciso que você confirme a que se refere o limite de 512 KB** (M10K da FPGA? orçamento do software? outro?), pois o README original também levanta essa dúvida. O Cyclone V da DE1-SoC tem ≈ 4,4 Mb (≈ 556 KB) de M10K, o que sugere que o limite se refere à FPGA.

## 7. Funcionalidades

| Funcionalidade | Estado |
|----------------|--------|
| Mapa 64×32 e blocos | Implementado (pequeno) |
| Geração de terreno | **Incompleta** (injogável, N2) |
| Árvores | Implementado (ingênuo) |
| Jogador / gravidade | **Com defeito** (N1) |
| Colisões | Parcial |
| Pulo | Defeituoso (consequência de N1) |
| Mineração / colocação | Parcial (N3–N5) |
| Inventário | Contadores sem UI; sem seleção |
| Câmera | Implementado |
| Renderização FPGA (tilemap+scroll+sprite) | Implementado, **não validado** |
| Renderização host | Só PPM estático |
| Janela interativa no PC | **Ausente** |
| Entrada na placa (evdev) | Implementado, não testado; sem cursor visível |
| Cursor/mira, hotbar, HUD | **Ausente** |
| Testes automatizados | **Ausente** |
| Salvamento, crafting, iluminação, água, áudio, mobs | Ausente (fora do escopo mínimo) |

---

## 8. Plano de correção priorizado

Princípios: núcleo independente de hardware; um único gerador de gráficos procedural compartilhado entre PC e FPGA; passo de tempo fixo; testes antes de integrar.

**ETAPA 1 — Núcleo** (independe de RTL; pode começar já)
1. 1.1 Reestruturar em `core/` (`world`, `player`, `terrain`, `inventory`, `game`) sem dependência de hardware; remover estilo compactado.
2. 1.2 Corrigir pouso/colisão por eixo com resolução contra a grade (N1, N6); passo de tempo fixo.
3. 1.3 Terreno suave (variação limitada a ±1 por coluna, camadas, minério, árvores válidas) — garantir percurso transponível (N2, N9).
4. 1.4 Mineração/colocação: alcance do centro, linha de visada, bloqueio de colocação sobre o jogador (N3, N4).
5. 1.5 Inventário com hotbar e seleção (N5).
6. 1.6 Testes automatizados em C puro (`tests/`, alvo `make test`): pouso, pulo, degraus, colisões, mineração, colocação, determinismo, limites.

**ETAPA 2 — Simulador Windows**: `platform_win32.c` com Win32/GDI (C puro, nada além do MinGW), loop de 60 Hz, mesmo gerador procedural de tiles/sprites, cursor, hotbar, HUD. Compilável por `make win` (GCC/MSYS2).

**ETAPA 3 — Interface FPGA** — **bloqueada até receber RTL e `driver.zip`/`api.S`**. Reconferir cada opcode, codificação, scroll, sprites/transparência, limites e VBlank; implementar `has_error`, `clear_flags`, `wait_idle`; corrigir corrida do `cop_init` (D4).

**ETAPA 4 — Integração**: backend `video_fpga` usando o gerador compartilhado; cursor por sprite; medir desempenho/quadro; relatório de testes (só marcar "validado" o que rodar na placa).

**ETAPA 5 — Finalização**: otimização, README, limitações, ZIP final.

## 9. Pendências e perguntas ao usuário

1. **Enviar `driver.zip`** (com `api.S`, headers e Makefile originais) e **todo o Verilog/SystemVerilog** (`unidade_de_controle.v`, `banco_registradores.v`, `rasterizador_top.v`, `motor_sprite.v`, `motor_background.v`, `avalon_cmd_slave` e o topo). Necessários para a Etapa 3.
2. **Qual é o escopo dos 512 KB?** (memória da FPGA, RAM do HPS ou orçamento do software.)
3. **Janela no Windows:** proponho Win32/GDI (C puro, sem dependências). Aceita? (Alternativa: SDL2, que exige instalação.)
4. **Autoriza reescrever o núcleo** em vez de remendar o `minecraft.c` atual? (Recomendado: o arquivo é difícil de testar e os erros são estruturais.)
5. **O RTL tem framebuffer?** O `cop_api.h` fala em "double buffer"; isso impacta a regra 6. A resposta sai do RTL.
6. Os binários `.exe` e `.ppm` do ZIP devem ser descartados do projeto final? (Proponho que sim.)

## 10. O que NÃO foi feito/validado

- Nenhum teste em hardware real; nenhuma execução em ARM (não há cross-compiler no ambiente).
- O alvo FPGA foi **compilado nativamente em x86-64** apenas para checar sintaxe/link; **não foi executado**.
- Nenhuma afirmação sobre o comportamento do coprocessador foi confirmada.
- As sondas de física usadas nesta auditoria estão em `audit/` (fora de `src/`, não fazem parte do build).
