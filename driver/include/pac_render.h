/* ============================================================================
 * pac_render.h - Carga dos recursos e desenho de cada quadro (so a API cop_*)
 *
 * Disposicao na tela (320 x 240):
 *   - labirinto de 28 colunas nas colunas de tile 6..33 (x = 48..271);
 *   - painel esquerdo (colunas 0..5): SCORE e pontuacao;
 *   - painel direito (colunas 34..39): FPS medido;
 *   - scroll vertical de 4 px: as 30 linhas do mapa mostram as linhas 0..29 do
 *     labirinto e os sprites da ultima linha de corredor ficam inteiros na tela.
 * ========================================================================== */
#ifndef PAC_RENDER_H
#define PAC_RENDER_H

#include <stdint.h>
#include "pac_core.h"

#define PAC_SCREEN_X0       48      /* x da tela onde comeca o labirinto (6 colunas de tile)  */
#define PAC_SCROLL_Y        4       /* scroll vertical do fundo                                */
#define PAC_SPRITE_PACMAN   0

typedef struct {
    int32_t  attr_sent;      /* ultimo atributo do Pac-Man enviado (-1 = nenhum)   */
    int      drawn_score;    /* placar ja desenhado (-1 = nenhum)                  */
    int      drawn_fps;      /* fps ja desenhado (-1 = nenhum)                     */
    int      blink_on;       /* estado do energizer na paleta (-1 = desconhecido)  */
    uint32_t frames;         /* quadros desenhados                                 */
} pac_render_t;

/* Carrega paleta, tiles, padroes de sprite, mapa inteiro (1200 posicoes), scroll e
 * desliga os 32 sprites. Chame uma vez, depois de cop_init. 0 ou erro negativo da API. */
int  pac_load_assets(void *base);

void pac_render_init(pac_render_t *r);

/* Envia os comandos de um quadro (sem o HALT: quem fecha e cop_present).
 * Consome os pontos comidos (p->n_ev = 0). "fps" e mostrado no painel direito. */
int  pac_render_frame(pac_render_t *r, void *base, pac_t *p, int fps);

#endif /* PAC_RENDER_H */
