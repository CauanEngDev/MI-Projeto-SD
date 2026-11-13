/* ============================================================================
 * input.h - Teclado e mouse via evdev (/dev/input/eventN)
 *
 * O driver le os eventos no ARM (Linux) e entrega um estado simples ao jogo:
 *   - teclas logicas: esquerda (seta ou A), direita (seta ou D),
 *     acao (espaco ou enter), sair (ESC);
 *   - mouse: posicao absoluta limitada a tela (0..319, 0..239) e botoes.
 * Cada tecla/botao tem NIVEL (esta pressionado agora) e BORDA (foi pressionado
 * desde o ultimo input_poll). A borda e marcada por evento, entao um toque
 * mais curto que um quadro nao se perde.
 *
 * As leituras sao nao bloqueantes: input_poll() nunca espera por eventos.
 * ========================================================================== */
#ifndef INPUT_H
#define INPUT_H

#include <stdint.h>

#define INPUT_MAX_DEVS   8
#define INPUT_SCREEN_W   320
#define INPUT_SCREEN_H   240

/* Teclas logicas (campos keys e key_edges) */
enum {
    INPUT_LEFT   = 1u << 0,
    INPUT_RIGHT  = 1u << 1,
    INPUT_ACTION = 1u << 2,
    INPUT_QUIT   = 1u << 3
};

/* Botoes do mouse (campos buttons e button_edges) */
enum {
    INPUT_MOUSE_LEFT  = 1u << 0,
    INPUT_MOUSE_RIGHT = 1u << 1
};

typedef struct {
    int      kbd_fd[INPUT_MAX_DEVS];
    int      n_kbd;
    int      mouse_fd[INPUT_MAX_DEVS];
    int      n_mouse;

    uint32_t keys;          /* nivel: teclas logicas pressionadas             */
    uint32_t key_edges;     /* bordas de subida durante o ultimo input_poll   */
    uint32_t buttons;       /* nivel: botoes do mouse                         */
    uint32_t button_edges;  /* bordas dos botoes durante o ultimo input_poll  */
    int      mouse_x;       /* 0..INPUT_SCREEN_W-1                            */
    int      mouse_y;       /* 0..INPUT_SCREEN_H-1                            */
    int      mouse_gain;    /* multiplicador do deslocamento relativo (1)     */

    uint32_t phys;          /* uso interno: teclas fisicas pressionadas       */
} input_t;

/* Zera o estado e coloca o mouse no centro. Chamado pelas funcoes de abertura. */
void input_init(input_t *in);

/* Procura teclado e mouse em /proc/bus/input/devices e abre /dev/input/eventN.
 * Devolve quantos dispositivos abriu (0 se nenhum; o jogo segue so com o
 * acelerometro). Exige permissao de leitura em /dev/input (root ou grupo input). */
int input_open(input_t *in);

/* Mesma busca, com os caminhos do arquivo de dispositivos e do diretorio de
 * eventos informados (usado em testes). */
int input_open_proc(input_t *in, const char *proc_devices, const char *dev_dir);

/* Abre caminhos conhecidos (qualquer um pode ser NULL) e os ACRESCENTA ao estado:
 * chame input_init() antes. Devolve quantos abriu. */
int input_open_paths(input_t *in, const char *kbd_path, const char *mouse_path);

/* Le todos os eventos pendentes e atualiza o estado.
 * Devolve o numero de eventos processados (>= 0). Um dispositivo desconectado
 * e fechado e ignorado; nao e erro. */
int input_poll(input_t *in);

void input_close(input_t *in);

#endif /* INPUT_H */