/*
 * gerador_mif.c
 *
 * Gerador de programas MIF para o coprocessador grafico.
 * Todo o programa e gerado diretamente em C, sem Assembly externo.
 *
 * Recursos:
 * - Desenhar retangulos e triangulos.
 * - Definir a quantidade de Sonics (0 a 5).
 * - Reutilizar o pattern 0 do Sonic em diferentes posicoes.
 * - Animar os Sonics com movimento e reflexao nas bordas.
 * - Rolar o fundo para cima, baixo, esquerda e direita.
 * - Preservar a ordem das camadas: fundo, rasterizador e sprites.
 *
 * IMPORTANTE:
 * O fundo, a paleta e o pattern 0 do Sonic devem estar previamente
 * carregados nas memorias graficas do hardware.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define MEM_WORDS 16384
#define MAX_ACTIONS 20
#define MAX_SONICS 5

/* Opcodes da ISA */
#define OP_NOP             0x00
#define OP_ADD             0x01
#define OP_SUB             0x02
#define OP_AND             0x03
#define OP_LSL             0x04
#define OP_LSR             0x05
#define OP_PASS            0x06
#define OP_DRAW_RECT       0x08
#define OP_DRAW_TRI        0x09
#define OP_SET_SPRITE_POS  0x0A
#define OP_SET_SPRITE_ATTR 0x0B
#define OP_SCROLL_BG       0x0D
#define OP_DRAW_BG         0x10
#define OP_DRAW_SPRITES    0x11
#define OP_HALT            0x13
#define OP_B               0x14
#define OP_B_COND          0x15

/* Condicoes de desvio */
#define COND_EQ  0
#define COND_NE  1
#define COND_GE 10
#define COND_LT 11
#define COND_LE 13

enum {
    ACT_RECT = 1,
    ACT_TRIANGLE,
    ACT_SET_SONICS,
    ACT_SCROLL
};

typedef struct {
    int type;
    int x1, y1, x2, y2, x3, y3;
    int palette, color;
    int value;
} Action;

typedef struct {
    uint32_t word;
    char comment[100];
} Instruction;

typedef struct {
    char name[48];
    int index;
} Label;

typedef struct {
    int index;
    char label[48];
    int opcode;
    int condition;
} Fixup;

static Instruction program[MEM_WORDS];
static int program_len;
static Label labels[256];
static int label_count;
static Fixup fixups[512];
static int fixup_count;
static int label_serial;

/* ============================================================
 * Entrada de dados
 * ============================================================ */

static void error_exit(const char *message)
{
    fprintf(stderr, "\nErro: %s\n", message);
    exit(EXIT_FAILURE);
}

static int read_int(const char *prompt, int min, int max)
{
    char line[128];
    char *end;
    long value;

    for (;;) {
        printf("%s", prompt);

        if (!fgets(line, sizeof(line), stdin))
            error_exit("entrada encerrada.");

        value = strtol(line, &end, 10);

        while (*end == ' ' || *end == '\t' ||
               *end == '\r' || *end == '\n')
            end++;

        if (end == line || *end != '\0' ||
            value < min || value > max) {
            printf("Digite um inteiro entre %d e %d.\n", min, max);
            continue;
        }

        return (int)value;
    }
}

/* ============================================================
 * Codificacao das instrucoes
 * ============================================================ */

/*
 * Formato A:
 * [31:27] opcode
 * [26]    I
 * [25:21] Rd[4:0]
 * [20:15] Rn[5:0]
 * [14]    Rd[5]
 * [13:12] reservado
 * [11:0]  imediato
 */
static uint32_t encode_a_imm(int opcode, int rd, int rn, int imm)
{
    if (rd < 0 || rd > 63 ||
        rn < 0 || rn > 63 ||
        imm < 0 || imm > 4095)
        error_exit("operando invalido na instrucao A.");

    return ((uint32_t)opcode << 27)
         | (1u << 26)
         | ((uint32_t)(rd & 31) << 21)
         | ((uint32_t)rn << 15)
         | ((uint32_t)(rd >> 5) << 14)
         | (uint32_t)imm;
}

static uint32_t encode_a_reg(int opcode, int rd, int rn, int rm)
{
    if (rd < 0 || rd > 63 ||
        rn < 0 || rn > 63 ||
        rm < 0 || rm > 63)
        error_exit("registrador invalido na instrucao A.");

    return ((uint32_t)opcode << 27)
         | ((uint32_t)(rd & 31) << 21)
         | ((uint32_t)rn << 15)
         | ((uint32_t)(rd >> 5) << 14)
         | (uint32_t)rm;
}

/*
 * Formato grafico:
 * [31:27] opcode
 * [26:21] registrador Ra
 * [20:15] registrador Rb
 */
static uint32_t encode_g(int opcode, int ra, int rb)
{
    if (ra < 0 || ra > 63 || rb < 0 || rb > 63)
        error_exit("registrador invalido na instrucao grafica.");

    return ((uint32_t)opcode << 27)
         | ((uint32_t)ra << 21)
         | ((uint32_t)rb << 15);
}

static void emit(uint32_t word, const char *comment)
{
    if (program_len >= MEM_WORDS)
        error_exit("programa excedeu a memoria de instrucoes.");

    program[program_len].word = word;

    snprintf(program[program_len].comment,
             sizeof(program[program_len].comment),
             "%s", comment ? comment : "");

    program_len++;
}

static void emit_pass(int rd, int value, const char *comment)
{
    emit(encode_a_imm(OP_PASS, rd, 31, value), comment);
}

static void emit_alu_imm(int opcode, int rd, int rn,
                         int imm, const char *comment)
{
    emit(encode_a_imm(opcode, rd, rn, imm), comment);
}

static void emit_alu_reg(int opcode, int rd, int rn, int rm,
                         const char *comment)
{
    emit(encode_a_reg(opcode, rd, rn, rm), comment);
}

static void emit_g(int opcode, int ra, int rb, const char *comment)
{
    emit(encode_g(opcode, ra, rb), comment);
}

static void emit_simple(int opcode, const char *comment)
{
    emit((uint32_t)opcode << 27, comment);
}

/* ============================================================
 * Rotulos e desvios
 * ============================================================ */

static void new_label_name(char *out, size_t size, const char *prefix)
{
    snprintf(out, size, "%s_%d", prefix, label_serial++);
}

static void define_label(const char *name)
{
    int i;

    for (i = 0; i < label_count; i++) {
        if (strcmp(labels[i].name, name) == 0)
            error_exit("rotulo duplicado.");
    }

    if (label_count >= 256)
        error_exit("quantidade de rotulos excedida.");

    snprintf(labels[label_count].name,
             sizeof(labels[label_count].name), "%s", name);

    labels[label_count].index = program_len;
    label_count++;
}

static void emit_branch(int opcode, int condition, const char *label)
{
    if (fixup_count >= 512)
        error_exit("quantidade de desvios excedida.");

    fixups[fixup_count].index = program_len;
    fixups[fixup_count].opcode = opcode;
    fixups[fixup_count].condition = condition;

    snprintf(fixups[fixup_count].label,
             sizeof(fixups[fixup_count].label), "%s", label);

    fixup_count++;

    emit(0, opcode == OP_B_COND ? "B_COND" : "B");
}

static void resolve_branches(void)
{
    int i, j;

    for (i = 0; i < fixup_count; i++) {
        int target = -1;
        int source = fixups[i].index;
        int displacement;
        uint32_t word;

        for (j = 0; j < label_count; j++) {
            if (strcmp(labels[j].name, fixups[i].label) == 0) {
                target = labels[j].index;
                break;
            }
        }

        if (target < 0)
            error_exit("rotulo de desvio inexistente.");

        /* Deslocamento em palavras, relativo a instrucao atual. */
        displacement = target - source;

        if (displacement < -8192 || displacement > 8191)
            error_exit("deslocamento de desvio fora do limite.");

        if (fixups[i].opcode == OP_B_COND) {
            word = ((uint32_t)OP_B_COND << 27)
                 | ((uint32_t)(fixups[i].condition & 15) << 23)
                 | ((uint32_t)displacement & 0x3FFFu);
        } else {
            word = ((uint32_t)OP_B << 27)
                 | ((uint32_t)displacement & 0x3FFFu);
        }

        program[source].word = word;

        snprintf(program[source].comment,
                 sizeof(program[source].comment),
                 "%s %s",
                 fixups[i].opcode == OP_B_COND ? "B_COND" : "B",
                 fixups[i].label);
    }
}

/* ============================================================
 * Leitura das acoes do usuario
 * ============================================================ */

static void read_actions(Action actions[], int *count,
                         int *sonic_count, int *scroll_x, int *scroll_y)
{
    int i;

    *count = read_int("Quantidade de acoes (1-20): ",
                      1, MAX_ACTIONS);

    *sonic_count = 1;
    *scroll_x = 0;
    *scroll_y = 0;

    printf("\nAcoes disponiveis:\n");
    printf("1 - Desenhar retangulo\n");
    printf("2 - Desenhar triangulo\n");
    printf("3 - Definir quantidade de Sonics (0 a %d)\n", MAX_SONICS);
    printf("4 - Rolar o fundo\n");

    for (i = 0; i < *count; i++) {
        int type;

        printf("\n--- Acao %d/%d ---\n", i + 1, *count);

        type = read_int("Tipo de acao (1-4): ", 1, 4);

        memset(&actions[i], 0, sizeof(actions[i]));
        actions[i].type = type;

        if (type == ACT_RECT) {
            actions[i].x1 = read_int("x1 (0-319): ", 0, 319);
            actions[i].y1 = read_int("y1 (0-239): ", 0, 239);
            actions[i].x2 = read_int("x2 (0-319): ", 0, 319);
            actions[i].y2 = read_int("y2 (0-239): ", 0, 239);
            actions[i].palette = read_int("Paleta (0-1): ", 0, 1);
            actions[i].color = read_int("Indice de cor (0-255): ", 0, 255);
        }
        else if (type == ACT_TRIANGLE) {
            actions[i].x1 = read_int("x do vertice 1 (0-319): ", 0, 319);
            actions[i].y1 = read_int("y do vertice 1 (0-239): ", 0, 239);
            actions[i].x2 = read_int("x do vertice 2 (0-319): ", 0, 319);
            actions[i].y2 = read_int("y do vertice 2 (0-239): ", 0, 239);
            actions[i].x3 = read_int("x do vertice 3 (0-319): ", 0, 319);
            actions[i].y3 = read_int("y do vertice 3 (0-239): ", 0, 239);
            actions[i].palette = read_int("Paleta (0-1): ", 0, 1);
            actions[i].color = read_int("Indice de cor (0-255): ", 0, 255);
        }
        else if (type == ACT_SET_SONICS) {
            actions[i].value = read_int("Quantidade final de Sonics (0-5): ",
                                        0, MAX_SONICS);

            /* SET: a ultima escolha substitui a anterior. */
            *sonic_count = actions[i].value;
        }
        else if (type == ACT_SCROLL) {
            printf("Direcao: 1-cima, 2-baixo, 3-esquerda, 4-direita\n");

            actions[i].value = read_int("Direcao (1-4): ", 1, 4);

            switch (actions[i].value) {
                case 1:
                    *scroll_y = (*scroll_y + 240 - 16) % 240;
                    break;
                case 2:
                    *scroll_y = (*scroll_y + 16) % 240;
                    break;
                case 3:
                    *scroll_x = (*scroll_x + 320 - 16) % 320;
                    break;
                case 4:
                    *scroll_x = (*scroll_x + 16) % 320;
                    break;
            }
        }
    }
}

/* ============================================================
 * Movimento dos Sonics
 * ============================================================ */

/*
 * Cada Sonic usa quatro registradores:
 * X, Y, velocidade X, velocidade Y.
 *
 * O movimento e atualizado a cada frame. Os Sonics refletem
 * nas bordas, reutilizando o mesmo pattern grafico.
 */
static void emit_sonic_motion(int index)
{
    int rx = index * 4;
    int ry = rx + 1;
    int rvx = rx + 2;
    int rvy = rx + 3;

    char right_label[48];
    char left_label[48];
    char bottom_label[48];
    char top_label[48];

    new_label_name(right_label, sizeof(right_label), "x_direita");
    new_label_name(left_label, sizeof(left_label), "x_esquerda");
    new_label_name(bottom_label, sizeof(bottom_label), "y_baixo");
    new_label_name(top_label, sizeof(top_label), "y_cima");

    /* Movimento horizontal: X = X + velocidade X. */
    emit_alu_reg(OP_ADD, rx, rx, rvx, "atualiza X");

    emit_alu_imm(OP_SUB, 31, rx, 304, "verifica limite direito");
    emit_branch(OP_B_COND, COND_LE, right_label);

    emit_pass(rx, 304, "limita X no extremo direito");
    emit_alu_reg(OP_SUB, rvx, 31, rvx, "inverte velocidade X");

    define_label(right_label);

    emit_alu_imm(OP_SUB, 31, rx, 0, "verifica limite esquerdo");
    emit_branch(OP_B_COND, COND_GE, left_label);

    emit_pass(rx, 0, "limita X no extremo esquerdo");
    emit_alu_reg(OP_SUB, rvx, 31, rvx, "inverte velocidade X");

    define_label(left_label);

    /* Movimento vertical: Y = Y + velocidade Y. */
    emit_alu_reg(OP_ADD, ry, ry, rvy, "atualiza Y");

    emit_alu_imm(OP_SUB, 31, ry, 224, "verifica limite inferior");
    emit_branch(OP_B_COND, COND_LE, bottom_label);

    emit_pass(ry, 224, "limita Y no extremo inferior");
    emit_alu_reg(OP_SUB, rvy, 31, rvy, "inverte velocidade Y");

    define_label(bottom_label);

    emit_alu_imm(OP_SUB, 31, ry, 0, "verifica limite superior");
    emit_branch(OP_B_COND, COND_GE, top_label);

    emit_pass(ry, 0, "limita Y no extremo superior");
    emit_alu_reg(OP_SUB, rvy, 31, rvy, "inverte velocidade Y");

    define_label(top_label);
}

/* ============================================================
 * Inicializacao e configuracao dos sprites
 * ============================================================ */

static void emit_initialization(int sonic_count)
{
    int i;
    char initialized_label[48];

    new_label_name(initialized_label, sizeof(initialized_label),
                   "ja_inicializado");

    /*
     * R30 funciona como indicador de inicializacao.
     * Se ja estiver inicializado, preserva as posicoes animadas.
     */
    emit_alu_imm(OP_SUB, 31, 30, 0, "testa inicializacao");
    emit_branch(OP_B_COND, COND_NE, initialized_label);

    for (i = 0; i < sonic_count; i++) {
        int rx = i * 4;
        int ry = rx + 1;
        int rvx = rx + 2;
        int rvy = rx + 3;
        int start_x;
        int start_y;

        if (i == 0) {
            start_x = 100;
            start_y = 80;
        } else {
            start_x = 35 + ((i - 1) % 2) * 180;
            start_y = 35 + ((i - 1) / 2) * 100;
        }

        emit_pass(rx, start_x, "posicao inicial X do Sonic");
        emit_pass(ry, start_y, "posicao inicial Y do Sonic");
        emit_pass(rvx, 3, "velocidade inicial X");
        emit_pass(rvy, 2, "velocidade inicial Y");
    }

    emit_pass(30, 1, "marca inicializacao concluida");
    define_label(initialized_label);
}

static void emit_sprites(int sonic_count)
{
    int i;

    /*
     * Atributos:
     * bit 14: enable
     * bits 13:9: prioridade
     * bit 8: flip vertical
     * bit 7: flip horizontal
     * bit 6: selecao da paleta
     * bits 5:0: indice do pattern
     *
     * Base: enable=1, prioridade=1, paleta=0, pattern=0.
     */

    for (i = 0; i < sonic_count; i++) {
        int rx = i * 4;
        int ry = rx + 1;
        int rvx = rx + 2;
        int rvy = rx + 3;

        char flip_h_label[48];
        char after_flip_h_label[48];
        char flip_v_label[48];
        char after_flip_v_label[48];

        new_label_name(flip_h_label, sizeof(flip_h_label),
                       "ativa_flip_horizontal");

        new_label_name(after_flip_h_label,
                       sizeof(after_flip_h_label),
                       "fim_flip_horizontal");

        new_label_name(flip_v_label, sizeof(flip_v_label),
                       "ativa_flip_vertical");

        new_label_name(after_flip_v_label,
                       sizeof(after_flip_v_label),
                       "fim_flip_vertical");

        /*
         * Empacota a posicao:
         * bits 16:9 = Y
         * bits 8:0  = X
         */
        emit_alu_imm(OP_LSL, 20, ry, 9, "empacota Y");
        emit_alu_reg(OP_ADD, 20, 20, rx, "empacota posicao");

        /*
         * Atributos base:
         * enable = 1
         * prioridade = 1
         * flip_h = 0
         * flip_v = 0
         * paleta = 0
         * pattern = 0
         */
        emit_pass(25, 33, "enable e prioridade 1");
        emit_alu_imm(OP_LSL, 25, 25, 9,
                     "atributos base do Sonic");

        /*
         * Verifica o sinal da velocidade horizontal.
         * SUB XZR, VX, XZR calcula VX - 0 e atualiza as flags.
         * Se VX < 0, ativa o flip horizontal.
         */
        emit_alu_reg(OP_SUB, 31, rvx, 31,
                     "verifica sinal da velocidade X");

        emit_branch(OP_B_COND, COND_LT, flip_h_label);
        emit_branch(OP_B, 0, after_flip_h_label);

        define_label(flip_h_label);

        emit_alu_imm(OP_ADD, 25, 25, 128,
                     "ativa flip horizontal");

        define_label(after_flip_h_label);

        /*
         * Verifica o sinal da velocidade vertical.
         * Se VY < 0, ativa o flip vertical.
         */
        emit_alu_reg(OP_SUB, 31, rvy, 31,
                     "verifica sinal da velocidade Y");

        emit_branch(OP_B_COND, COND_LT, flip_v_label);
        emit_branch(OP_B, 0, after_flip_v_label);

        define_label(flip_v_label);

        emit_alu_imm(OP_ADD, 25, 25, 256,
                     "ativa flip vertical");

        define_label(after_flip_v_label);

        /* Define o ID e envia a posicao do sprite. */
        emit_pass(21, i, "ID do sprite");

        emit_g(OP_SET_SPRITE_POS, 21, 20,
               "SET_SPRITE_POS");

        /* Envia os atributos com os flips calculados. */
        emit_g(OP_SET_SPRITE_ATTR, 21, 25,
               "SET_SPRITE_ATTR");
    }

    /*
     * Desabilita slots restantes para evitar sprites antigos
     * permanecerem ativos.
     */
    emit_pass(22, 0, "atributos desabilitados");

    for (i = sonic_count; i < 32; i++) {
        emit_pass(21, i, "ID de sprite a desabilitar");

        emit_g(OP_SET_SPRITE_ATTR, 21, 22,
               "desabilita sprite");
    }
}

/* ============================================================
 * Fundo e formas
 * ============================================================ */

static void emit_scroll(int scroll_x, int scroll_y)
{
    /*
     * No motor_background, SCROLL_BG escreve um deslocamento absoluto.
     * X usa modulo 320 e Y usa modulo 240.
     */

    emit_pass(23, scroll_x, "deslocamento X");
    emit_pass(24, 0, "seleciona eixo X");
    emit_g(OP_SCROLL_BG, 23, 24, "SCROLL_BG X");

    emit_pass(23, scroll_y, "deslocamento Y");
    emit_pass(24, 1, "seleciona eixo Y");
    emit_g(OP_SCROLL_BG, 23, 24, "SCROLL_BG Y");
}

static void emit_shape(const Action *a)
{
    int color = a->palette * 256 + a->color;

    if (a->type == ACT_RECT) {
        emit_pass(37, a->x1, "V0X");
        emit_pass(38, a->y1, "V0Y");
        emit_pass(39, a->x2, "V1X");
        emit_pass(40, a->y2, "V1Y");
        emit_pass(43, color, "COLOR");
        emit_simple(OP_DRAW_RECT, "DRAW_RECT");
    }
    else if (a->type == ACT_TRIANGLE) {
        emit_pass(37, a->x1, "V0X");
        emit_pass(38, a->y1, "V0Y");
        emit_pass(39, a->x2, "V1X");
        emit_pass(40, a->y2, "V1Y");
        emit_pass(41, a->x3, "V2X");
        emit_pass(42, a->y3, "V2Y");
        emit_pass(43, color, "COLOR");
        emit_simple(OP_DRAW_TRI, "DRAW_TRI");
    }
}

/* ============================================================
 * Montagem do programa
 * ============================================================ */

static void build_program(const Action actions[], int action_count,
                          int sonic_count, int scroll_x, int scroll_y)
{
    int i;

    emit_initialization(sonic_count);

    for (i = 0; i < sonic_count; i++)
        emit_sonic_motion(i);

    emit_scroll(scroll_x, scroll_y);

    /* A camada de fundo e redesenhada em todos os frames. */
    emit_simple(OP_DRAW_BG, "DRAW_BG");

    /* As formas ficam acima do fundo. */
    for (i = 0; i < action_count; i++) {
        if (actions[i].type == ACT_RECT ||
            actions[i].type == ACT_TRIANGLE)
            emit_shape(&actions[i]);
    }

    /* Os sprites ficam na camada superior. */
    emit_sprites(sonic_count);

    emit_simple(OP_DRAW_SPRITES, "DRAW_SPRITES");
    emit_simple(OP_HALT, "HALT");

    resolve_branches();
}

/* ============================================================
 * Gravacao do MIF
 * ============================================================ */

static void write_mif(const char *filename)
{
    FILE *file;
    char output_filename[256];
    int i;
    size_t len;

    /*
     * Garante que o nome do arquivo termine em .mif.
     * Se a extensao ja existir, ela e preservada.
     */
    snprintf(output_filename, sizeof(output_filename), "%s", filename);

    len = strlen(output_filename);

    if (len < 4 ||
        strcmp(output_filename + len - 4, ".mif") != 0) {

        if (len + 4 >= sizeof(output_filename)) {
            fprintf(stderr, "Nome do arquivo muito longo.\n");
            exit(EXIT_FAILURE);
        }

        strcat(output_filename, ".mif");
    }

    file = fopen(output_filename, "w");

    if (!file) {
        perror("Nao foi possivel criar o arquivo");
        exit(EXIT_FAILURE);
    }

    fprintf(file, "-- gerado por gerador_mif.c\n");
    fprintf(file, "WIDTH=32;\n");
    fprintf(file, "DEPTH=%d;\n", MEM_WORDS);
    fprintf(file, "ADDRESS_RADIX=HEX;\n");
    fprintf(file, "DATA_RADIX=HEX;\n");
    fprintf(file, "CONTENT BEGIN\n");

    for (i = 0; i < program_len; i++) {
        fprintf(file, "    %04X : %08X;",
                i, program[i].word);

        if (program[i].comment[0] != '\0')
            fprintf(file, "  -- %s", program[i].comment);

        fputc('\n', file);
    }

    if (program_len < MEM_WORDS) {
        fprintf(file, "    [%04X..3FFF] : 00000000; -- preenchimento\n",
                program_len);
    }

    fprintf(file, "END;\n");

    if (fclose(file) != 0) {
        perror("Erro ao fechar o MIF");
        exit(EXIT_FAILURE);
    }

    printf("\nArquivo MIF gerado: %s\n", output_filename);
}

/* ============================================================
 * Programa principal
 * ============================================================ */

int main(void)
{
    Action actions[MAX_ACTIONS];
    int action_count;
    int sonic_count;
    int scroll_x;
    int scroll_y;
    char filename[256];

    printf("=== Gerador MIF do coprocessador grafico ===\n\n");
    printf("O programa reutiliza o pattern 0 do Sonic ja carregado.\n");
    printf("Cada Sonic usa uma posicao e movimento independentes.\n");
    printf("Limite: %d acoes e %d Sonics.\n\n",
           MAX_ACTIONS, MAX_SONICS);

    read_actions(actions, &action_count,
                 &sonic_count, &scroll_x, &scroll_y);

    printf("\nArquivo de saida (Enter para programa.mif): ");

    if (!fgets(filename, sizeof(filename), stdin))
        error_exit("entrada encerrada.");

    filename[strcspn(filename, "\r\n")] = '\0';

    if (filename[0] == '\0')
        strcpy(filename, "programa.mif");

    build_program(actions, action_count,
                  sonic_count, scroll_x, scroll_y);

    write_mif(filename);

    printf("\nMIF gerado: %s\n", filename);
    printf("Instrucoes utilizadas: %d / %d\n",
           program_len, MEM_WORDS);
    printf("Quantidade final de Sonics: %d\n", sonic_count);
    printf("Scroll final: X=%d, Y=%d\n", scroll_x, scroll_y);

    printf("\nLembre-se: o fundo, a paleta e o pattern 0 do Sonic\n");
    printf("precisam estar previamente inicializados nas memorias graficas.\n");

    return EXIT_SUCCESS;
}