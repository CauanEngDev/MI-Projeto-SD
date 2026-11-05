// ============================================================================
// ISA DO COPROCESSADOR GRAFICO - OPCODES (bits 31:27 da instrucao)
// ----------------------------------------------------------------------------
// Fonte da verdade: aux_files/montador.py (tabela OPCODES). Esta tabela deve
// coincidir com ela, com a unidade_de_controle e com a busca passiva. Se mudar
// a ISA, atualize o montador e este arquivo juntos.
//
// Formatos (mapa de bits da palavra de 32 bits):
//   N (so opcode)  : DRR, DRT, DRB, DRS, WVB, HALT, NOP
//                    [31:27] opcode
//   G (Ra, Rb)     : SEP, SESP, SESA, SETM, SCB, WRSD, WRTD
//                    [31:27] opcode | [26:21] Ra | [20:15] Rb
//   A (ULA)        : ADD, SUB, AND, LSL, LSR, PASS
//                    [31:27] opcode | [26] I | [25:21] Rd[4:0] | [20:15] Rn |
//                    [14] Rd[5] | [11:0] imm12 (I=1) ou Rm (I=0)
//   Desvio         : B, B_COND  (14 bits de deslocamento em palavras)
//                    [31:27] opcode | [26:23] cond (so B_COND) | [13:0] desloc.
//
// Busca ATIVA  (ROM + PC): aceita todos os opcodes, inclusive B e B_COND.
// Busca PASSIVA (FIFO/HPS): o ultimo opcode valido e HALT. B e B_COND (e tudo
// acima de HALT) sao descartados e sinalizam invalid_opcode.
// ============================================================================
`ifndef ISA_VH
`define ISA_VH

// ---- ULA (alu_op = opcode[2:0]) --------------------------------------------
`define NOP    5'b00000
`define ADD    5'b00001
`define SUB    5'b00010
`define AND    5'b00011
`define LSL    5'b00100
`define LSR    5'b00101
`define PASS   5'b00110

// ---- Configuracao e escrita de dados ---------------------------------------
`define SEP    5'b00111   // SET_PALETTE
`define SESP   5'b01010   // SET_SPRITE_POS
`define SESA   5'b01011   // SET_SPRITE_ATTR
`define SETM   5'b01100   // SET_TILEMAP
`define SCB    5'b01101   // SCROLL_BG
`define WRSD   5'b01110   // WRITE_SPRITE_DATA
`define WRTD   5'b01111   // WRITE_TILE_DATA

// ---- Desenho (bloqueiam ate o motor terminar) -------------------------------
`define DRR    5'b01000   // DRAW_RECT
`define DRT    5'b01001   // DRAW_TRI
`define DRB    5'b10000   // DRAW_BG
`define DRS    5'b10001   // DRAW_SPRITES

// ---- Sincronismo e fim de quadro --------------------------------------------
`define WVB    5'b10010   // WAIT_VBLANK
`define HALT   5'b10011   // fim do quadro (ultimo opcode valido na busca passiva)

// ---- Desvios (somente busca ativa) ------------------------------------------
`define B      5'b10100   // desvio incondicional
`define B_COND 5'b10101   // desvio condicional

`endif
